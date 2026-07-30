import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_repository.dart';
import 'supabase_support.dart';

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository({
    required BackendService backendService,
    required DeviceFingerprintService deviceFingerprintService,
    required PushNotificationService pushNotificationService,
  })  : _backendService = backendService,
        _deviceFingerprintService = deviceFingerprintService,
        _pushNotificationService = pushNotificationService;

  final BackendService _backendService;
  final DeviceFingerprintService _deviceFingerprintService;
  final PushNotificationService _pushNotificationService;

  @override
  Future<SessionSnapshot> bootstrap({
    required AppTarget target,
    required AppSurface surface,
  }) async {
    final backendState = await _backendService.ensureInitialized();
    final client = _backendService.client;

    if (!backendState.supabaseReady || client == null) {
      return SessionSnapshot.guest(
        target: target,
        surface: surface,
        supabaseReady: backendState.supabaseReady,
        firebaseReady: backendState.firebaseReady,
        message: backendState.supabaseMessage ?? backendState.firebaseMessage,
      );
    }

    final authUser = client.auth.currentUser;
    if (authUser == null) {
      return SessionSnapshot.guest(
        target: target,
        surface: surface,
        supabaseReady: backendState.supabaseReady,
        firebaseReady: backendState.firebaseReady,
        message: backendState.firebaseMessage,
      );
    }

    final user = await _fetchProfile(client, authUser.id);
    var deviceLimitReached = false;

    if (!user.isAdmin) {
      deviceLimitReached = await _registerDeviceIfPossible(client, target);
    }

    final devices = await _fetchDevices(client);
    final pushToken = await _pushNotificationService.initializeAndGetToken(firebaseReady: backendState.firebaseReady);
    if (pushToken != null && !user.isAdmin) {
      await _registerPushToken(client, pushToken);
    }

    return SessionSnapshot(
      target: target,
      surface: surface,
      supabaseReady: backendState.supabaseReady,
      firebaseReady: backendState.firebaseReady,
      isBootstrapping: false,
      user: user,
      devices: devices,
      deviceLimitReached: deviceLimitReached,
      message: backendState.firebaseMessage ?? backendState.supabaseMessage,
    );
  }

  @override
  Future<void> disconnectAllDevices({String? userId}) async {
    final client = await _client();
    await client.rpc('disconnect_all_devices', params: <String, dynamic>{
      'p_target_user_id': userId,
    });
  }

  @override
  Future<List<DeviceModel>> fetchDevices() async {
    final client = await _client();
    return _fetchDevices(client);
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    final client = await _client();
    await client.rpc('remove_device', params: <String, dynamic>{
      'p_device_id': deviceId,
    });
  }

  Future<AppUser> _fetchProfile(SupabaseClient client, String userId) async {
    dynamic row;

    try {
      row = await client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', userId)
          .single();
    } on PostgrestException {
      final authUser = client.auth.currentUser;
      if (authUser == null) {
        rethrow;
      }

      await client.from(SupabaseConstants.profilesTable).upsert(<String, dynamic>{
        'id': authUser.id,
        'email': authUser.email,
        'full_name': (authUser.userMetadata?['full_name'] as String?) ?? 'Utilisateur Cineva',
      });

      row = await client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', userId)
          .single();
    }

    return mapAppUser(Map<String, dynamic>.from(row as Map));
  }

  Future<List<DeviceModel>> _fetchDevices(SupabaseClient client) async {
    final rows = await client
        .from(SupabaseConstants.devicesTable)
        .select()
        .order('last_seen_at', ascending: false);

    return rows
        .map<DeviceModel>((dynamic row) => mapDevice(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<bool> _registerDeviceIfPossible(SupabaseClient client, AppTarget target) async {
    final fingerprint = await _deviceFingerprintService.getOrCreateFingerprint();
    final platform = target == AppTarget.androidTv
        ? 'androidTv'
        : await _deviceFingerprintService.resolvePlatformLabel();
    final deviceName = await _deviceFingerprintService.resolveDeviceName();

    try {
      await client.rpc('register_device', params: <String, dynamic>{
        'p_device_fingerprint': fingerprint,
        'p_device_name': deviceName,
        'p_platform': platform,
        'p_app_version': '0.1.0',
      });
      return false;
    } on PostgrestException catch (error) {
      final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
      if (message.contains('device_limit_reached') ||
          message.contains('tv_limit_reached')) {
        return true;
      }
      rethrow;
    }
  }

  Future<void> _registerPushToken(SupabaseClient client, String token) async {
    final fingerprint = await _deviceFingerprintService.getOrCreateFingerprint();
    try {
      await client
          .from(SupabaseConstants.devicesTable)
          .update(<String, dynamic>{
            'push_token': token,
            'push_token_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', client.auth.currentUser!.id)
          .eq('device_fingerprint', fingerprint);
    } catch (_) {}
  }

  Future<SupabaseClient> _client() async {
    final state = await _backendService.ensureInitialized();
    final client = _backendService.client;
    if (!state.supabaseReady || client == null) {
      throw const AppFailure('Supabase n’est pas configuré.', code: 'SUPABASE_NOT_READY');
    }
    return client;
  }
}
