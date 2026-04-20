import 'package:flutter/material.dart';

/// Master data kontrolnog plana — CRUD kroz Callable u sljedećoj fazi.
class ControlPlansListScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const ControlPlansListScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontrolni planovi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Lista i uređivanje kontrolnih planova (proizvod, operacije, karakteristike, tolerancije, frekvencija, reakcioni plan). '
            'Podaci: kolekcija control_plans — upis admin/engineering tokom implementacije Callable.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
