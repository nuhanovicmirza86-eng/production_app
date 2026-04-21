import 'package:flutter/material.dart';

/// Prikaz Availability / Performance / Quality (0–1 ili %).
class OoeFactorRow extends StatelessWidget {
  final double availability;
  final double performance;
  final double quality;
  final Widget? headerTrailing;

  const OoeFactorRow({
    super.key,
    required this.availability,
    required this.performance,
    required this.quality,
    this.headerTrailing,
  });

  String _pct(double x) => '${(x * 100).toStringAsFixed(1)} %';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (headerTrailing != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: headerTrailing,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _cell('Availability', _pct(availability), Colors.blue),
                ),
                Expanded(
                  child: _cell('Performance', _pct(performance), Colors.orange),
                ),
                Expanded(
                  child: _cell('Quality', _pct(quality), Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String t, String v, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text(
          v,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
      ],
    );
  }
}
