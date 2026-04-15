import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _loading = true;
  String _appName = 'Operonix Production';
  String _packageName = '';
  String _version = '';
  String _buildNumber = '';

  static const String _authorName = 'Mirza Nuhanović';
  static const String _contactEmail = 'info@operonixindustrial.com';
  static const String _companyName = 'Operonix Industrial';
  static const String _companyWeb = 'www.operonixindustrial.com';
  static const String _privacyPolicyUrl =
      'https://www.operonixindustrial.com/privacy-policy?lang=bs';

  static const String _appDescriptionFull =
      'Operonix Production digitalno spaja prodaju, nabavu i proizvodnu liniju u '
      'jedan brz i fleksibilan tok, prilagođen stvarnim industrijskim uslovima. '
      'Osnovni cilj je da informacija i odgovornost stignu do ljudi na liniji '
      'bez čekanja, uz jasnu kontrolu kvaliteta i rokova — prednost u odnosu na '
      'spore ERP petlje ili papirne evidencije.'
      '\n\n'
      'Sljedivost od sirovine i ulazne robe do gotovog proizvoda i otpreme: '
      'jedinstven trag podataka koji olakšava audit, reklamacije i interne '
      'kontrole.'
      '\n\n'
      'Izvještaji i pregledi (otpad, dnevna proizvodnja, IATF / CAPA, KPI) te '
      'akcioni planovi za sve neusklađenosti; uz to live praćenje proizvodnog '
      'toka radi brzog odgovora na odstupanja i zastoje.'
      '\n\n'
      'Rješenje je građeno IATF 16949–friendly logikom: strukturirani rizici '
      '(uklj. PFMEA), jasne uloge i mjerljivi KPI, kako bi kvalitet i proizvodnja '
      'dijelili istu sliku stanja. Moduli se kombinuju prema potrebama; dostupno '
      'je za Android, iOS i Web — za timove u pogonu i u uredu.';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appName = info.appName;
        _packageName = info.packageName;
        _version = info.version;
        _buildNumber = info.buildNumber;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openMail(String email, {String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: subject == null || subject.isEmpty
          ? null
          : <String, String>{'subject': subject},
    );

    if (await launchUrl(uri)) {
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ne mogu otvoriti email klijent.')),
    );
  }

  Future<void> _openWeb(String web) async {
    final url = web.startsWith('http') ? web : 'https://$web';
    final uri = Uri.parse(url);

    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ne mogu otvoriti web stranicu.')),
    );
  }

  Widget _brandCard({required Widget child}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: kOperonixProductionBrandGreen,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('O aplikaciji')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _brandCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.factory_outlined,
                          size: 44,
                          color: kOperonixProductionBrandGreen,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _appName.isEmpty
                                    ? 'Operonix Production'
                                    : _appName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _appDescriptionFull,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _brandCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.verified),
                        title: const Text('Verzija'),
                        subtitle: Text(
                          _version.isEmpty
                              ? '-'
                              : 'v$_version (build $_buildNumber)',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.apps),
                        title: const Text('Package'),
                        subtitle: SelectableText(
                          _packageName.isEmpty ? '-' : _packageName,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _brandCard(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.person),
                        title: Text('Autor'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Ime i prezime'),
                        subtitle: SelectableText(_authorName),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Kontakt email'),
                        subtitle: const SelectableText(_contactEmail),
                        trailing: IconButton(
                          tooltip: 'Pošalji email',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => _openMail(_contactEmail),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.business_outlined),
                        title: const Text('Firma'),
                        subtitle: SelectableText(_companyName),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.public),
                        title: const Text('Web'),
                        subtitle: SelectableText(_companyWeb),
                        trailing: IconButton(
                          tooltip: 'Otvori web',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => _openWeb(_companyWeb),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _brandCard(
                  child: ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Politika privatnosti'),
                    subtitle: const Text(
                      'Tekst politike na operonixindustrial.com (Operonix Production).',
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openWeb(_privacyPolicyUrl),
                  ),
                ),
                const SizedBox(height: 12),
                _brandCard(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Brisanje računa'),
                    subtitle: const Text(
                      'Zahtjev za brisanje računa i povezanih podataka šalje se emailom.',
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openMail(
                      _contactEmail,
                      subject: 'Zahtjev za brisanje računa',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _brandCard(
                  child: Column(
                    children: const [
                      ListTile(
                        leading: Icon(Icons.shield_outlined),
                        title: Text('Kontrola i sljedivost'),
                        subtitle: Text(
                          'IATF 16949–friendly: uloge, evidencija promjena, CAPA i '
                          'akcioni planovi za neusklađenosti, KPI i podrška PFMEA '
                          'tokovima — jedna slika za kvalitet i proizvodnju.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
