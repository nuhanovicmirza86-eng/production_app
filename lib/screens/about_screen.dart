import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  /// Zeleni brend obrub (usklađeno s `ColorScheme` seed u aplikaciji).
  static const Color _brandOutline = Color(0xFF164344);

  static const String _authorName = 'Mirza Nuhanović';
  static const String _contactEmail = 'info@operonix.com';
  static const String _companyName = 'Operonix Industrial';
  static const String _companyWeb = 'www.operonixindustrial.com';

  /// Detaljan opis isključivo za Production app (bez CMMS / održavanja).
  static const String _appDescriptionFull =
      'Operonix Production je operativni sloj za proizvodnju i komerciju u '
      'industrijskom okruženju: povezuje proizvodne naloge, master podatke o '
      'proizvodima, komercijalne narudžbe i partnere, te digitalne tokove na '
      'podu (QR, operaterske stanice, logističke prijeme). Aplikacija radi u '
      'kontekstu kompanije i pogona (company / plant), uz prijavu korisnika i '
      'ovlaštenja po ulozi. '
      '\n\n'
      'Koje funkcije aplikacija podržava u praksi:\n'
      '• Proizvodni nalozi — pregled liste, detalji naloga, statusi i radni '
      'tok oko izvršavanja (ovisno o konfiguraciji i pravima).\n'
      '• Proizvodi — evidencija proizvoda, strukture / BOM gdje su definisane, '
      'te povezani tehnički i komercijalni podaci za rad u proizvodnji.\n'
      '• QR skeniranje — brzo otvaranje naloga ili rukovanje naljepnicama s '
      'proizvodnog poda preko kamere (gdje je uređaj podržan), uz jasno '
      'raspoznavanje tipa QR koda.\n'
      '• Operativno praćenje proizvodnje — tabbed pregled faza i posebni '
      'punozaslonski režimi stanica (npr. priprema, kontrolne faze) namijenjeni '
      'monitorima na liniji; dio ekrana je u proširenju prema punom unosu, ali '
      'arhitektura već podržava odvojene operaterske tokove.\n'
      '• Komercija — narudžbe (pregled i rad s narudžbama) te partneri '
      '(kupci / dobavljači) kao podrška prodajno-nabavnom krugu uz proizvodnju.\n'
      '• Logistika — prijem štampanih klasifikacijskih naljepnica / isprava '
      'kroz namjenski tok vezan za QR.\n'
      '• Izvještaji — hub profesionalnih izvještaja (npr. otpad, dnevna '
      'proizvodnja, IATF / CAPA) za uloge kojima je pristup dodijeljen.\n'
      '• Održivost — modul karbonskog otiska (postavke, aktivnosti, faktori, '
      'pregled i izvoz) kada je omogućen za kompaniju.\n'
      '• Administracija — odobravanje novih korisnika (pending registracije) '
      'za administratore.\n'
      '\n'
      'Prikaz modula i kartica na početnom ekranu ovisi o listi omogućenih '
      'modula i pravima pristupa (uloga). Neki moduli u razvoju (npr. radni '
      'centri, smjene, zastoji) mogu biti vidljivi kao „uskoro” ovisno o '
      'konfiguraciji. '
      '\n\n'
      'Platforme: web, mobilni uređaji i desktop (Windows), uz prilagođen '
      'izgled za širinu web sučelja. Aplikacija nije CMMS: ne obavlja '
      'evidenciju održavanja, mjerača ni servisnih radnih naloga u smislu '
      'Operonix Maintenance modula — fokus je na proizvodnji, komerciji i '
      'povezanim operativnim i izvještajnim tokovima.';

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

  Future<void> _openMail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ne mogu otvoriti email klijent.')),
      );
    }
  }

  Future<void> _openWeb(String web) async {
    final url = web.startsWith('http') ? web : 'https://$web';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ne mogu otvoriti web stranicu.')),
      );
    }
  }

  Widget _brandCard({required Widget child}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _brandOutline, width: 2),
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
                          color: _brandOutline,
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
                  child: Column(
                    children: const [
                      ListTile(
                        leading: Icon(Icons.shield_outlined),
                        title: Text('Kontrola i sljedivost'),
                        subtitle: Text(
                          'U proizvodnji i komerciji naglasak je na jasnim ulogama, '
                          'dozvoljenim akcijama i sljedivosti podataka i promjena '
                          '(IATF 16949–friendly pristup u izvještajima i procesima '
                          'gdje su ti moduli uključeni).',
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
