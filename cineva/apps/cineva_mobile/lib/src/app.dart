import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_widgets/cineva_widgets.dart';
import 'package:flutter/widgets.dart';

class CinevaMobileEntry extends StatelessWidget {
  const CinevaMobileEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return const CinevaUserApp(target: AppTarget.mobile);
  }
}
