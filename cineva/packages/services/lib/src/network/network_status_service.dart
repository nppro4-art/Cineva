import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatusService {
  NetworkStatusService() {
    _controller = StreamController<bool>.broadcast(
      onListen: () async {
        _controller.add(await isConnected());
      },
    );
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((result) => result != ConnectivityResult.none);
      _controller.add(connected);
    });
  }

  late final StreamController<bool> _controller;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  Stream<bool> get statusStream => _controller.stream;

  Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
