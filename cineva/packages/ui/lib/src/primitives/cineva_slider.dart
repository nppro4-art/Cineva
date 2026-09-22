import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Curseur Cineva : piste fine, remplissage clair/or, pommeau discret qui
/// s'agrandit uniquement pendant le geste. Aucun `Slider` Material (trop
/// marqué visuellement et trop haut).
class CinevaSlider extends StatefulWidget {
  const CinevaSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor = CinevaColors.textHigh,
    this.inactiveColor = const Color(0x29FFFFFF),
    this.trackHeight = 3,
    this.thumbSize = 13,
    this.height = 26,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final Color activeColor;
  final Color inactiveColor;
  final double trackHeight;
  final double thumbSize;

  /// Hauteur de la zone tactile (visible = [trackHeight]).
  final double height;

  @override
  State<CinevaSlider> createState() => _CinevaSliderState();
}

class _CinevaSliderState extends State<CinevaSlider> {
  bool _dragging = false;
  double _dragValue = 0;

  double get _span {
    final double span = widget.max - widget.min;
    return span <= 0 ? 1 : span;
  }

  double get _fraction {
    final double current = _dragging ? _dragValue : widget.value;
    return ((current - widget.min) / _span).clamp(0.0, 1.0).toDouble();
  }

  double _valueAt(double localX, double width) {
    if (width <= 0) return widget.min;
    final double ratio = (localX / width).clamp(0.0, 1.0).toDouble();
    return widget.min + (ratio * _span);
  }

  void _start(DragStartDetails details, double width) {
    setState(() {
      _dragging = true;
      _dragValue = _valueAt(details.localPosition.dx, width);
    });
    widget.onChangeStart?.call(_dragValue);
    widget.onChanged?.call(_dragValue);
  }

  void _update(DragUpdateDetails details, double width) {
    if (!_dragging) return;
    final double next = _valueAt(details.localPosition.dx, width);
    if ((next - _dragValue).abs() < 0.0005) return;
    setState(() => _dragValue = next);
    widget.onChanged?.call(next);
  }

  void _end(DragEndDetails details) {
    if (!_dragging) return;
    final double value = _dragValue;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(value);
  }

  void _tap(TapDownDetails details, double width) {
    final double next = _valueAt(details.localPosition.dx, width);
    widget.onChanged?.call(next);
    widget.onChangeEnd?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onChanged != null;
    final double fraction = _fraction;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double thumb = _dragging ? widget.thumbSize * 1.35 : widget.thumbSize;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: enabled ? (DragStartDetails d) => _start(d, width) : null,
          onHorizontalDragUpdate: enabled ? (DragUpdateDetails d) => _update(d, width) : null,
          onHorizontalDragEnd: enabled ? _end : null,
          onTapDown: enabled ? (TapDownDetails d) => _tap(d, width) : null,
          child: SizedBox(
            height: widget.height,
            width: width,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                Container(
                  height: widget.trackHeight,
                  decoration: BoxDecoration(
                    color: widget.inactiveColor,
                    borderRadius: BorderRadius.circular(CinevaRadii.chip),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: AnimatedContainer(
                    duration: _dragging ? Duration.zero : CinevaMotion.fast,
                    curve: CinevaCurve.out,
                    height: widget.trackHeight,
                    decoration: BoxDecoration(
                      color: enabled ? widget.activeColor : CinevaColors.textFaint,
                      borderRadius: BorderRadius.circular(CinevaRadii.chip),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(fraction * 2 - 1, 0),
                  child: AnimatedContainer(
                    duration: CinevaMotion.fast,
                    curve: CinevaCurve.release,
                    width: thumb,
                    height: thumb,
                    decoration: BoxDecoration(
                      color: enabled ? widget.activeColor : CinevaColors.textFaint,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withOpacity(_dragging ? 0.55 : 0.35),
                          blurRadius: _dragging ? 8 : 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ligne de réglage avec curseur : icône, libellé, valeur et [CinevaSlider].
class CinevaSliderTile extends StatelessWidget {
  const CinevaSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.min = 0,
    this.max = 100,
    this.suffix = '%',
    this.enabled = true,
    this.valueLabel,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final IconData? icon;
  final double min;
  final double max;
  final String suffix;
  final bool enabled;

  /// Affichage précis de la valeur (« +3,0 dB ») — sinon valeur arrondie +
  /// [suffix].
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CinevaSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 17, color: CinevaColors.textFaint),
                const SizedBox(width: CinevaSpacing.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  style: CinevaTypography.cardTitle.copyWith(
                    fontSize: 13.5,
                    color: enabled ? CinevaColors.textHigh : CinevaColors.textFaint,
                  ),
                ),
              ),
              Text(
                valueLabel ?? '${value.round()}$suffix',
                style: CinevaTypography.numeric.copyWith(
                  color: enabled ? CinevaColors.gold : CinevaColors.textFaint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: CinevaSpacing.xs),
          CinevaSlider(
            value: value,
            min: min,
            max: max,
            activeColor: CinevaColors.gold,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
