import 'package:flutter/material.dart';

/// Svjetlija zelena za obrube kartica i polja (usklađeno s Početnom / „O aplikaciji“).
const Color kOperonixProductionBrandGreen = Color(0xFF3DCF8C);

/// Obrub kartica — `RoundedRectangleBorder` + `side` 1.5 (isti obrazac kao maintenance narandžasta).
const ShapeBorder kOperonixProductionCardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  side: BorderSide(color: kOperonixProductionBrandGreen, width: 1.5),
);

ShapeBorder operonixProductionCardShape() => kOperonixProductionCardShape;
