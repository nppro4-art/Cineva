import { load } from "https://esm.sh/cheerio@1.0.0";

/**
 * Edge Function: import-from-url
 *
 * Scrape une page web listant des films/séries et renvoie un tableau JSON
 * d'éléments normalisés. Tourne côté serveur (Supabase Edge Functions) afin
 * d'éviter les blocages CORS du navigateur.
 *
 * Corps attendu:
 * {
 *   "url": "https://un-site-avec-des-films...",
 *   "selectors": {            // optionnel, pour affiner un site précis
 *     "item": "article, .movie, .item, li",
 *     "title": "h2, h3, a, .title",
 *     "poster": "img",
 *     "year": ".year",
 *     "overview": ".synopsis, p"
 *   }
 * }
 *
 * Réponse: { "items": [ { "contentType", "title", "posterPath", "releaseYear",
 *                         "audioLanguages", "subtitleLanguages", "quality", ... } ] }
 */
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface Selectors {
  item?: string;
  title?: string;
  poster?: string;
  year?: string;
  overview?: string;
  link?: string;
}

interface ImportedItem {
  contentType: "movie" | "series";
  title: string;
  originalTitle?: string;
  synopsis?: string;
  posterPath?: string;
  backdropPath?: string;
  releaseYear?: number;
  audioLanguages: string[];
  subtitleLanguages: string[];
  quality?: string;
  genres: string[];
  castNames: string[];
  countries: string[];
  directorName?: string;
  sourceUrl?: string;
}

// Indices de langue -> code ISO. Les marqueurs "VOST/SUB/VOSE" sont orientés
// sous-titres, les autres (VF/VO/VFF) orientés audio.
const AUDIO_HINTS: Record<string, string> = {
  VF: "fr", VFF: "fr", "FR": "fr", "Français": "fr", VQ: "fr",
  VO: "en", "EN": "en", "English": "en", VOA: "en",
  "ES": "es", "Español": "es", "VOSE": "es",
  "DE": "de", "Allemand": "de",
  "IT": "it", "Italiano": "it",
  "PT": "pt", "Português": "pt",
  "RU": "ru", "Russe": "ru",
  "AR": "ar", "Arabe": "ar",
  "JA": "ja", "Japonais": "ja",
  "KO": "ko", "Coréen": "ko",
  "ZH": "zh", "Chinois": "zh",
};
const SUB_HINTS: Record<string, string> = {
  VOSTFR: "fr", VOST: "fr", "SUB": "fr", "VOSE": "es", "VOSTEN": "en",
  "ST": "en", "Sous-titres": "fr", "Subtitles": "en", "Subtitulado": "es",
};
const QUALITY_RANK: Record<string, number> = {
  cam: 0, ts: 1, hd: 2, "720p": 3, "1080p": 4, webrip: 4, "web-dl": 4,
  bluray: 5, brip: 5, "2160p": 6, "4k": 6,
};

function absolutize(url: string, base: string): string {
  try {
    return new URL(url, base).toString();
  } catch {
    return url;
  }
}

function extractYear(text: string): number | undefined {
  const m = text.match(/(?:19|20)\d{2}/);
  return m ? parseInt(m[0], 10) : undefined;
}

function firstText(root: any, selector?: string): string {
  if (!selector) return "";
  const el = root.find(selector).first();
  return el.length ? el.text().trim() : "";
}

function pickPoster(root: any, base: string): string | undefined {
  const img = root.find("img").first();
  const src =
    img.attr("src") ||
    img.attr("data-src") ||
    img.attr("data-lazy-src") ||
    img.attr("data-original");
  if (!src) return undefined;
  return absolutize(src, base);
}

function detectLanguages(text: string): {
  audio: string[];
  subtitle: string[];
} {
  const hay = ` ${text} `;
  const audio = new Set<string>();
  const subtitle = new Set<string>();
  for (const [hint, code] of Object.entries(AUDIO_HINTS)) {
    if (new RegExp(`\\b${hint}\\b`, "i").test(hay)) audio.add(code);
  }
  for (const [hint, code] of Object.entries(SUB_HINTS)) {
    if (new RegExp(`\\b${hint}\\b`, "i").test(hay)) subtitle.add(code);
  }
  return { audio: [...audio], subtitle: [...subtitle] };
}

function detectQuality(text: string): string | undefined {
  const lower = text.toLowerCase();
  let best: { q: string; r: number } | undefined;
  for (const [token, rank] of Object.entries(QUALITY_RANK)) {
    if (lower.includes(token)) {
      if (!best || rank > best.r) best = { q: token.toUpperCase(), r: rank };
    }
  }
  return best?.q;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const url = body?.url as string | undefined;
    if (!url || typeof url !== "string") {
      return new Response(JSON.stringify({ error: "Champ 'url' requis." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (compatible; CinevaBot/1.0; +https://cineva.app)",
        "Accept-Language": "fr-FR,fr;q=0.9,en;q=0.8",
      },
    });
    if (!res.ok) {
      return new Response(
        JSON.stringify({ error: `La page a répondu HTTP ${res.status}.` }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const html = await res.text();
    const $ = await load(html);
    const sel: Selectors = body?.selectors ?? {};

    const itemSelector =
      sel.item ||
      "article, .movie, .film, .item, .post, .thumb, .card, li";
    const titleSelector = sel.title || "h1, h2, h3, h4, a, .title";
    const overviewSelector =
      sel.overview || ".synopsis, .description, .overview, .plot, p";

    const items: ImportedItem[] = [];
    $(itemSelector).each((_: number, el: any) => {
      const $el = $(el);
      const rawTitle =
        firstText($el, titleSelector) ||
        $el.attr("title") ||
        $el.find("img").first().attr("alt") ||
        "";
      const title = rawTitle.replace(/\(\s*(?:19|20)\d{2}\s*\)/g, "").trim();
      if (title.length < 2) return;

      const poster = pickPoster($el, url);
      const overview = firstText($el, overviewSelector);
      const href = $el.find("a").first().attr("href");
      const year =
        extractYear(rawTitle) ||
        (sel.year ? extractYear(firstText($el, sel.year)) : undefined);

      const blob = `${title} ${overview} ${$el.text()}`;
      const langs = detectLanguages(blob);
      const quality = detectQuality(blob);

      items.push({
        contentType: "movie",
        title,
        synopsis: overview || undefined,
        posterPath: poster,
        releaseYear: year,
        audioLanguages: langs.audio,
        subtitleLanguages: langs.subtitle,
        quality,
        genres: [],
        castNames: [],
        countries: [],
        sourceUrl: href ? absolutize(href, url) : undefined,
      });
    });

    // Déduplication par titre (insensible à la casse).
    const seen = new Set<string>();
    const unique = items.filter((it) => {
      const k = it.title.toLowerCase();
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });

    return new Response(
      JSON.stringify({ items: unique.slice(0, 200) }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `Erreur de scraping: ${String(e)}` }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
