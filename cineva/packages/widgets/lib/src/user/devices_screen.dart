import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/session_controller.dart';

/// Appareils connectés au compte Cineva (route `/account/devices`).
///
/// Liste réelle issue de [SessionSnapshot.devices] : déconnexion d'un appareil
/// ou de tous les appareils, avec confirmation et retour visuel.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SessionSnapshot> sessionAsync =
        ref.watch(sessionControllerProvider);
    final SessionSnapshot? session = sessionAsync.valueOrNull;
    final List<DeviceModel> devices = session?.devices ?? const <DeviceModel>[];
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(sessionControllerProvider.notifier).refresh(showLoader: false),
        color: CinevaColors.gold,
        backgroundColor: CinevaColors.raised,
        edgeOffset: 96,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
            decelerationRate: ScrollDecelerationRate.fast,
          ),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: CinevaTopBar(
                title: 'Appareils',
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/profile'),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                metrics.gutter,
                CinevaSpacing.sm,
                metrics.gutter,
                CinevaSpacing.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    Text(
                      devices.length == 1
                          ? '1 appareil connecté'
                          : '${devices.length} appareils connectés',
                      style: CinevaTypography.screenTitle.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: CinevaSpacing.xs),
                    Text(
                      'Votre abonnement autorise un nombre limité d’appareils. '
                      'Déconnectez ceux que vous n’utilisez plus.',
                      style: CinevaTypography.bodyCompact,
                    ),
                    if (session?.deviceLimitReached ?? false) ...<Widget>[
                      const SizedBox(height: CinevaSpacing.md),
                      const CinevaStatusBanner(
                        title: 'Limite atteinte',
                        message:
                            'Déconnectez un appareil pour reprendre la lecture sur celui-ci.',
                        tone: CinevaBannerTone.warning,
                      ),
                    ],
                    if (sessionAsync.isLoading && session == null) ...<Widget>[
                      const SizedBox(height: CinevaSpacing.lg),
                      ...List<Widget>.generate(
                        3,
                        (int index) => const Padding(
                          padding: EdgeInsets.only(bottom: CinevaSpacing.sm),
                          child: CinevaSkeleton(height: 74),
                        ),
                      ),
                    ] else if (devices.isEmpty) ...<Widget>[
                      const SizedBox(height: CinevaSpacing.xxl),
                      const Center(
                        child: Icon(Icons.devices_other_outlined,
                            size: 28, color: CinevaColors.textFaint),
                      ),
                      const SizedBox(height: CinevaSpacing.md),
                      Center(
                        child: Text(
                          'Aucun appareil enregistré',
                          style: CinevaTypography.cardTitle.copyWith(fontSize: 14),
                        ),
                      ),
                    ] else ...<Widget>[
                      const SizedBox(height: CinevaSpacing.lg),
                      ...devices.map(
                        (DeviceModel device) => Padding(
                          padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                          child: _DeviceCard(
                            device: device,
                            onRemove: () => _remove(context, ref, device),
                          ),
                        ),
                      ),
                      const SizedBox(height: CinevaSpacing.md),
                      CinevaSecondaryButton(
                        label: 'Tout déconnecter',
                        icon: Icons.logout_rounded,
                        tone: CinevaButtonTone.danger,
                        height: 46,
                        onPressed: devices.length < 2
                            ? null
                            : () => _removeAll(context, ref, devices.length),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    DeviceModel device,
  ) async {
    final bool confirmed = await CinevaDialog.show(
      context,
      title: 'Déconnecter cet appareil',
      message: '« ${device.displayName} » devra se reconnecter pour lire du contenu.',
      confirmLabel: 'Déconnecter',
      cancelLabel: 'Annuler',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (!confirmed) return;

    final SessionController controller =
        ref.read(sessionControllerProvider.notifier);
    await controller.removeDevice(device.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2000),
          content: Text('${device.displayName} déconnecté.'),
        ),
      );
  }

  Future<void> _removeAll(BuildContext context, WidgetRef ref, int count) async {
    final bool confirmed = await CinevaDialog.show(
      context,
      title: 'Tout déconnecter',
      message: 'Les $count appareils devront se reconnecter, y compris celui-ci.',
      confirmLabel: 'Tout déconnecter',
      cancelLabel: 'Annuler',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (!confirmed) return;

    final SessionController controller =
        ref.read(sessionControllerProvider.notifier);
    await controller.disconnectAllDevices();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 2000),
          content: Text('Tous les appareils ont été déconnectés.'),
        ),
      );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onRemove});

  final DeviceModel device;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String platform = device.platform;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.sm + 2),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CinevaColors.raised,
              ),
              child: Icon(_iconFor(platform), size: 19, color: CinevaColors.textSoft),
            ),
            const SizedBox(width: CinevaSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          device.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CinevaTypography.cardTitle.copyWith(fontSize: 14),
                        ),
                      ),
                      if (device.isActive) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: CinevaColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    <String>[
                      platform.toUpperCase(),
                      device.appVersion ?? 'version inconnue',
                      _lastSeenLabel(device.lastSeenAt),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CinevaTypography.meta.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            CinevaIconButton(
              icon: Icons.delete_outline_rounded,
              filled: false,
              size: 36,
              tooltip: 'Déconnecter ${device.displayName}',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String platform) {
    final String value = platform.toLowerCase();
    if (value.contains('ios') || value.contains('iphone') || value.contains('ipad')) {
      return Icons.phone_iphone_rounded;
    }
    if (value.contains('android')) return Icons.smartphone_rounded;
    if (value.contains('tv')) return Icons.tv_rounded;
    if (value.contains('mac') || value.contains('windows') || value.contains('linux')) {
      return Icons.desktop_windows_rounded;
    }
    if (value.contains('web')) return Icons.public_rounded;
    return Icons.devices_other_outlined;
  }

  /// Horodatage relatif lisible, sans dépendance supplémentaire.
  static String _lastSeenLabel(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return 'jamais utilisé';
    final Duration diff = DateTime.now().difference(lastSeenAt);
    if (diff.inMinutes < 1) return 'à l’instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
    final String day = lastSeenAt.day.toString().padLeft(2, '0');
    final String month = lastSeenAt.month.toString().padLeft(2, '0');
    return 'vu le $day/$month/${lastSeenAt.year}';
  }
}
