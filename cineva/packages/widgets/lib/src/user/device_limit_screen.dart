import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/session_controller.dart';

/// Limite d'appareils atteinte : liste réelle des appareils du compte, avec
/// déconnexion unitaire et actualisation de la session.
class DeviceLimitScreen extends ConsumerWidget {
  const DeviceLimitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionSnapshot? session = ref.watch(sessionControllerProvider).valueOrNull;
    final List<DeviceModel> devices = session?.devices ?? const <DeviceModel>[];
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(metrics.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: CinevaColors.surface,
                    ),
                    child: const Icon(
                      Icons.devices_other_outlined,
                      size: 24,
                      color: CinevaColors.warning,
                    ),
                  ),
                  const SizedBox(height: CinevaSpacing.lg),
                  Text(
                    'Limite d’appareils atteinte',
                    style: CinevaTypography.screenTitle.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: CinevaSpacing.xs),
                  Text(
                    'Ce compte est déjà utilisé sur le nombre maximum d’appareils '
                    'autorisé. Déconnectez-en un pour continuer ici.',
                    style: CinevaTypography.bodyCompact,
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  ...devices.map(
                    (DeviceModel device) => Padding(
                      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CinevaColors.surface,
                          borderRadius: BorderRadius.circular(CinevaRadii.card),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            CinevaSpacing.md,
                            CinevaSpacing.xs,
                            CinevaSpacing.xs,
                            CinevaSpacing.xs,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      device.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: CinevaTypography.cardTitle.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      device.platform.toUpperCase(),
                                      style: CinevaTypography.overline.copyWith(
                                        fontSize: 9,
                                      ),
                                    ),
                                    const SizedBox(height: CinevaSpacing.xs),
                                  ],
                                ),
                              ),
                              CinevaIconButton(
                                icon: Icons.logout_rounded,
                                filled: false,
                                size: 38,
                                tooltip: 'Déconnecter ${device.displayName}',
                                onPressed: () => _remove(context, ref, device),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  CinevaPlayButton(
                    label: 'Actualiser la session',
                    icon: Icons.refresh_rounded,
                    height: 48,
                    onPressed: () => ref
                        .read(sessionControllerProvider.notifier)
                        .refresh(showLoader: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    DeviceModel device,
  ) async {
    final SessionController controller =
        ref.read(sessionControllerProvider.notifier);
    await controller.removeDevice(device.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 2200),
          content: Text('Appareil déconnecté. Réessayez la lecture.'),
        ),
      );
  }
}
