part of 'home_screen.dart';

class _HeroCarouselSection extends StatefulWidget {
  const _HeroCarouselSection({required this.section});

  final HomeSectionModel section;

  @override
  State<_HeroCarouselSection> createState() => _HeroCarouselSectionState();
}

class _HeroCarouselSectionState extends State<_HeroCarouselSection> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.96);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.section.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final current = items[_currentIndex.clamp(0, items.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: CinevaSectionTitle(title: widget.section.title),
        ),
        if (widget.section.description != null) ...<Widget>[
          const SizedBox(height: CinevaSpacing.xs),
          Text(
            widget.section.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
          ),
        ],
        const SizedBox(height: CinevaSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CinevaRadii.large),
                gradient: CinevaArtworkPalette.gradientFor(current.id),
              ),
              padding: const EdgeInsets.all(1.2),
              child: SizedBox(
                height: HomeScreenLayout.heroHeight(constraints.maxWidth),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: items.length,
                  onPageChanged: (value) => setState(() => _currentIndex = value),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: CinevaSpacing.md),
                    child: _HeroCard(item: items[index]),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: CinevaSpacing.lg),
        Row(
          children: <Widget>[
            ...List<Widget>.generate(
              items.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                width: _currentIndex == index ? 28 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _currentIndex == index ? CinevaColors.accentSoft : CinevaColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${_currentIndex + 1}/${items.length}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: CinevaColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  void _startTimer() {
    if (widget.section.items.length <= 1) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentIndex + 1) % widget.section.items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.item});

  final ContentTileModel item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CinevaRadii.large),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CinevaArtwork(
            content: item,
            useBackdrop: true,
            borderRadius: BorderRadius.circular(CinevaRadii.large),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Colors.black.withOpacity(0.78),
                  Colors.black.withOpacity(0.44),
                  Colors.black.withOpacity(0.14),
                ],
                stops: const <double>[0.0, 0.52, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(CinevaSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = HomeScreenLayout.showHeroPoster(constraints.maxWidth);
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                _HeroPill(label: item.badge),
                                if (item.ageRating != null) _HeroPill(label: item.ageRating!),
                                if (item.year != null) _HeroPill(label: '${item.year}'),
                                if (item.durationMinutes != null) _HeroPill(label: '${item.durationMinutes} min'),
                              ],
                            ),
                            const Spacer(),
                            Semantics(
                              header: true,
                              child: Text(
                                item.title,
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(height: 1.0),
                              ),
                            ),
                            const SizedBox(height: CinevaSpacing.md),
                            Text(
                              item.description ?? item.subtitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: CinevaColors.textPrimary.withOpacity(0.92),
                                    height: 1.45,
                                  ),
                            ),
                            const SizedBox(height: CinevaSpacing.lg),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: item.genres.take(3).map((genre) => _HeroPill(label: genre)).toList(),
                            ),
                            const SizedBox(height: CinevaSpacing.xl),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: <Widget>[
                                SizedBox(
                                  width: 220,
                                  child: CinevaPrimaryButton(
                                    label: 'Lecture',
                                    icon: Icons.play_arrow_rounded,
                                    onPressed: () => context.push('/player/${Uri.encodeComponent(item.id)}'),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: CinevaPrimaryButton(
                                    label: 'Détails',
                                    icon: Icons.info_outline_rounded,
                                    onPressed: () => context.push('/content/${Uri.encodeComponent(item.id)}'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (wide) ...<Widget>[
                      const SizedBox(width: CinevaSpacing.xl),
                      SizedBox(
                        width: 220,
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(CinevaRadii.large),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 28,
                                  offset: const Offset(0, 22),
                                ),
                              ],
                            ),
                            child: CinevaArtwork(
                              content: item,
                              borderRadius: BorderRadius.circular(CinevaRadii.large),
                              showTypeBadge: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingSection extends StatelessWidget {
  const _ContinueWatchingSection({required this.section});

  final HomeSectionModel section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: CinevaSectionTitle(title: section.title),
        ),
        if (section.description != null) ...<Widget>[
          const SizedBox(height: CinevaSpacing.xs),
          Text(
            section.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
          ),
        ],
        const SizedBox(height: CinevaSpacing.md),
        SizedBox(
          height: 194,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: section.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: CinevaSpacing.md),
            itemBuilder: (context, index) => _ContinueWatchingCard(item: section.items[index]),
          ),
        ),
      ],
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({required this.item});

  final ContentTileModel item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: HomeScreenLayout.continueWatchingCardWidth(MediaQuery.of(context).size.width),
      child: Semantics(
        button: true,
        label: 'Reprendre ${item.title}',
        value: '${((item.progressPercent ?? 0) * 100).round()} pour cent visionné',
        child: InkWell(
          borderRadius: BorderRadius.circular(CinevaRadii.medium),
          onTap: () => GoRouter.of(context).push('/player/${Uri.encodeComponent(item.id)}'),
          child: CinevaGlassCard(
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 120,
                  child: AspectRatio(
                    aspectRatio: 0.95,
                    child: CinevaArtwork(
                      content: item,
                      borderRadius: BorderRadius.circular(CinevaRadii.medium),
                      showTypeBadge: true,
                    ),
                  ),
                ),
                const SizedBox(width: CinevaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: item.progressPercent ?? 0,
                          backgroundColor: CinevaColors.surfaceRaised,
                        ),
                      ),
                      const SizedBox(height: CinevaSpacing.sm),
                      Text(
                        '${((item.progressPercent ?? 0) * 100).round()}% visionné',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailSection extends StatelessWidget {
  const _RailSection({required this.section});

  final HomeSectionModel section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: CinevaSectionTitle(title: section.title, actionLabel: '${section.items.length} éléments'),
        ),
        if (section.description != null) ...<Widget>[
          const SizedBox(height: CinevaSpacing.xs),
          Text(
            section.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
          ),
        ],
        const SizedBox(height: CinevaSpacing.md),
        SizedBox(
          height: 274,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) => CinevaPosterCard(
              item: section.items[index],
              onTap: () => GoRouter.of(context).push('/content/${Uri.encodeComponent(section.items[index].id)}'),
            ),
            separatorBuilder: (_, __) => const SizedBox(width: CinevaSpacing.md),
            itemCount: section.items.length,
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
