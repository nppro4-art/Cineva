import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';

import 'admin_supabase_gateway.dart';
import 'admin_user_query_support.dart';
import 'supabase_support.dart';

class SupabaseAdminUsersRepository {
  SupabaseAdminUsersRepository(this._gateway);

  final AdminSupabaseGateway _gateway;

  Future<void> addMonths({required String userId, required int months, String? note}) {
    return _gateway.runRpc(
      'extend_subscription_months',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_months': months,
        'p_note': note,
      },
    );
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    String role = 'user',
    DateTime? expiresAt,
  }) {
    return _gateway.invokeCheckedFunction(
      'admin-user-management',
      body: <String, dynamic>{
        'action': 'create',
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': role,
        'expiresAt': expiresAt?.toIso8601String(),
      },
      failureMessage: 'Création utilisateur impossible.',
    );
  }

  Future<void> deleteUser(String userId) {
    return _gateway.invokeCheckedFunction(
      'admin-user-management',
      body: <String, dynamic>{
        'action': 'delete',
        'userId': userId,
      },
      failureMessage: 'Suppression utilisateur impossible.',
    );
  }

  Future<void> disconnectAllDevices(String userId) {
    return _gateway.runRpc(
      'disconnect_all_devices',
      params: <String, dynamic>{'p_target_user_id': userId},
    );
  }

  Future<List<DeviceModel>> fetchUserDevices(String userId) async {
    final client = await _gateway.client();
    final rows = await client.from(SupabaseConstants.devicesTable).select().eq('user_id', userId).order('last_seen_at', ascending: false);
    return rows.map<DeviceModel>((dynamic row) => mapDevice(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<AppUser>> fetchUsers({String query = '', AdminUserFilter filter = AdminUserFilter.all}) async {
    final client = await _gateway.client();
    final rows = await client.from(SupabaseConstants.profilesTable).select().order('created_at', ascending: false);
    final now = DateTime.now();

    return rows
        .map<AppUser>((dynamic row) => mapAppUser(Map<String, dynamic>.from(row as Map)))
        .where((user) => AdminUserQuerySupport.matchesUser(user, query: query, filter: filter, now: now))
        .toList();
  }

  Future<void> reactivateUser({required String userId, String? note}) {
    return _gateway.runRpc(
      'reactivate_user_subscription',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_note': note,
      },
    );
  }

  Future<void> removeUserDevice(String deviceId) {
    return _gateway.runRpc(
      'remove_device',
      params: <String, dynamic>{'p_device_id': deviceId},
    );
  }

  Future<void> resetPassword({required String email}) async {
    final client = await _gateway.client();
    await client.auth.resetPasswordForEmail(email);
  }

  Future<void> setExpiration({required String userId, required DateTime expiresAt, String? note}) {
    return _gateway.runRpc(
      'set_subscription_expiration',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_expires_at': expiresAt.toIso8601String(),
        'p_note': note,
      },
    );
  }

  Future<void> suspendUser({required String userId, String? note}) {
    return _gateway.runRpc(
      'suspend_user_subscription',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_note': note,
      },
    );
  }

  Future<void> updateUserProfile({
    required String userId,
    required String email,
    required String fullName,
    required String role,
    required String status,
    DateTime? expiresAt,
  }) {
    return _gateway.invokeCheckedFunction(
      'admin-user-management',
      body: <String, dynamic>{
        'action': 'update',
        'userId': userId,
        'email': email,
        'fullName': fullName,
        'role': role,
        'status': status,
        'expiresAt': expiresAt?.toIso8601String(),
      },
      failureMessage: 'Mise à jour utilisateur impossible.',
    );
  }
}
