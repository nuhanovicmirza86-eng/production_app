/// Podaci za zaglavlje PDF narudžbenica i srodnih dokumenata (mapa `documentPdfSettings` na `companies/{id}`).
class DocumentPdfSettings {
  final int version;

  final String companyLegalName;
  final String businessDescription;
  final String addressLine1;
  final String addressLine2;

  final String phone;
  final String fax;
  final String email;
  final String website;

  final String courtRegistration;
  final String idNumber;
  final String vatNumber;

  final String bankName;
  final String bankAccount;
  final String bankIban;

  /// Izravni HTTPS URL slike loga (npr. iz Firebase Storage ili javnog URL-a).
  final String logoUrl;

  /// Podrazumijevani PDV % po stavci ako u `order_items` nije postavljeno.
  final int defaultVatPercent;

  /// Podrazumijevani rabat % po stavci ako nije u bazi.
  final int defaultDiscountPercent;

  const DocumentPdfSettings({
    this.version = 1,
    this.companyLegalName = '',
    this.businessDescription = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phone = '',
    this.fax = '',
    this.email = '',
    this.website = '',
    this.courtRegistration = '',
    this.idNumber = '',
    this.vatNumber = '',
    this.bankName = '',
    this.bankAccount = '',
    this.bankIban = '',
    this.logoUrl = '',
    this.defaultVatPercent = 17,
    this.defaultDiscountPercent = 0,
  });

  factory DocumentPdfSettings.fromMap(Map<String, dynamic> map) {
    int iv(dynamic v, int def) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse((v ?? '').toString()) ?? def;
    }

    return DocumentPdfSettings(
      version: iv(map['version'], 1),
      companyLegalName: _s(map['companyLegalName']),
      businessDescription: _s(map['businessDescription']),
      addressLine1: _s(map['addressLine1']),
      addressLine2: _s(map['addressLine2']),
      phone: _s(map['phone']),
      fax: _s(map['fax']),
      email: _s(map['email']),
      website: _s(map['website']),
      courtRegistration: _s(map['courtRegistration']),
      idNumber: _s(map['idNumber']),
      vatNumber: _s(map['vatNumber']),
      bankName: _s(map['bankName']),
      bankAccount: _s(map['bankAccount']),
      bankIban: _s(map['bankIban']),
      logoUrl: _s(map['logoUrl']),
      defaultVatPercent: iv(map['defaultVatPercent'], 17).clamp(0, 100),
      defaultDiscountPercent: iv(map['defaultDiscountPercent'], 0).clamp(0, 100),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'companyLegalName': companyLegalName,
      'businessDescription': businessDescription,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'phone': phone,
      'fax': fax,
      'email': email,
      'website': website,
      'courtRegistration': courtRegistration,
      'idNumber': idNumber,
      'vatNumber': vatNumber,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'bankIban': bankIban,
      'logoUrl': logoUrl,
      'defaultVatPercent': defaultVatPercent,
      'defaultDiscountPercent': defaultDiscountPercent,
    };
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();
}
