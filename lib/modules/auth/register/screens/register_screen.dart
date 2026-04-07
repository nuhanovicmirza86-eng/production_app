import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../shared/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  final fullNameCtrl = TextEditingController();
  final displayNameCtrl = TextEditingController();
  final workEmailCtrl = TextEditingController();
  final companyCodeCtrl = TextEditingController();

  final _authService = AuthService();

  bool loading = false;
  bool _obscure = true;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    fullNameCtrl.dispose();
    displayNameCtrl.dispose();
    workEmailCtrl.dispose();
    companyCodeCtrl.dispose();
    super.dispose();
  }

  String _t(String v) => v.replaceAll(RegExp(r'\s+'), ' ').trim();
  String _normCode(String v) => v.trim().toUpperCase();

  bool _looksLikeEmail(String v) {
    final x = v.trim();
    if (x.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(x);
  }

  Future<void> register() async {
    final email = _t(emailCtrl.text);
    final pass = passCtrl.text;

    final fullName = _t(fullNameCtrl.text);
    final displayName = _t(displayNameCtrl.text);
    final workEmail = _t(workEmailCtrl.text);
    final companyCode = _normCode(companyCodeCtrl.text);

    if (email.isEmpty || !_looksLikeEmail(email)) {
      setState(() => error = 'Unesi ispravan email.');
      return;
    }

    if (pass.isEmpty || pass.length < 6) {
      setState(() => error = 'Lozinka mora imati najmanje 6 znakova.');
      return;
    }

    if (workEmail.isNotEmpty && !_looksLikeEmail(workEmail)) {
      setState(() => error = 'Poslovni email nije ispravan.');
      return;
    }

    if (companyCode.isEmpty) {
      setState(() => error = 'Unesi šifru firme.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final user = await _authService.registerUser(
        email: email,
        password: pass,
        role: 'operator',
        fullName: fullName.isEmpty ? null : fullName,
        displayName: displayName.isEmpty ? null : displayName,
        workEmail: workEmail.isEmpty ? null : workEmail,
        companyCode: companyCode,
      );

      if (user == null) {
        if (mounted) {
          setState(() => error = 'Registracija nije uspjela.');
        }
        return;
      }

      // 🔴 KLJUČNA DODANA LOGIKA
      await FirebaseFirestore.instance.collection('registration_requests').add({
        'email': email,
        'companyCode': companyCode,
        'companyId': null, // popuni admin kasnije ili backend
        'plantKey': null,
        'requestedApp': 'production',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Zahtjev uspješno poslan'),
          content: const Text(
            'Vaš zahtjev za pristup sistemu je uspješno kreiran.\n\n'
            'Administrator vaše firme treba da ga odobri prije nego što možete koristiti aplikaciju.\n\n'
            'Bićete obaviješteni nakon odobrenja.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('U redu'),
            ),
          ],
        ),
      );

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registracija')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (prijava)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Lozinka',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscure = !_obscure;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyCodeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Šifra firme / Company Code',
                  helperText:
                      'Unesi šifru firme koju si dobio od administratora.',
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              TextField(
                controller: fullNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ime/Name (opciono)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nadimak/Nickname (opciono)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: workEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Poslovni email (opciono)',
                ),
              ),
              const SizedBox(height: 16),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : register,
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registruj se'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
