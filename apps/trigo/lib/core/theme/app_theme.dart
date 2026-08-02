import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: AppColors.brandBlueBase,
        primaryContainer: AppColors.brandBlueLight,
        secondary: AppColors.brandGreenBase,
        secondaryContainer: AppColors.brandGreenLight,
        tertiary: AppColors.driverOrange,
        tertiaryContainer: AppColors.tricycleYellow,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        useMaterial3Typography: true,
        defaultRadius: 16.0,
        elevatedButtonRadius: 999.0,
        cardRadius: 24.0,
        inputDecoratorRadius: 12.0,
        dialogRadius: 24.0,
        bottomSheetRadius: 24.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      scaffoldBackground: AppColors.background,
    ).copyWith(
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
