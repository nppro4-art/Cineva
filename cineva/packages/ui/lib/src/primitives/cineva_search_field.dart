import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import 'cineva_pressable.dart';

/// Champ de recherche Cineva.
///
/// Au repos : surface sombre légèrement élevée, aucun liseré visible.
/// Au focus : liseré doré très discret + halo, transition en
/// [CinevaMotion.fast]. Le bouton d'effacement n'apparaît que s'il y a du
/// texte, avec un fondu.
class CinevaSearchField extends StatefulWidget {
  const CinevaSearchField({
    super.key,
    required this.controller,
    this.hint = 'Rechercher un film, une série…',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
    this.onTapOutside,
    this.textInputAction = TextInputAction.search,
    this.enabled = true,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;
  final PointerDownEventListener? onTapOutside;
  final TextInputAction textInputAction;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<CinevaSearchField> createState() => _CinevaSearchFieldState();
}

class _CinevaSearchFieldState extends State<CinevaSearchField> {
  late final FocusNode _internalNode = FocusNode(debugLabel: 'CinevaSearchField');
  FocusNode? _attachedNode;
  bool _focused = false;
  bool _hasText = false;

  FocusNode get _node => widget.focusNode ?? _internalNode;

  @override
  void initState() {
    super.initState();
    _attachedNode = _node;
    _attachedNode!.addListener(_handleFocus);
    widget.controller.addListener(_handleTextChanged);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void didUpdateWidget(CinevaSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
      _handleTextChanged();
    }
    final FocusNode next = _node;
    if (!identical(next, _attachedNode)) {
      _attachedNode?.removeListener(_handleFocus);
      _attachedNode = next;
      next.addListener(_handleFocus);
    }
  }

  @override
  void dispose() {
    _attachedNode?.removeListener(_handleFocus);
    widget.controller.removeListener(_handleTextChanged);
    _internalNode.dispose();
    super.dispose();
  }

  void _handleFocus() {
    final bool focused = _attachedNode?.hasFocus ?? false;
    if (focused == _focused) return;
    setState(() => _focused = focused);
  }

  void _handleTextChanged() {
    final bool hasText = widget.controller.text.isNotEmpty;
    if (hasText == _hasText) return;
    setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: widget.semanticLabel ?? widget.hint,
      child: AnimatedContainer(
        duration: CinevaMotion.fast,
        curve: CinevaCurve.out,
        height: 50,
        padding: const EdgeInsets.only(left: 14, right: 6),
        decoration: BoxDecoration(
          color: _focused ? CinevaColors.raised : CinevaColors.card,
          borderRadius: BorderRadius.circular(CinevaRadii.medium),
          border: Border.all(
            color: _focused ? CinevaColors.gold.withOpacity(0.45) : CinevaColors.hairline,
          ),
          boxShadow: _focused
              ? <BoxShadow>[
                  BoxShadow(
                    color: CinevaColors.gold.withOpacity(0.07),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              size: 20,
              color: _focused ? CinevaColors.gold : CinevaColors.textFaint,
            ),
            const SizedBox(width: CinevaSpacing.sm),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _node,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                textInputAction: widget.textInputAction,
                cursorColor: CinevaColors.gold,
                cursorWidth: 1.6,
                style: CinevaTypography.body.copyWith(
                  color: CinevaColors.textHigh,
                  fontSize: 15,
                  height: 1.2,
                ),
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                onTapOutside: widget.onTapOutside,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: CinevaTypography.body.copyWith(
                    color: CinevaColors.textFaint,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              duration: CinevaMotion.fast,
              opacity: _hasText ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_hasText,
                child: CinevaIconButton(
                  icon: Icons.close_rounded,
                  size: 34,
                  filled: false,
                  tooltip: 'Effacer',
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                    _node.requestFocus();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
