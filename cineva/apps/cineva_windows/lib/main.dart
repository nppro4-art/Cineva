import 'package:cineva_desktop_video/cineva_desktop_video.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Moteur de lecture : `video_player` n'a aucune implémentation desktop
  // complète, media_kit (libmpv) est donc injecté avant le premier
  // widget. Sans cet appel, l'application Windows démarre mais le
  // lecteur reste sur une surface noire.
  installDesktopVideoPlayback();
  runApp(const CinevaEntry());
}
