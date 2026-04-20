import 'package:flutter/material.dart';

/// U [LogisticsHubEntryScreen] tabu ne treba drugi AppBar — samo tijelo ekrana.
Widget wmsTabScaffold({
  required bool embedInHubShell,
  required String title,
  required Widget body,
  Widget? floatingActionButton,
}) {
  if (embedInHubShell) {
    return Scaffold(
      primary: false,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: body,
    floatingActionButton: floatingActionButton,
  );
}
