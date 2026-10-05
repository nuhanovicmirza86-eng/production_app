import 'package:flutter/material.dart';

/// Neutral plate so a tenant logo stays readable on Premium Midnight.
///
/// The raster is not tinted, cropped, or recolored. Maintenance uses the same
/// plate color, padding, radius, and border.
class PremiumCompanyLogoPlate extends StatelessWidget {
  static const Key plateKey = Key('premium-company-logo-plate');

  /// Light neutral brand-safe surface. Identical in Production and Maintenance.
  static const Color plateColor = Color(0xFFF7F8FA);
  static const Color borderColor = Color(0xFFD8DEE6);
  static const double radius = 12;

  final double size;
  final Widget child;

  const PremiumCompanyLogoPlate({
    super.key,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: plateKey,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: plateColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
        ),
      ),
    );
  }
}
