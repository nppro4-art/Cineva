import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSupabaseGateway {
  AdminSupabaseGateway(this._backendService);

  final BackendService _backendService;

  Future<SupabaseClient> client() async {
    final state = await _backendService.ensureInitialized();
    final client = _backendService.client;
    if (!state.supabaseReady || client == null) {
      throw const AppFailure('Supabase n’est pas configuré.', code: 'SUPABASE_NOT_READY');
    }
    return client;
  }

  Future<void> invokeCheckedFunction(
    String name, {
    required Map<String, dynamic> body,
    required String failureMessage,
  }) async {
    final client = await this.client();
    final response = await client.functions.invoke(name, body: body);
    if (response.status >= 400) {
      throw AppFailure(failureMessage, details: response.data);
    }
  }

  Future<void> runRpc(String name, {required Map<String, dynamic> params}) async {
    final client = await this.client();
    await client.rpc(name, params: params);
  }
}
