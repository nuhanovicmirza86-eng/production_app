import 'package:flutter/material.dart';

/// NCR lista — detalji i workflow nakon povezivanja s non_conformances.
class NcrListScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const NcrListScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NCR — neskladi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Lista zapisa iz kolekcije non_conformances (izvor, ozbiljnost, containment, veza na lot/nalog/inspekciju).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
