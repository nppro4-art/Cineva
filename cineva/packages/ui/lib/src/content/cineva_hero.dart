import 'dart:async';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import '../primitives/cineva_buttons.dart';
import '../primitives/cineva_pressable.dart';
import 'cineva_artwork_image.dart';
import 'cineva_content_labels.dart';

/// Hero animé de l'accueil.
///
/// Rotation automatique des suggestions avec une transition cinématographique :
/// 1. le backdrop précédent s'efface pendant que le nouveau apparaît
///    (crossfade + zoom arrière très léger, 720 ms) ;
/// 2. le titre arrive depuis le bas ;
/// 3. les métadonnées suivent ;
/// 4. la description ;
/// 5. le bouton « Regarder » en dernier.
///
/// L'enchaînement texte complet dure 760 ms : rapide mais lisible. Un swipe
/// horizontal change de suggestion et relance la rotation automatique.
class CinevaHero extends StatefulWidget {
  const CinevaHero({
    super.key,
    required this.items,
    required this.onPlay,
    required this.onOpen,
    this.height = 480,
    this.overline = 'À la une',
    this.onToggleMyList,
    this.myListIds = const <String>{},
    this.autoRotate = true,
    this.rotationInterval = CinevaMotion.heroRotation,
    this.onIndexChanged,
    this.playLabelFor,
    this.parallaxController,
    this.parallaxFactor = 0.22,
  });

  final List<ContentTileModel> items;

  /// Lance la lecture (ou la reprise) du contenu courant.
  final void Function(ContentTileModel item) onPlay;

  /// Ouvre la fiche du contenu courant.
  final void Function(ContentTileModel item) onOpen;

  final double height;
  final String overline;

  /// Ajoute/retire de « Ma liste » (null = action masquée).
  final void Function(ContentTileModel item)? onToggleMyList;
  final Set<String> myListIds;

  final bool autoRotate;
  final Duration rotationInterval;
  final ValueChanged<int>? onIndexChanged;

  /// Libellé du bouton principal (« Regarder » ou « Reprendre »).
  final String Function(ContentTileModel item)? playLabelFor;

  /// Contrôleur de scroll de la page hôte : active la parallaxe du backdrop
  /// (l'image descend plus lentement que le contenu) et son léger
  /// rétrécissement, sans jamais reconstruire la page entière.
  final ScrollController? parallaxController;

  /// Amplitude de la parallaxe (0 = aucune, 1 = image totalement fixe).
  final double parallaxFactor;

  @override
  State<CinevaHero> createState() => _CinevaHeroState();
}

class _CinevaHeroState extends State<CinevaHero> with SingleTickerProviderStateMixin {
  static const Duration _textDuration = Duration(milliseconds: 760);

  late final AnimationController _text = AnimationController(
    vsync: this,
    duration: _textDuration,
  );

  Timer? _timer;
  int _index = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _text.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_reduceMotion) {
        _text.forward();
      }
      _startRotation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _timer?.cancel();
      _text.stop();
      _text.value = 1;
    } else {
      _startRotation();
    }
  }

  @override
  void didUpdateWidget(CinevaHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length && _index >= widget.items.length) {
      _index = widget.items.isEmpty ? 0 : widget.items.length - 1;
    }
    if (oldWidget.autoRotate != widget.autoRotate) {
      if (widget.autoRotate) {
        _startRotation();
      } else {
        _timer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  ContentTileModel get _current => widget.items[_index.clamp(0, widget.items.length - 1)];

  void _startRotation() {
    _timer?.cancel();
    if (!widget.autoRotate || _reduceMotion || widget.items.length <= 1) return;
    _timer = Timer.periodic(widget.rotationInterval, (_) => _goTo(_index + 1));
  }

  void _goTo(int next) {
    if (widget.items.isEmpty) return;
    final int target = next % widget.items.length;
    if (target == _index) {
      _startRotation();
      return;
    }
    setState(() => _index = target);
    widget.onIndexChanged?.call(target);
    if (!_reduceMotion) {
      _text.forward(from: 0);
    }
    _startRotation();
  }

  void _handleDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity < -180) {
      _goTo(_index + 1);
    } else if (velocity > 180) {
      _goTo(_index - 1);
    } else {
      _startRotation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final ContentTileModel item = _current;
    final bool inList = widget.myListIds.contains(item.id);
    final String playLabel = widget.playLabelFor?.call(item) ??
        ((item.progressPercent ?? 0) > 0.02 && (item.progressPercent ?? 0) < 0.97
            ? 'Reprendre'
            : 'Regarder');

    final Widget backdrop = AnimatedSwitcher(
      duration: _reduceMotion ? Duration.zero : CinevaMotion.heroImage,
      switchInCurve: CinevaCurve.heroRotate,
      switchOutCurve: CinevaCurve.inOut,
      transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.05, end: 1).animate(
            CurvedAnimation(parent: animation, curve: CinevaCurve.inOut),
          ),
          child: child,
        ),
      ),
      child: RepaintBoundary(
        key: ValueKey<String>(item.id),
        child: CinevaArtworkImage.forTile(item, useBackdrop: true),
      ),
    );

    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _timer?.cancel(),
        onHorizontalDragEnd: _handleDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _parallaxBackdrop(backdrop),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: CinevaScrims.heroTop),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: CinevaScrims.heroBottom),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _parallaxContent(_HeroBody(
                item: item,
                playLabel: playLabel,
                inList: inList,
                showListAction: widget.onToggleMyList != null,
                animation: _text,
                reduceMotion: _reduceMotion,
                overline: widget.overline,
                index: _index,
                count: widget.items.length,
                onPlay: () => widget.onPlay(item),
                onOpen: () => widget.onOpen(item),
                onToggleList: widget.onToggleMyList == null
                    ? null
                    : () => widget.onToggleMyList!(item),
                onSelectIndex: _goTo,
              ),
            )),
          ],
        ),
      ),
    );
  }

  /// Backdrop : parallaxe + très léger rétrécissement pendant le scroll.
  ///
  /// L'image part à 1.18 et revient à 1.00 ; elle est toujours décalée vers le
  /// bas d'une fraction du scroll, donc jamais plus haut que la zone déjà
  /// sortie de l'écran (aucun vide visible).
  Widget _parallaxBackdrop(Widget child) {
    final ScrollController? controller = widget.parallaxController;
    if (controller == null) {
      return ClipRect(child: child);
    }
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (BuildContext context, Widget? cached) {
        final double offset = controller.hasClients && controller.offset > 0
            ? controller.offset
            : 0;
        final double progress = widget.height <= 0
            ? 0
            : (offset / widget.height).clamp(0.0, 1.0);
        return ClipRect(
          child: Transform.translate(
            offset: Offset(0, offset * widget.parallaxFactor),
            child: Transform.scale(
              scale: 1.18 - (0.18 * progress),
              alignment: Alignment.topCenter,
              child: cached,
            ),
          ),
        );
      },
    );
  }

  /// Contenu : remonte légèrement et s'estompe pendant le scroll.
  Widget _parallaxContent(Widget child) {
    final ScrollController? controller = widget.parallaxController;
    if (controller == null) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (BuildContext context, Widget? cached) {
        final double offset = controller.hasClients && controller.offset > 0
            ? controller.offset
            : 0;
        final double fadeEnd = widget.height * 0.55;
        final double opacity = fadeEnd <= 0
            ? 1
            : (1 - (offset / fadeEnd)).clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: opacity < 0.05,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, offset * -0.12),
              child: cached,
            ),
          ),
        );
      },
    );
  }
}

class _HeroBody extends StatelessWidget {
  const _HeroBody({
    required this.item,
    required this.playLabel,
    required this.inList,
    required this.showListAction,
    required this.animation,
    required this.reduceMotion,
    required this.overline,
    required this.index,
    required this.count,
    required this.onPlay,
    required this.onOpen,
    required this.onToggleList,
    required this.onSelectIndex,
  });

  final ContentTileModel item;
  final String playLabel;
  final bool inList;
  final bool showListAction;
  final Animation<double> animation;
  final bool reduceMotion;
  final String overline;
  final int index;
  final int count;
  final VoidCallback onPlay;
  final VoidCallback onOpen;
  final VoidCallback? onToggleList;
  final ValueChanged<int> onSelectIndex;

  static const Interval _title = Interval(0, 0.55, curve: CinevaCurve.decelerate);
  static const Interval _meta = Interval(0.12, 0.68, curve: CinevaCurve.decelerate);
  static const Interval _description = Interval(0.26, 0.84, curve: CinevaCurve.decelerate);
  static const Interval _actions = Interval(0.4, 1, curve: CinevaCurve.decelerate);

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final List<String> tokens = CinevaContentLabels.qualityTokens(item.badge);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.gutter,
        0,
        metrics.gutter,
        CinevaSpacing.lg,
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double title = _valueFor(_title);
          final double meta = _valueFor(_meta);
          final double description = _valueFor(_description);
          final double actions = _valueFor(_actions);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _step(
                title,
                16,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 14,
                          height: 2,
                          decoration: BoxDecoration(
                            color: CinevaColors.gold,
                            borderRadius: BorderRadius.circular(CinevaRadii.chip),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          overline.toUpperCase(),
                          style: CinevaTypography.overline.copyWith(color: CinevaColors.gold),
                        ),
                      ],
                    ),
                    const SizedBox(height: CinevaSpacing.sm),
                    Semantics(
                      header: true,
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CinevaTypography.heroTitle.copyWith(
                          fontSize: metrics.heroTitleSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _step(
                meta,
                12,
                Padding(
                  padding: const EdgeInsets.only(top: CinevaSpacing.sm),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        CinevaContentLabels.meta(item),
                        style: CinevaTypography.meta.copyWith(color: CinevaColors.textHigh),
                      ),
                      for (final String token in tokens.take(2)) _HeroTag(label: token),
                      if (item.ageRating != null) _HeroTag(label: item.ageRating!),
                      if (item.genres.isNotEmpty)
                        Text(
                          item.genres.take(2).join(' · '),
                          style: CinevaTypography.meta,
                        ),
                    ],
                  ),
                ),
              ),
              _step(
                description,
                10,
                Padding(
                  padding: const EdgeInsets.only(top: CinevaSpacing.sm),
                  child: Text(
                    CinevaContentLabels.clampText(item.description ?? item.subtitle, maxChars: 116),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CinevaTypography.body.copyWith(
                      fontSize: 13.5,
                      height: 1.5,
                      color: CinevaColors.textSoft,
                    ),
                  ),
                ),
              ),
              _step(
                actions,
                14,
                Padding(
                  padding: const EdgeInsets.only(top: CinevaSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: CinevaPlayButton(
                              label: playLabel,
                              height: 48,
                              onPressed: onPlay,
                              semanticLabel: '$playLabel ${item.title}',
                            ),
                          ),
                          if (showListAction) ...<Widget>[
                            const SizedBox(width: CinevaSpacing.sm),
                            _MyListButton(
                              inList: inList,
                              onTap: onToggleList!,
                              label: item.title,
                            ),
                          ],
                          const SizedBox(width: CinevaSpacing.sm),
                          _InfoButton(onTap: onOpen, label: item.title),
                        ],
                      ),
                      if (count > 1) ...<Widget>[
                        const SizedBox(height: CinevaSpacing.md),
                        _HeroDots(
                          count: count,
                          index: index,
                          onSelected: reduceMotion ? null : onSelectIndex,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _valueFor(Interval interval) {
    final double raw = interval.transform(animation.value);
    return raw.clamp(0.0, 1.0);
  }

  Widget _step(double value, double offset, Widget child) {
    if (reduceMotion) return child;
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * offset),
        child: child,
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CinevaRadii.hair - 2),
        border: Border.all(color: CinevaColors.hairlineStrong),
        color: const Color(0x26000000),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          height: 1.2,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: CinevaColors.textHigh,
        ),
      ),
    );
  }
}

class _MyListButton extends StatelessWidget {
  const _MyListButton({required this.inList, required this.onTap, required this.label});

  final bool inList;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: inList ? 'Retirer $label de ma liste' : 'Ajouter $label à ma liste',
      child: CinevaPressable(
        pressedScale: 0.92,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CinevaRadii.medium),
            color: CinevaColors.raised.withOpacity(0.86),
            border: Border.all(
              color: inList ? CinevaColors.gold.withOpacity(0.5) : CinevaColors.hairlineStrong,
            ),
          ),
          child: AnimatedSwitcher(
            duration: CinevaMotion.fast,
            switchInCurve: CinevaCurve.release,
            transitionBuilder: (Widget child, Animation<double> value) => ScaleTransition(
              scale: value,
              child: FadeTransition(opacity: value, child: child),
            ),
            child: Icon(
              inList ? Icons.check_rounded : Icons.add_rounded,
              key: ValueKey<bool>(inList),
              size: 22,
              color: inList ? CinevaColors.gold : CinevaColors.textHigh,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Plus d’informations sur $label',
      child: CinevaPressable(
        pressedScale: 0.92,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CinevaRadii.medium),
            color: CinevaColors.raised.withOpacity(0.86),
            border: Border.all(color: CinevaColors.hairlineStrong),
          ),
          child: const Icon(
            Icons.info_outline_rounded,
            size: 21,
            color: CinevaColors.textHigh,
          ),
        ),
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({required this.count, required this.index, this.onSelected});

  final int count;
  final int index;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Suggestion ${index + 1} sur $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSelected == null ? null : () => onSelected!(i),
                child: AnimatedContainer(
                  duration: CinevaMotion.medium,
                  curve: CinevaCurve.out,
                  width: i == index ? 16 : 5,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i == index ? CinevaColors.gold : const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(CinevaRadii.chip),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
