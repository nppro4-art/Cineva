import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

class CinevaSkeleton extends StatefulWidget {
  const CinevaSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(CinevaRadii.medium)),
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  State<CinevaSkeleton> createState() => _CinevaSkeletonState();
}

class _CinevaSkeletonState extends State<CinevaSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.2 + (progress * 2.4), -0.25),
              end: Alignment(1.2 + (progress * 2.4), 0.25),
              colors: <Color>[
                CinevaColors.surfaceRaised,
                Colors.white.withOpacity(0.08),
                CinevaColors.surfaceRaised,
              ],
              stops: const <double>[0.1, 0.35, 0.6],
            ),
          ),
        );
      },
    );
  }
}
