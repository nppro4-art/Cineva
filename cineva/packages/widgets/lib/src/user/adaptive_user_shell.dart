import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    if (target.isMobileLike) {
      return Scaffold(
        body: CinevaScaffoldContainer(padding: EdgeInsets.zero, child: navigationShell),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(index),
          destinations: const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Recherche'),
            NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download_done_rounded), label: 'Téléchargements'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Compte'),
          ],
        ),
      );
    }

    return Scaffold(
      body: CinevaScaffoldContainer(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: target.isTv ? 260 : 240,
              child: CinevaGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Cineva', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: CinevaSpacing.sm),
                    Text(
                      target.isTv ? 'Mode Android TV' : 'Mode desktop premium',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                    ),
                    const SizedBox(height: CinevaSpacing.lg),
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
                      icon: Icons.person_rounded,
                      label: 'Compte',
                      selected: navigationShell.currentIndex == 3,
                      onTap: () => navigationShell.goBranch(3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CinevaSpacing.lg),
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
      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(CinevaRadii.small),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? CinevaColors.accent.withOpacity(0.16) : CinevaColors.surfaceRaised,
            borderRadius: BorderRadius.circular(CinevaRadii.small),
            border: Border.all(color: selected ? CinevaColors.accentSoft : Colors.transparent),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: selected ? CinevaColors.accentSoft : null),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
