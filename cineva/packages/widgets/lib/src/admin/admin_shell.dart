import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Coque de l'application admin.
///
/// Sur les écrans larges (>= 700 px) : barre latérale fixe.
/// Sous 700 px (mobile) : la navigation passe en bas d'écran pour rester
/// utilisable avec un pouce.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.navigationShell});

  /// Largeur minimale (en px) au-dessus de laquelle la barre latérale s'affiche.
  static const double _wideBreakpoint = 700;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideBreakpoint) {
          return _buildMobile(context);
        }
        return _buildWide(context);
      },
    );
  }

  Widget _buildWide(BuildContext context) {
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

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      body: CinevaScaffoldContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            Expanded(child: navigationShell),
            _AdminMobileNavBar(
              currentIndex: navigationShell.currentIndex,
              onNavigate: navigationShell.goBranch,
            ),
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

/// Barre de navigation mobile (bas d'écran), visible sous 700 px.
class _AdminMobileNavBar extends StatelessWidget {
  const _AdminMobileNavBar({required this.currentIndex, required this.onNavigate});

  final int currentIndex;
  final ValueChanged<int> onNavigate;

  static const List<_AdminMobileDestination> _destinations = <_AdminMobileDestination>[
    _AdminMobileDestination(Icons.dashboard_rounded, 'Tableau'),
    _AdminMobileDestination(Icons.group_rounded, 'Comptes'),
    _AdminMobileDestination(Icons.video_library_rounded, 'Catalogue'),
    _AdminMobileDestination(Icons.notifications_active_rounded, 'Alertes'),
    _AdminMobileDestination(Icons.query_stats_rounded, 'Stats'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: CinevaSpacing.sm, vertical: CinevaSpacing.xs),
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        border: Border(top: BorderSide(color: CinevaColors.border)),
      ),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < _destinations.length; index += 1)
            Expanded(
              child: _AdminMobileNavItem(
                destination: _destinations[index],
                selected: index == currentIndex,
                onTap: () => onNavigate(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminMobileDestination {
  const _AdminMobileDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _AdminMobileNavItem extends StatelessWidget {
  const _AdminMobileNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _AdminMobileDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(CinevaRadii.small),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(destination.icon, size: 22, color: selected ? CinevaColors.accent : null),
          const SizedBox(height: 2),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: selected ? CinevaColors.accent : CinevaColors.textMuted),
          ),
        ],
      ),
    );
  }
}
