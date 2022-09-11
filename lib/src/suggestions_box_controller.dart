import 'package:flutter/material.dart';

class SuggestionsBoxController {
  SuggestionsBoxController(
    this.context,
  );
  final BuildContext context;

  OverlayEntry? overlayEntry;

  bool _isOpened = false;

  bool get isOpened => _isOpened;

  void open() {
    if (_isOpened) return;
    assert(overlayEntry != null, 'Overlay entry must not be null');
    Overlay.of(context)!.insert(overlayEntry!);
    _isOpened = true;
  }

  void close() {
    if (!_isOpened) return;
    assert(overlayEntry != null, 'Overlay entry must not be null');
    overlayEntry!.remove();
    _isOpened = false;
  }

  void toggle() {
    if (_isOpened) {
      close();
    } else {
      open();
    }
  }
}
