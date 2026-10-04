import 'package:flutter/material.dart';

import '../operonix_visual_tokens.dart';

/// Tipografska hijerarhija Premium Midnighta.
class PremiumType {
  const PremiumType._();

  static TextStyle pageTitle(OperonixVisualTokens tokens) {
    return TextStyle(
      fontSize: 22,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: tokens.primaryText,
    );
  }

  static TextStyle sectionTitle(OperonixVisualTokens tokens) {
    return TextStyle(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: tokens.secondaryText,
    );
  }

  static TextStyle cardTitle(OperonixVisualTokens tokens) {
    return TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: tokens.primaryText,
    );
  }

  static TextStyle value(OperonixVisualTokens tokens, {Color? color}) {
    return TextStyle(
      fontSize: 22,
      height: 1,
      fontWeight: FontWeight.w800,
      color: color ?? tokens.primaryText,
    );
  }

  static TextStyle meta(OperonixVisualTokens tokens) {
    return TextStyle(
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w500,
      color: tokens.secondaryText,
    );
  }

  static TextStyle support(OperonixVisualTokens tokens) {
    return TextStyle(
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: tokens.secondaryText,
    );
  }
}
