import 'package:flutter/material.dart';

class CinevaFadeSlide extends StatelessWidget {
  const CinevaFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 260),
    this.offsetY = 18,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final totalMs = (duration + delay).inMilliseconds;
        final shifted = delay == Duration.zero
            ? value
            : ((value * totalMs - delay.inMilliseconds) / duration.inMilliseconds).clamp(0, 1).toDouble();

        return Opacity(
          opacity: shifted,
          child: Transform.translate(
            offset: Offset(0, (1 - shifted) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
