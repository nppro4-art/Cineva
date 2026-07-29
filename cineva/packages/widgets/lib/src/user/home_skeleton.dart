import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        const CinevaSkeleton(height: 26, width: 190),
        const SizedBox(height: CinevaSpacing.sm),
        const CinevaSkeleton(height: 16, width: 320),
        const SizedBox(height: CinevaSpacing.xl),
        const CinevaSkeleton(height: 380),
        const SizedBox(height: CinevaSpacing.xxl),
        ...List<Widget>.generate(
          5,
          (sectionIndex) => Padding(
            padding: const EdgeInsets.only(bottom: CinevaSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CinevaSkeleton(height: 24, width: 180),
                const SizedBox(height: CinevaSpacing.xs),
                const CinevaSkeleton(height: 14, width: 280),
                const SizedBox(height: CinevaSpacing.md),
                SizedBox(
                  height: sectionIndex == 0 ? 188 : 270,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, __) => CinevaSkeleton(
                      width: sectionIndex == 0 ? 310 : 156,
                      height: sectionIndex == 0 ? 188 : 240,
                      borderRadius: BorderRadius.circular(CinevaRadii.medium),
                    ),
                    separatorBuilder: (_, __) => const SizedBox(width: CinevaSpacing.md),
                    itemCount: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
