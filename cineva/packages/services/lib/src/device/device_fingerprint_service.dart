import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../storage/local_preferences_service.dart';

class DeviceFingerprintService {
  DeviceFingerprintService(this._localPreferencesService);

  final LocalPreferencesService _localPreferencesService;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getOrCreateFingerprint() async {
    final existing = await _localPreferencesService.readDeviceFingerprint();
    if (existing != null && existing.isNotEmpty) return existing;

    final packageInfo = await PackageInfo.fromPlatform();
    final buffer = StringBuffer(packageInfo.packageName)..write('|')..write(packageInfo.version);

    try {
      if (kIsWeb) {
        final info = await _deviceInfo.webBrowserInfo;
        buffer
          ..write('|')
          ..write(info.browserName.name)
          ..write('|')
          ..write(info.userAgent)
          ..write('|')
          ..write(info.platform);
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await _deviceInfo.androidInfo;
            buffer
              ..write('|')
              ..write(info.brand)
              ..write('|')
              ..write(info.model)
              ..write('|')
              ..write(info.id);
          case TargetPlatform.iOS:
            final info = await _deviceInfo.iosInfo;
            buffer
              ..write('|')
              ..write(info.model)
              ..write('|')
              ..write(info.systemName)
              ..write('|')
              ..write(info.identifierForVendor);
          case TargetPlatform.macOS:
            final info = await _deviceInfo.macOsInfo;
            buffer
              ..write('|')
              ..write(info.model)
              ..write('|')
              ..write(info.computerName)
              ..write('|')
              ..write(info.systemGUID);
          case TargetPlatform.windows:
            final info = await _deviceInfo.windowsInfo;
            buffer
              ..write('|')
              ..write(info.computerName)
              ..write('|')
              ..write(info.productId)
              ..write('|')
              ..write(info.numberOfCores);
          case TargetPlatform.linux:
            final info = await _deviceInfo.linuxInfo;
            buffer
              ..write('|')
              ..write(info.name)
              ..write('|')
              ..write(info.machineId)
              ..write('|')
              ..write(info.version);
          case TargetPlatform.fuchsia:
            buffer
              ..write('|fuchsia|')
              ..write(PlatformDispatcher.instance.locale.toLanguageTag());
        }
      }
    } catch (_) {
      buffer
        ..write('|fallback|')
        ..write(DateTime.now().millisecondsSinceEpoch);
    }

    final digest = sha256.convert(utf8.encode(buffer.toString())).toString();
    await _localPreferencesService.saveDeviceFingerprint(digest);
    return digest;
  }

  Future<String> resolvePlatformLabel() async {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<String> resolveDeviceName() async {
    try {
      if (kIsWeb) {
        final info = await _deviceInfo.webBrowserInfo;
        return info.browserName.name;
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _deviceInfo.androidInfo;
          return '${info.brand} ${info.model}'.trim();
        case TargetPlatform.iOS:
          final info = await _deviceInfo.iosInfo;
          return info.name;
        case TargetPlatform.macOS:
          final info = await _deviceInfo.macOsInfo;
          return info.computerName;
        case TargetPlatform.windows:
          final info = await _deviceInfo.windowsInfo;
          return info.computerName;
        case TargetPlatform.linux:
          final info = await _deviceInfo.linuxInfo;
          return info.prettyName;
        case TargetPlatform.fuchsia:
          return 'Fuchsia';
      }
    } catch (_) {}
    return 'Appareil Cineva';
  }
}
