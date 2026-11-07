import 'package:flutter/material.dart';

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get screenPadding => MediaQuery.of(this).padding;

  bool get isTablet => screenWidth >= 600;
  bool get isDesktop => screenWidth >= 1024;

  double get maxAppWidth => isTablet ? 480.0 : double.infinity;
}
