import 'package:cloud_firestore/cloud_firestore.dart';

/// Opcionalno vezivanje Firestore emulatora (isti `maintenance_app/firebase.json`, port 8080).
///
/// `--dart-define=USE_FIRESTORE_EMULATOR=true`
/// Android emulator: `--dart-define=FIRESTORE_EMULATOR_HOST=10.0.2.2`
///
/// Pokreni emulator iz `maintenance_app`: `npm run emulator:firestore`.
void configureFirestoreEmulatorFromEnvironment() {
  const use = bool.fromEnvironment('USE_FIRESTORE_EMULATOR', defaultValue: false);
  if (!use) return;
  const host = String.fromEnvironment('FIRESTORE_EMULATOR_HOST', defaultValue: 'localhost');
  const port = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
  FirebaseFirestore.instance.useFirestoreEmulator(host, port);
}
