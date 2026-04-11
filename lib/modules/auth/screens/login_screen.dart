import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _openRegister() async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );

    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vaš zahtjev za registraciju je zaprimljen i čeka odobrenje Administratora.',
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
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordCtrl,
                        enabled: !_loading,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Lozinka',
                          border: const OutlineInputBorder(),
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
}
