import 'dart:async';

import 'package:flutter/material.dart';

/// Widget to simulate the text cursor on of a [TextField]
class TextCursor extends StatefulWidget {
  /// Widget to simulate the text cursor on of a [TextField].
  const TextCursor({
    super.key,
    this.duration = const Duration(milliseconds: 500),
    this.resumed = false,
  });

  /// Duration of the cursor animation
  final Duration duration;

  /// Controls if the cursor is visible or not based pm [FocusNode.hasFocus]
  final bool resumed;

  @override
  State<TextCursor> createState() => _TextCursorState();
}

class _TextCursorState extends State<TextCursor>
    with SingleTickerProviderStateMixin {
  bool _displayed = false;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.duration, _onTimer);
  }

  void _onTimer(Timer timer) {
    setState(() => _displayed = !_displayed);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Opacity(
        opacity: _displayed && widget.resumed ? 1.0 : 0.0,
        child: Container(
          width: 2,
          color: theme.textSelectionTheme.cursorColor ??
              theme.textSelectionTheme.selectionColor ??
              theme.primaryColor,
        ),
      ),
    );
  }
}
