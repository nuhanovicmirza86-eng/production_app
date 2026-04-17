import 'dart:typed_data';



import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;



import '../services/company_print_identity_service.dart';



/// Podaci za profesionalno zaglavlje (letterhead) na PDF-ovima.

class PdfCompanyLetterheadData {

  const PdfCompanyLetterheadData({

    required this.companyName,

    required this.tagline,

    required this.addressLines,

    required this.contactLines,

    required this.footerLines,

  });



  final String companyName;

  final String tagline;

  final List<String> addressLines;

  final List<String> contactLines;

  final List<String> footerLines;



  /// Narudžbenica i sl.: jedna lista redova kao ranije.

  factory PdfCompanyLetterheadData.fromLegacyLines({

    required String companyName,

    required List<String> detailLines,

  }) {

    return PdfCompanyLetterheadData(

      companyName: companyName,

      tagline: '',

      addressLines: const [],

      contactLines: List<String>.from(detailLines),

      footerLines: const [],

    );

  }

}



extension CompanyPrintIdentityLetterhead on CompanyPrintIdentity {

  PdfCompanyLetterheadData toLetterheadData(Map<String, dynamic> companyData) {

    final s = settings;

    final name = primaryName(companyData);

    final tag = s.businessDescription.trim();

    final address = <String>[

      if (s.addressLine1.trim().isNotEmpty) s.addressLine1.trim(),

      if (s.addressLine2.trim().isNotEmpty) s.addressLine2.trim(),

    ];

    final contact = <String>[

      if (s.phone.trim().isNotEmpty) 'Tel: ${s.phone.trim()}',

      if (s.fax.trim().isNotEmpty) 'Fax: ${s.fax.trim()}',

      if (s.email.trim().isNotEmpty) s.email.trim(),

      if (s.website.trim().isNotEmpty) s.website.trim(),

    ];

    final footer = <String>[];

    if (s.courtRegistration.trim().isNotEmpty) {

      footer.add('Sud: ${s.courtRegistration.trim()}');

    }

    if (s.idNumber.trim().isNotEmpty) footer.add('ID: ${s.idNumber.trim()}');

    if (s.vatNumber.trim().isNotEmpty) footer.add('PDV: ${s.vatNumber.trim()}');

    if (s.bankName.trim().isNotEmpty ||

        s.bankAccount.trim().isNotEmpty ||

        s.bankIban.trim().isNotEmpty) {

      if (s.bankName.trim().isNotEmpty) footer.add(s.bankName.trim());

      final acc = [s.bankAccount, s.bankIban]

          .map((e) => e.trim())

          .where((e) => e.isNotEmpty)

          .join(' · ');

      if (acc.isNotEmpty) footer.add(acc);

    }

    return PdfCompanyLetterheadData(

      companyName: name,

      tagline: tag,

      addressLines: address,

      contactLines: contact,

      footerLines: footer,

    );

  }

}



/// Profesionalno zaglavlje (letterhead) na PDF izvozima — kao u narudžbenicama / ponudama.

class PdfCompanyHeader {

  PdfCompanyHeader._();



  /// Tamnoplava akcent linija (Operonix navy / poslovni dokumenti).

  static final PdfColor _accent = PdfColor.fromInt(0xFF0B1F3A);

  static final PdfColor _muted = PdfColors.grey700;

  static final PdfColor _line = PdfColors.grey300;



  static pw.Widget _textLine(

    pw.Font fontR,

    String text, {

    double fontSize = 8,

    PdfColor? color,

  }) {

    return pw.Padding(

      padding: const pw.EdgeInsets.only(bottom: 3),

      child: pw.Text(

        text,

        style: pw.TextStyle(

          font: fontR,

          fontSize: fontSize,

          color: color ?? PdfColors.black,

          height: 1.25,

        ),

      ),

    );

  }



  static pw.Widget _columnBlock(

    pw.Font fontR,

    List<String> lines, {

    PdfColor? color,

  }) {

    return pw.Column(

      crossAxisAlignment: pw.CrossAxisAlignment.start,

      children: [

        for (final line in lines)

          if (line.trim().isNotEmpty)

            _textLine(fontR, line.trim(), color: color),

      ],

    );

  }



  /// Novi izgled: logo, naziv, dvije kolone (adresa | kontakt), zatim pravne/bankovne podatke.

  static pw.Widget buildLetterhead({

    required pw.Font fontR,

    required pw.Font fontB,

    required PdfCompanyLetterheadData data,

    Uint8List? logoBytes,

    double maxLogoHeight = 52,

  }) {

    final name = data.companyName.trim();

    final tag = data.tagline.trim();

    final useTwoColumns =
        data.addressLines.isNotEmpty && data.contactLines.isNotEmpty;

    pw.Widget? logo;

    if (logoBytes != null && logoBytes.isNotEmpty) {

      logo = pw.Image(

        pw.MemoryImage(logoBytes),

        height: maxLogoHeight,

        fit: pw.BoxFit.contain,

      );

    }



    return pw.Container(

      margin: const pw.EdgeInsets.only(bottom: 14),

      child: pw.Column(

        crossAxisAlignment: pw.CrossAxisAlignment.stretch,

        children: [

          pw.Row(

            crossAxisAlignment: pw.CrossAxisAlignment.start,

            children: [

              if (logo != null) ...[

                pw.Container(

                  width: 110,

                  constraints: pw.BoxConstraints(maxHeight: maxLogoHeight + 8),

                  alignment: pw.Alignment.centerLeft,

                  child: logo,

                ),

                pw.SizedBox(width: 20),

              ],

              pw.Expanded(

                child: pw.Column(

                  crossAxisAlignment: pw.CrossAxisAlignment.start,

                  children: [

                    if (name.isNotEmpty)

                      pw.Text(

                        name,

                        style: pw.TextStyle(

                          font: fontB,

                          fontSize: 15,

                          color: PdfColors.black,

                          letterSpacing: 0.2,

                        ),

                      ),

                    if (tag.isNotEmpty) ...[

                      pw.SizedBox(height: 4),

                      pw.Text(

                        tag,

                        style: pw.TextStyle(

                          font: fontR,

                          fontSize: 8.5,

                          color: _muted,

                          height: 1.3,

                        ),

                      ),

                    ],

                    pw.SizedBox(height: 10),

                    if (useTwoColumns)

                      pw.Row(

                        crossAxisAlignment: pw.CrossAxisAlignment.start,

                        children: [

                          pw.Expanded(

                            child: _columnBlock(

                              fontR,

                              data.addressLines,

                              color: PdfColors.black,

                            ),

                          ),

                          pw.SizedBox(width: 16),

                          pw.Expanded(

                            child: _columnBlock(

                              fontR,

                              data.contactLines,

                              color: PdfColors.black,

                            ),

                          ),

                        ],

                      )

                    else

                      _columnBlock(

                        fontR,

                        data.contactLines.isNotEmpty

                            ? data.contactLines

                            : data.addressLines,

                        color: PdfColors.black,

                      ),

                  ],

                ),

              ),

            ],

          ),

          if (data.footerLines.isNotEmpty) ...[

            pw.SizedBox(height: 10),

            pw.Container(height: 1, color: _line),

            pw.SizedBox(height: 8),

            pw.Wrap(

              spacing: 12,

              runSpacing: 4,

              children: [

                for (final line in data.footerLines)

                  if (line.trim().isNotEmpty)

                    pw.Text(

                      line.trim(),

                      style: pw.TextStyle(

                        font: fontR,

                        fontSize: 7.5,

                        color: _muted,

                      ),

                    ),

              ],

            ),

          ],

          pw.SizedBox(height: 10),

          pw.Container(height: 2, color: _accent),

        ],

      ),

    );

  }



  /// Kompatibilnost: stari poziv s ravnom listom redova.

  static pw.Widget buildBand({

    required pw.Font fontR,

    required pw.Font fontB,

    required String primaryName,

    required List<String> detailLines,

    Uint8List? logoBytes,

    double maxLogoHeight = 44,

  }) {

    return buildLetterhead(

      fontR: fontR,

      fontB: fontB,

      data: PdfCompanyLetterheadData.fromLegacyLines(

        companyName: primaryName,

        detailLines: detailLines,

      ),

      logoBytes: logoBytes,

      maxLogoHeight: maxLogoHeight,

    );

  }

}

