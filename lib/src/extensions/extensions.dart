import 'package:flutter/material.dart';
import 'package:wallet_words/src/constants.dart';

extension TextEditingGetters on TextEditingValue {
  String get normalCharactersText => String.fromCharCodes(
        text.codeUnits.where((ch) => ch != kObjectReplacementChar),
      );

  List<int> get replacementCharacters => text.codeUnits
      .where((ch) => ch == kObjectReplacementChar)
      .toList(growable: false);

  int get replacementCharactersCount => replacementCharacters.length;
}

class TooltipShapeBorder extends ShapeBorder {
  const TooltipShapeBorder({
    this.radius = 16.0,
    this.arrowWidth = 20.0,
    this.arrowHeight = 10.0,
    this.arrowArc = 0.0,
  }) : assert(
          arrowArc <= 1.0 && arrowArc >= 0.0,
          'arrowArc must be between 0.0 and 1.0',
        );
  final double arrowWidth;
  final double arrowHeight;
  final double arrowArc;
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: arrowHeight);

  @override
  ShapeBorder scale(double t) => this;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final workedRect = Rect.fromPoints(
      rect.topLeft,
      rect.bottomRight - Offset(0, arrowHeight),
    );
    final x = arrowWidth;
    final y = arrowHeight;
    final r = 1 - arrowArc;

    return Path()
      ..addRRect(RRect.fromRectAndRadius(workedRect, Radius.circular(radius)))
      ..moveTo(workedRect.bottomCenter.dx + x / 2, workedRect.bottomCenter.dy)
      ..relativeLineTo(-x / 2 * r, y * r)
      ..relativeQuadraticBezierTo(
        -x / 2 * (1 - r),
        y * (1 - r),
        -x * (1 - r),
        0,
      )
      ..relativeLineTo(-x / 2 * r, -y * r);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}
