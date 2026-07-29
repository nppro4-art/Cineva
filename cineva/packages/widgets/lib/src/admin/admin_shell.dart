import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CinevaScaffoldContainer(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 280,
              child: CinevaGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Cineva Admin', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: CinevaSpacing.sm),
                    Text(
                      'Pilotage utilisateurs, catalogue, abonnements, notifications et santé globale de la plateforme.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                    ),
                    const SizedBox(height: CinevaSpacing.lg),
                    _AdminNavTile(index: 0, currentIndex: navigationShell.currentIndex, icon: Icons.dashboard_rounded, label: 'Dashboard', navigationShell: navigationShell),
                    _AdminNavTile(index: 1, currentIndex: navigationShell.currentIndex, icon: Icons.group_rounded, label: 'Utilisateurs', navigationShell: navigationShell),
                    _AdminNavTile(index: 2, currentIndex: navigationShell.currentIndex, icon: Icons.video_library_rounded, label: 'Catalogue', navigationShell: navigationShell),
                    _AdminNavTile(index: 3, currentIndex: navigationShell.currentIndex, icon: Icons.notifications_active_rounded, label: 'Notifications', navigationShell: navigationShell),
                    _AdminNavTile(index: 4, currentIndex: navigationShell.currentIndex, icon: Icons.query_stats_rounded, label: 'Statistiques', navigationShell: navigationShell),
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

class _AdminNavTile extends StatelessWidget {
  const _AdminNavTile({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.navigationShell,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(CinevaRadii.small),
        onTap: () => navigationShell.goBranch(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? CinevaColors.accent.withOpacity(0.16) : CinevaColors.surfaceRaised,
            borderRadius: BorderRadius.circular(CinevaRadii.small),
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
