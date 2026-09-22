import 'package:cineva_desktop_video/cineva_desktop_video.dart';
import 'package:cineva_widgets/cineva_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Le registre est global : chaque test part de la fabrique par défaut.
  tearDown(CinevaVideoControllers.reset);

  group('conversion de volume', () {
    test('0.0 → 1.0 devient 0 → 100', () {
      expect(mediaKitVolumeFromNormalized(0), 0.0);
      expect(mediaKitVolumeFromNormalized(0.35), closeTo(35, 1e-9));
      expect(mediaKitVolumeFromNormalized(1), 100.0);
    });

    test('les valeurs hors bornes sont écrêtées', () {
      expect(mediaKitVolumeFromNormalized(-0.5), 0.0);
      expect(mediaKitVolumeFromNormalized(2), 100.0);
      expect(normalizedVolumeFromMediaKit(-10), 0.0);
      expect(normalizedVolumeFromMediaKit(250), 1.0);
    });

    test('100 → 0 devient 1.0 → 0.0', () {
      expect(normalizedVolumeFromMediaKit(0), 0.0);
      expect(normalizedVolumeFromMediaKit(35), closeTo(0.35, 1e-9));
      expect(normalizedVolumeFromMediaKit(100), 1.0);
    });

    test('aller-retour sans dérive sur toute la plage', () {
      for (int step = 0; step <= 20; step++) {
        final double normalized = step / 20;
        expect(
          normalizedVolumeFromMediaKit(mediaKitVolumeFromNormalized(normalized)),
          closeTo(normalized, 1e-9),
        );
      }
    });
  });

  group('injection du moteur desktop', () {
    test('le registre revient à video_player par défaut', () {
      expect(CinevaVideoControllers.isOverridden, isFalse);
    });

    test('la fabrique desktop remplace la fabrique par défaut', () {
      CinevaVideoControllers.install(desktopVideoControllerFactory);

      expect(CinevaVideoControllers.isOverridden, isTrue);
      expect(CinevaVideoControllers.factory, desktopVideoControllerFactory);

      CinevaVideoControllers.reset();
      expect(CinevaVideoControllers.isOverridden, isFalse);
    });

    test('open() route vers l’adapteur media_kit une fois installé', () {
      CinevaVideoControllers.install(desktopVideoControllerFactory);

      final CinevaVideoController network = CinevaVideoControllers.open(
        url: 'https://cdn.cineva.test/stream.m3u8',
      );
      final CinevaVideoController local = CinevaVideoControllers.open(
        url: 'C:\\Cineva\\downloads\\episode-1.mp4',
        isLocal: true,
      );

      expect(network, isA<MediaKitBackedController>());
      expect(local, isA<MediaKitBackedController>());
      expect(network, isNot(same(local)));
    });
  });

  group('contrôleur media_kit', () {
    test('un contrôleur non initialisé reste inerte', () async {
      // Aucune bibliothèque native n’est chargée avant initialize() : libmpv
      // ne doit jamais être touché en test.
      final CinevaVideoController controller = CinevaVideoControllers.open(
        url: 'https://cdn.cineva.test/stream.m3u8',
      );

      expect(controller.value.isInitialized, isFalse);
      expect(controller.value.isPlaying, isFalse);
      expect(controller.value.hasError, isFalse);
      expect(controller.value.position, Duration.zero);
      expect(controller.value.duration, Duration.zero);
      expect(controller.value.buffered, isEmpty);
      expect(controller.value.aspectRatio, greaterThan(0));

      await controller.dispose();
      expect(controller.value.isInitialized, isFalse);
    });

    test('les écouteurs ne sont plus notifiés après disposal', () async {
      final CinevaVideoController controller = CinevaVideoControllers.open(
        url: 'https://cdn.cineva.test/stream.m3u8',
      );
      int notifications = 0;
      void listener() => notifications++;

      controller.addListener(listener);
      await controller.dispose();
      controller.addListener(listener);

      expect(notifications, 0);
    });

    test('le rapport d’aspect de repli est strictement positif et fini', () {
      expect(kDesktopVideoFallbackAspectRatio, greaterThan(0));
      expect(kDesktopVideoFallbackAspectRatio.isFinite, isTrue);
      expect(CinevaVideoValue.uninitialized.aspectRatio, greaterThan(0));
    });
  });
}
