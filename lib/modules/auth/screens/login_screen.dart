import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/station_launch_preference.dart';
import '../register/screens/register_screen.dart';
import '../shared/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function()? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _kRememberEmail = 'remember_email';
  static const _kSavedEmail = 'saved_email';
  static const _privacyPolicyUrl =
      'https://operonixindustrial.com/privacy-policy';

  final _authService = AuthService();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _rememberEmail = true;
  bool _prefsLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberEmail) ?? true;
      final saved = prefs.getString(_kSavedEmail) ?? '';

      if (!mounted) return;

      setState(() {
        _rememberEmail = remember;
        _prefsLoaded = true;

        if (remember && saved.trim().isNotEmpty) {
          _emailCtrl.text = saved.trim();
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _rememberEmail = true;
        _prefsLoaded = true;
      });
    }
  }

  Future<void> _persistRememberState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_kRememberEmail, _rememberEmail);

      if (_rememberEmail) {
        await prefs.setString(_kSavedEmail, _emailCtrl.text.trim());
      } else {
        await prefs.remove(_kSavedEmail);
      }
    } catch (_) {}
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Unesi email i lozinku.';
      });
      return;
    }

    try {
      await _authService.signIn(email, password);
      await _persistRememberState();

      if (!mounted) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (!mounted) return;
          final role = snap.data()?['role'];
          if (ProductionAccessHelper.isAdminRole(
            ProductionAccessHelper.normalizeRole(role),
          )) {
            await _promptAdminStationMode(context);
          }
        } catch (_) {
          // Ako profil ne može pročitati, nastavi bez postavke uređaja.
        }
      }

      if (!mounted) return;

      if (widget.onLoginSuccess != null) {
        await widget.onLoginSuccess!();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message?.trim().isNotEmpty == true
            ? e.message
            : 'Greška prijave: ${e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ne mogu otvoriti stranicu politike.')),
      );
    }
  }

  Future<void> _openRegister() async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );

    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vaš zahtjev za registraciju je zaprimljen i čeka odobrenje Admina.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsWeb ? null : AppBar(title: const Text('Prijava')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'branding/operonix_production_icon.PNG',
                        height: kIsWeb ? 72 : 64,
                        semanticLabel: 'Operonix Production',
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Branding asset failed: $error');
                          return Icon(
                            Icons.precision_manufacturing_outlined,
                            size: kIsWeb ? 56 : 56,
                            color: Theme.of(context).colorScheme.primary,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Operonix Production',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailCtrl,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordCtrl,
                        enabled: !_loading,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Lozinka',
                          suffixIcon: IconButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _obscure = !_obscure;
                                    });
                                  },
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: _rememberEmail,
                        onChanged: (_loading || !_prefsLoaded)
                            ? null
                            : (value) async {
                                setState(() {
                                  _rememberEmail = value == true;
                                });
                                await _persistRememberState();
                              },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Zapamti email',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('Lozinka se nikad ne sprema.'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: Text(_loading ? 'Prijava...' : 'Prijavi se'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _loading ? null : _openRegister,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Nemaš račun? Registruj se'),
                      ),
                      TextButton(
                        onPressed: _loading ? null : _openPrivacyPolicy,
                        child: const Text('Politika privatnosti'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Samo uloga Admin — pitanje na samom ekranu prijave prije ulaska u aplikaciju.
  Future<void> _promptAdminStationMode(BuildContext context) async {
    final first = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ovaj uređaj'),
        content: const Text(
          'Želite li postaviti ovaj računar tako da se nakon svake prijave otvara '
          'stanica (pripremna, prva ili završna kontrola) umjesto cijelog izbornika?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne, cijela aplikacija'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da, kao stanicu'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (first != true) {
      await StationLaunchPreference.setMode(StationLaunchPreference.modeFull);
      return;
    }

    final initial = await _defaultStationPickerValue();
    if (!mounted) return;
    if (!context.mounted) return;

    final picked = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StationPickDialog(initialMode: initial),
    );
    if (!mounted) return;
    if (picked == null || picked.isEmpty) {
      await StationLaunchPreference.setMode(StationLaunchPreference.modeFull);
      return;
    }
    await StationLaunchPreference.setMode(picked);
  }

  Future<String> _defaultStationPickerValue() async {
    final r = await StationLaunchPreference.getModeRaw();
    switch (r) {
      case StationLaunchPreference.modePreparation:
      case StationLaunchPreference.modeFirstControl:
      case StationLaunchPreference.modeFinalControl:
        return r;
      default:
        return StationLaunchPreference.modePreparation;
    }
  }
}

class _StationPickDialog extends StatefulWidget {
  final String initialMode;

  const _StationPickDialog({required this.initialMode});

  @override
  State<_StationPickDialog> createState() => _StationPickDialogState();
}

class _StationPickDialogState extends State<_StationPickDialog> {
  late String _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Koja stanica?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Koju stanicu ovaj računar otvara nakon prijave?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Stanicu',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _mode,
                items: const [
                  DropdownMenuItem(
                    value: StationLaunchPreference.modePreparation,
                    child: Text('Stanica 1 — pripremna'),
                  ),
                  DropdownMenuItem(
                    value: StationLaunchPreference.modeFirstControl,
                    child: Text('Stanica 2 — prva kontrola'),
                  ),
                  DropdownMenuItem(
                    value: StationLaunchPreference.modeFinalControl,
                    child: Text('Stanica 3 — završna kontrola'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _mode = v);
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _mode),
          child: const Text('Potvrdi'),
        ),
      ],
    );
  }
}
