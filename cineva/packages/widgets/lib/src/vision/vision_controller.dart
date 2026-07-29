import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VisionState extends Equatable {
  const VisionState({
    this.capabilities,
    this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final DeviceCapabilities? capabilities;
  final CinevaVisionSettings? settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  bool get ready => capabilities != null && settings != null;

  VisionState copyWith({
    DeviceCapabilities? capabilities,
    CinevaVisionSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VisionState(
      capabilities: capabilities ?? this.capabilities,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        capabilities,
        settings,
        isLoading,
        isSaving,
        errorMessage,
      ];
}

class VisionController extends StateNotifier<VisionState> {
  VisionController({
    required CinevaVisionService visionService,
    required VisionSettingsRepository repository,
  })  : _visionService = visionService,
        _repository = repository,
        super(const VisionState(isLoading: true)) {
    initialize();
  }

  final CinevaVisionService _visionService;
  final VisionSettingsRepository _repository;

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final capabilities = await _visionService.analyzeDevice();
      final stored = await _repository.loadVisionSettings();
      final settings = stored.autoRecommended
          ? _visionService.recommendedSettings(capabilities)
          : _visionService.sanitize(stored, capabilities);
      state = state.copyWith(
        capabilities: capabilities,
        settings: settings,
        isLoading: false,
        clearError: true,
      );
      if (stored != settings) {
        await _repository.saveVisionSettings(settings);
      }
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> applyRecommended() async {
    final capabilities = state.capabilities;
    if (capabilities == null) return;
    final settings = _visionService.recommendedSettings(capabilities);
    await _save(settings.copyWith(autoRecommended: true));
  }

  Future<void> setProfile(CinevaVisionProfile profile) async {
    final capabilities = state.capabilities;
    final current = state.settings;
    if (capabilities == null || current == null) return;
    final recommended = _visionService.recommendedSettings(capabilities);
    final baseOptions = profile == recommended.profile ? recommended.options : current.options;
    final next = _visionService.sanitize(
      current.copyWith(
        profile: profile,
        options: baseOptions,
        autoRecommended: false,
      ),
      capabilities,
    );
    await _save(next);
  }

  Future<void> setAutoRecommended(bool enabled) async {
    final capabilities = state.capabilities;
    final current = state.settings;
    if (capabilities == null || current == null) return;
    final next = enabled
        ? _visionService.recommendedSettings(capabilities)
        : current.copyWith(autoRecommended: false);
    await _save(next.copyWith(autoRecommended: enabled));
  }

  Future<void> updateOptions(CinevaVisionOptions options) async {
    final capabilities = state.capabilities;
    final current = state.settings;
    if (capabilities == null || current == null) return;
    final next = _visionService.sanitize(
      current.copyWith(
        profile: CinevaVisionProfile.custom,
        options: options,
        autoRecommended: false,
      ),
      capabilities,
    );
    await _save(next);
  }

  Future<void> _save(CinevaVisionSettings settings) async {
    state = state.copyWith(settings: settings, isSaving: true, clearError: true);
    try {
      await _repository.saveVisionSettings(settings);
      state = state.copyWith(isSaving: false, settings: settings, clearError: true);
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }
}
