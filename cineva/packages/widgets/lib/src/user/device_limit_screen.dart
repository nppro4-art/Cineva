import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class DeviceLimitScreen extends ConsumerWidget {
  const DeviceLimitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;

    return Scaffold(
      body: CinevaScaffoldContainer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                CinevaGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Limite d’appareils atteinte', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: CinevaSpacing.md),
                      Text(
                        'Ce compte est déjà utilisé sur un autre appareil. Supprimez un appareil pour continuer.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: CinevaColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CinevaSpacing.lg),
                ...?session?.devices.map(
                  (device) => Padding(
                    padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                    child: CinevaGlassCard(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(device.displayName, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  device.platform.toUpperCase(),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref.read(sessionControllerProvider.notifier).removeDevice(device.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Appareil supprimé. Réessayez la connexion.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: CinevaSpacing.md),
                SizedBox(
                  width: 240,
                  child: CinevaPrimaryButton(
                    label: 'Actualiser la session',
                    icon: Icons.refresh_rounded,
                    onPressed: () => ref.read(sessionControllerProvider.notifier).refresh(showLoader: false),
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
