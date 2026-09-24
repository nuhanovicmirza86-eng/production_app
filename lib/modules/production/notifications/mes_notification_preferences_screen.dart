import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'mes_notification_prefs.dart';

/// NOTIF-M1-D1 — Postavke → Obavijesti.
class MesNotificationPreferencesScreen extends StatefulWidget {
  const MesNotificationPreferencesScreen({super.key});

  @override
  State<MesNotificationPreferencesScreen> createState() =>
      _MesNotificationPreferencesScreenState();
}

class _MesNotificationPreferencesScreenState
    extends State<MesNotificationPreferencesScreen> {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  MesNotificationPrefs _prefs = MesNotificationPrefs.allEnabled();
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
      _prefs = MesNotificationPrefs.fromUser(d);
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
      _error = 'Postavke se nisu mogle učitati.';
    } finally {
      if (mounted) setState(() => _loading = false);
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
      await _functions.httpsCallable('updateMesNotificationPreferences').call({
        'prefs': _prefs.toPayload(),
      });
      final patch = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
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
        setState(() => _error = 'Postavke nisu sačuvane.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Obavijesti')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Odaberite koje informativne i upozoravajuće obavijesti želite primati. '
                  'Obavezne akcije, sigurnost, HOLD, NCR / CAPA i verifikacije se ne mogu isključiti.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                for (final cat in MesNotificationPrefs.categories) ...[
                  _CategoryCard(
                    category: cat,
                    enabled: _prefs.isEnabled(cat.id),
                    saving: _saving,
                    onChanged: cat.canDisable
                        ? (v) => setState(
                              () => _prefs = _prefs.copyWithId(cat.id, v),
                            )
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                Text('Dodatno', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Tiši sati'),
                        subtitle: Text(
                          _quietEnabled
                              ? 'Push niže hitnosti od $_quietStart:00 do $_quietEnd:00. Kritične obavijesti i dalje stižu.'
                              : 'Isključeno. Kritične obavijesti uvijek stižu.',
                        ),
                        value: _quietEnabled,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _quietEnabled = v),
                      ),
                      if (_quietEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  key: ValueKey('quiet-start-$_quietStart'),
                                  decoration: const InputDecoration(
                                    labelText: 'Početak',
                                  ),
                                  initialValue: _quietStart,
                                  items: List.generate(
                                    24,
                                    (i) => DropdownMenuItem(
                                      value: i,
                                      child: Text('$i:00'),
                                    ),
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
                                  key: ValueKey('quiet-end-$_quietEnd'),
                                  decoration: const InputDecoration(
                                    labelText: 'Kraj',
                                  ),
                                  initialValue: _quietEnd,
                                  items: List.generate(
                                    24,
                                    (i) => DropdownMenuItem(
                                      value: i,
                                      child: Text('$i:00'),
                                    ),
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
                        ),
                      SwitchListTile(
                        title: const Text('Dnevni sažetak e-poštom'),
                        subtitle: const Text(
                          'Jedan dnevni sažetak nepročitanih obavijesti.',
                        ),
                        value: _digestEmail,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _digestEmail = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Čuvanje…' : 'Sačuvaj'),
                ),
              ],
            ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.enabled,
    required this.saving,
    required this.onChanged,
  });

  final MesNotificationCategory category;
  final bool enabled;
  final bool saving;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = onChanged == null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(category.title),
              subtitle: Text(category.subtitle),
              value: locked ? true : enabled,
              onChanged: saving || locked ? null : onChanged,
            ),
            if (category.lockReason != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.lockReason!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
