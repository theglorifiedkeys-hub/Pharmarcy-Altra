import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvasBase = Color(0xfff2f7f2);
  static const auraMintLight = Color(0xffcdeed9);
  static const auraMintWarm = Color(0xff87c7ab);
  static const auraMintDeep = Color(0xff176047);
  static const inkPrimary = Color(0xff17362b);
  static const inkSecondary = Color(0xff4d695d);
  static const inkMuted = Color(0xff657f74);
  static const badgeMintBg = Color(0xffdaf2e1);
  static const starGold = Color(0xfff5a623);
}

abstract final class AppTypography {
  static const numberFeatures = [FontFeature.tabularFigures()];
  static const number = TextStyle(fontFeatures: numberFeatures);
  static const caption = TextStyle(fontSize: 12, color: AppColors.inkSecondary);
  static const title = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -.5,
  );
  static const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
}

final appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.auraMintDeep,
    surface: AppColors.canvasBase,
    onSurface: AppColors.inkPrimary,
  ),
  scaffoldBackgroundColor: AppColors.canvasBase,
  inputDecorationTheme: const InputDecorationTheme(
    border: InputBorder.none,
    isDense: true,
    hintStyle: TextStyle(color: AppColors.inkSecondary, fontSize: 13),
  ),
);
