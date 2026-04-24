import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Faza 3 MES — korisničke preference (tiši sati za S1/S2 push, dnevni digest e-poštom).
/// Polja na [users]: [mesQuietHours], [mesDailyDigestEmail] (vidi Firestore rules).
class MesNotificationPreferencesScreen extends StatefulWidget {
  const MesNotificationPreferencesScreen({super.key});

  @override
  State<MesNotificationPreferencesScreen> createState() =>
      _MesNotificationPreferencesScreenState();
}

class _MesNotificationPreferencesScreenState
    extends State<MesNotificationPreferencesScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _digestEmail = false;
  bool _quietEnabled = false;
  int _quietStart = 22;
  int _quietEnd = 7;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = _user;
    if (u == null) {
      setState(() {
        _loading = false;
        _error = 'Nisi prijavljen.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _db.collection('users').doc(u.uid).get();
      final d = snap.data() ?? {};
      final qh = d['mesQuietHours'];
      if (qh is Map) {
        _quietStart = _hour(qh['startHour'], fallback: 22);
        _quietEnd = _hour(qh['endHour'], fallback: 7);
        _quietEnabled = true;
      } else {
        _quietEnabled = false;
        _quietStart = 22;
        _quietEnd = 7;
      }
      _digestEmail = d['mesDailyDigestEmail'] == true;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int _hour(dynamic v, {required int fallback}) {
    if (v is int) return v.clamp(0, 23);
    if (v is num) return v.toInt().clamp(0, 23);
    return fallback;
  }

  Future<void> _save() async {
    final u = _user;
    if (u == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final patch = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': u.uid,
        'updatedByEmail': u.email ?? '',
        'mesDailyDigestEmail': _digestEmail,
      };

      if (_quietEnabled) {
        patch['mesQuietHours'] = {
          'startHour': _quietStart,
          'endHour': _quietEnd,
          'timeZone': 'Europe/Sarajevo',
        };
      } else {
        patch['mesQuietHours'] = FieldValue.delete();
      }

      await _db.collection('users').doc(u.uid).update(patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Postavke su sačuvane.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MES obavijesti'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                Text(
                  'Push obavijesti niske ozbiljnosti (S1/S2) ne šalju se u zadatom noćnom prozoru. '
                  'Hitne obavijesti (S3/S4) uvijek stižu.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Tiši sati (S1/S2 push)'),
                  subtitle: Text(
                    _quietEnabled
                        ? 'Od $_quietStart:00 do $_quietEnd:00 (Europe/Sarajevo)'
                        : 'Isključeno',
                  ),
                  value: _quietEnabled,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _quietEnabled = v),
                ),
                if (_quietEnabled) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(
                            'mes-quiet-start-$_quietEnabled-$_quietStart',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Početak (sat)',
                          ),
                          initialValue: _quietStart,
                          items: List.generate(
                            24,
                            (i) => DropdownMenuItem(value: i, child: Text('$i:00')),
                          ),
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setState(() => _quietStart = v);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(
                            'mes-quiet-end-$_quietEnabled-$_quietEnd',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Kraj (sat)',
                          ),
                          initialValue: _quietEnd,
                          items: List.generate(
                            24,
                            (i) => DropdownMenuItem(value: i, child: Text('$i:00')),
                          ),
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setState(() => _quietEnd = v);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 32),
                SwitchListTile(
                  title: const Text('Dnevni sažetak e-poštom'),
                  subtitle: const Text(
                    'Jedan e-mail oko 07:15 (Europe/Sarajevo) ako ima nepročitanih MES obavijesti u zadnjih 24 h. '
                    'Potreban je SMTP na projektu.',
                  ),
                  value: _digestEmail,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _digestEmail = v),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Čuvanje…' : 'Sačuvaj'),
                ),
              ],
            ),
    );
  }
}
