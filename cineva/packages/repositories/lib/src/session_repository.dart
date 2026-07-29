import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';

abstract interface class SessionRepository {
  Future<SessionSnapshot> bootstrap({
    required AppTarget target,
    required AppSurface surface,
  });

  Future<List<DeviceModel>> fetchDevices();

  Future<void> removeDevice(String deviceId);

  Future<void> disconnectAllDevices({String? userId});
}
