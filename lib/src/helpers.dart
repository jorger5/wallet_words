import 'dart:math';

import 'package:flutter/material.dart';

class UIHelpers {
  static double getSuggestedBoxHeight(
    BuildContext context,
    Size size,
    Offset offset,
  ) {
    final mq = MediaQuery.of(context);
    final topAvailableSpace = offset.dy;
    final bottomAvailableSpace =
        mq.size.height - mq.viewInsets.bottom - offset.dy - size.height;

    return max(topAvailableSpace, bottomAvailableSpace);
  }
}
