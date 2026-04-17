import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:production_app/core/user_display_label.dart';

/// Traka sesije na operativnoj stanici: tko je prijavljen + placeholder za QR prijavu.
///
/// Koristi [FirebaseAuth.authStateChanges] za prikaz; unos u Firestore i dalje
/// slijedi [FirebaseAuth.instance.currentUser] u servisima.
class StationSessionStrip extends StatelessWidget {
  const StationSessionStrip({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snap) {
            final u = snap.data;
            final loggedIn = u != null;
            final name = loggedIn
                ? UserDisplayLabel.fromSessionMap(companyData)
                : null;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  loggedIn ? Icons.person_rounded : Icons.person_off_outlined,
                  size: 28,
                  color: loggedIn ? cs.primary : cs.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loggedIn ? 'Prijavljen' : 'Niste prijavljeni',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loggedIn
                            ? (name ?? '—')
                            : 'Potrebna je prijava za audit unosa.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'QR prijava na stanicu bit će povezana u sljedećoj fazi (bedž + skener).',
                        ),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'U redu',
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  label: const Text('QR prijava'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
