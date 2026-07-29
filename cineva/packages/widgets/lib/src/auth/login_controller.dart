import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/session_controller.dart';

class LoginController extends StateNotifier<AsyncValue<void>?> {
  LoginController({
    required AuthRepository authRepository,
    required LocalPreferencesService localPreferencesService,
    required SessionController sessionController,
  })  : _authRepository = authRepository,
        _localPreferencesService = localPreferencesService,
        _sessionController = sessionController,
        super(null);

  final AuthRepository _authRepository;
  final LocalPreferencesService _localPreferencesService;
  final SessionController _sessionController;

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signIn(email: email.trim(), password: password);
      await _localPreferencesService.saveLastEmail(email.trim());
      await _sessionController.refresh(showLoader: false);
    });
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signUp(fullName: fullName.trim(), email: email.trim(), password: password);
      await _localPreferencesService.saveLastEmail(email.trim());
      await _sessionController.refresh(showLoader: false);
    });
  }

  Future<void> resetPassword({required String email}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.resetPassword(email: email.trim());
    });
  }

  void clear() => state = null;
}
