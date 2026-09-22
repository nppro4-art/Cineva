import 'dart:async';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';

/// Coquille de l'application abonné.
///
/// Mobile (et TV) : navigation basse fixe, contenu pleine largeur qui passe
/// sous la barre (`extendBody`), transition douce entre les sections.
/// Desktop : rail latéral (hors périmètre de la refonte mobile).
class AdaptiveUserShell extends StatelessWidget {
  const AdaptiveUserShell({
    super.key,
    required this.navigationShell,
    required this.target,
  });

  final StatefulNavigationShell navigationShell;
  final AppTarget target;

  @override
  Widget build(BuildContext context) {
    if (target.isDesktop) {
      return _DesktopShell(navigationShell: navigationShell, target: target);
    }
    return _MobileShell(navigationShell: navigationShell);
  }
}

class _MobileShell extends ConsumerStatefulWidget {
  const _MobileShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<_MobileShell> {
  void _handleSelect(int index) {
    if (index == widget.navigationShell.currentIndex) {
      // Re-taper sur l'onglet courant remonte en haut de la section.
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    widget.navigationShell.goBranch(index);
  }

  @override
  Widget build(BuildContext context) {
    // Uniquement le compteur : la coquille ne se reconstruit pas à chaque
    // changement d'état de la bibliothèque.
    final int pending = ref.watch(
      libraryControllerProvider.select(
        (LibraryState state) =>
            state.downloads.where((DownloadItemModel item) => !item.isCompleted).length,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: CinevaTheme.overlay,
      child: Scaffold(
        backgroundColor: CinevaColors.ink,
        extendBody: true,
        body: CinevaSurface(
          child: _BranchTransition(
            index: widget.navigationShell.currentIndex,
            child: widget.navigationShell,
          ),
        ),
        bottomNavigationBar: CinevaBottomNavigation(
          currentIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _handleSelect,
          destinations: <CinevaNavDestination>[
            const CinevaNavDestination(
              label: 'Accueil',
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
            ),
            const CinevaNavDestination(
              label: 'Recherche',
              icon: Icons.search_rounded,
            ),
            CinevaNavDestination(
              label: 'Téléchargements',
              icon: Icons.download_outlined,
              activeIcon: Icons.download_rounded,
              badgeCount: pending,
            ),
            const CinevaNavDestination(
              label: 'Bibliothèque',
              icon: Icons.video_library_outlined,
              activeIcon: Icons.video_library_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fond enchaîné entre deux sections : léger fondu + translation, sans jamais
/// reconstruire l'`IndexedStack` (les branches conservent leur état).
class _BranchTransition extends StatefulWidget {
  const _BranchTransition({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchTransition> createState() => _BranchTransitionState();
}

class _BranchTransitionState extends State<_BranchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CinevaMotion.medium,
    value: 1,
  );

  @override
  void didUpdateWidget(_BranchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (BuildContext context, Widget? child) {
          final double t = CinevaCurve.out.transform(_controller.value);
          return Opacity(
            opacity: 0.4 + (0.6 * t),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 8),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.navigationShell, required this.target});

  final StatefulNavigationShell navigationShell;
  final AppTarget target;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: SafeArea(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: target.isTv ? 260 : 240,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: CinevaColors.surface,
                  border: Border(right: BorderSide(color: CinevaColors.hairline)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(CinevaSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const CinevaWordmark(),
                      const SizedBox(height: CinevaSpacing.xs),
                      Text(
                        target.isTv ? 'Mode Android TV' : 'Mode desktop',
                        style: CinevaTypography.meta,
                      ),
                      const SizedBox(height: CinevaSpacing.xl),
                      _NavTile(
                        icon: Icons.home_rounded,
                        label: 'Accueil',
                        selected: navigationShell.currentIndex == 0,
                        onTap: () => navigationShell.goBranch(0),
                      ),
                      _NavTile(
                        icon: Icons.search_rounded,
                        label: 'Recherche',
                        selected: navigationShell.currentIndex == 1,
                        onTap: () => navigationShell.goBranch(1),
                      ),
                      _NavTile(
                        icon: Icons.download_rounded,
                        label: 'Téléchargements',
                        selected: navigationShell.currentIndex == 2,
                        onTap: () => navigationShell.goBranch(2),
                      ),
                      _NavTile(
                        icon: Icons.video_library_rounded,
                        label: 'Bibliothèque',
                        selected: navigationShell.currentIndex == 3,
                        onTap: () => navigationShell.goBranch(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.xs),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(CinevaRadii.small),
          onTap: onTap,
          child: AnimatedContainer(
            duration: CinevaMotion.fast,
            curve: CinevaCurve.out,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? CinevaColors.raised : Colors.transparent,
              borderRadius: BorderRadius.circular(CinevaRadii.small),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? CinevaColors.gold : CinevaColors.textSoft,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: CinevaTypography.cardTitle.copyWith(
                    fontSize: 14,
                    color: selected ? CinevaColors.textHigh : CinevaColors.textSoft,
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
