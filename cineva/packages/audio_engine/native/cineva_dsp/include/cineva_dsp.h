/*
 * Cineva Audio Engine — DSP core (C99).
 *
 * Temps réel par blocs : aucune allocation, aucun verrou, aucune E/S dans
 * cineva_dsp_process(). Paramètres versionnés sous forme de tableau de
 * doubles (voir CINEVA_DSP_PARAM_* ci-dessous), validés et clampés.
 *
 * Contrat d'équivalence : le même tableau de paramètres + le même PCM
 * d'entrée produisent le même PCM de sortie dans les implémentations
 * C, Dart et JS du moteur.
 */
#ifndef CINEVA_DSP_H
#define CINEVA_DSP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CINEVA_DSP_PARAM_VERSION 1
#define CINEVA_DSP_PARAM_COUNT 128
#define CINEVA_DSP_METRIC_COUNT 16
#define CINEVA_DSP_MAX_CHANNELS 8
#define CINEVA_DSP_MAX_BLOCK 8192

/*
 * Disposition des paramètres (index → signification, version 1).
 * Toutes les valeurs non finies (NaN/Inf) sont remplacées par défaut.
 * Tous les paramètres sont clampés à leur plage valide.
 *
 *   0     layoutVersion (doit valoir CINEVA_DSP_PARAM_VERSION)
 *   1     sampleRate (8000..192000)
 *   2     masterEnable (0 = bypass bit-exact)
 *   3     inChannels (1..8)
 *   4     outChannels (2 en V1)
 *   5     inputLayout (0 mono, 1 stéréo, 2 quad, 3 5.1, 4 7.1)
 *   6     lfeIntoBass (0/1)
 *   7     masterHeadroomDb (-12..12)
 *
 *   Loudness (8..15)
 *     8   enable
 *     9   targetLufs (-36..-8)
 *    10   maxGainDb (0..12)
 *    11   maxAttenuationDb (0..12)
 *    12   adaptRateDbPerSec (0.1..6)
 *
 *   EQ (16..47) — 6 bandes, i = 0..5
 *    16   enable
 *    17+5i bandType (0 lowshelf, 1 peaking, 2 highshelf)
 *    18+5i bandFreqHz (20..20000)
 *    19+5i bandGainDb (-15..15)
 *    20+5i bandQ (0.3..4)
 *
 *   DRC (48..59)
 *    48   enable
 *    49   thresholdDb (-60..0)
 *    50   ratio (1..20)
 *    51   kneeDb (0..24)
 *    52   attackMs (0.5..200)
 *    53   releaseMs (20..1000)
 *    54   makeupDb (-6..12)
 *    55   mixPercent (0..100)
 *    56   detector (0 peak, 1 rms)
 *
 *   Dialogue (60..67)
 *    60   enable
 *    61   intensityPercent (0..100)
 *
 *   Bass (68..79)
 *    68   enable
 *    69   intensityPercent (0..100)
 *    70   crossoverHz (50..160)
 *    71   speakerMode (0 full, 1 small, 2 headphone)
 *    72   subShelfGainDb (-6..9)
 *    73   harmonicDrivePercent (0..100)
 *    74   lfeGainDb (-12..6)
 *
 *   Spatial (80..91)
 *    80   enable
 *    81   mode (0 off, 1 width, 2 binaural, 3 binaural+crossfeed)
 *    82   widthPercent (0..150)
 *    83   crossfeedPercent (0..100)
 *    84   binauralAmountPercent (0..100)
 *
 *   Room (92..99)
 *    92   enable
 *    93   wetPercent (0..15)
 *    94   sizePercent (50..150)
 *
 *   Limiter (100..107)
 *   100   enable
 *   101   ceilingDb (-6..0)
 *   102   lookaheadMs (1..10)
 *   103   releaseMs (40..500)
 *
 * 108..127 réservés (0)
 *
 * Métriques (16) :
 *   0 loudnessLufs — estimation intégrée gate (BS.1770-4)
 *   1 truePeakDb — crête absolue depuis la dernière lecture
 *   2 loudnessGainDb — gain appliqué par le normaliseur
 *   3 limiterGainDb — atténuation instantanée du limiteur
 *   4 clippedSamples — échantillons clampés (cumul)
 *   5 engineActive — 1 si le traitement est actif
 *   6..15 réservés
 */

typedef struct cineva_dsp cineva_dsp;

/* Crée le moteur. sample_rate ∈ [8000, 192000], sinon 48000 est utilisé.
 * Retourne NULL en cas d'échec d'allocation. */
cineva_dsp *cineva_dsp_create(double sample_rate);

void cineva_dsp_destroy(cineva_dsp *dsp);

/* Applique un jeu de paramètres (tableau de CINEVA_DSP_PARAM_COUNT doubles).
 * Retourne 0 si OK, -1 si arguments invalides (dsp/values NULL ou count).
 * La version (values[0]) doit correspondre, sinon -2.
 * Un changement de sample_rate réinitialise proprement les états. */
int cineva_dsp_set_params(cineva_dsp *dsp, const double *values, int count);

/* Copie les paramètres effectifs (clampés) vers out. Retourne 0 ou -1. */
int cineva_dsp_get_params(const cineva_dsp *dsp, double *out, int count);

/* Traite un bloc. in/out : planar (in[in_channels][frames], out[out_channels][frames]).
 * in_channels doit être 1..8, out_channels 2, frames 1..CINEVA_DSP_MAX_BLOCK
 * (les blocs plus grands sont traités par tranches internes).
 * masterEnable = 0 ⇒ recopie bit-exact vers la stéréo (mono dupliqué).
 * Retourne 0 si OK, -1 si arguments invalides. */
int cineva_dsp_process(cineva_dsp *dsp,
                       const float *const *in, int in_channels,
                       float *const *out, int out_channels,
                       int frames);

/* Réinitialise les états internes (filtres, enveloppes, historique loudness). */
int cineva_dsp_reset(cineva_dsp *dsp);

/* Lit les métriques (CINEVA_DSP_METRIC_COUNT doubles). truePeakDb est
 * remis à -inf après lecture. Retourne 0 ou -1. */
int cineva_dsp_get_metrics(cineva_dsp *dsp, double *out, int count);

/* Version du cœur, ex. "1.0.0". */
const char *cineva_dsp_version(void);

#ifdef __cplusplus
}
#endif

#endif /* CINEVA_DSP_H */
