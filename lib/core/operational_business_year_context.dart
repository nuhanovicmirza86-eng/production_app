import 'package:cloud_firestore/cloud_firestore.dart';

/// Granični datumi aktivne poslovne godine u **lokalnom** vremenu uređaja
/// (dan uključeno: [startLocalInclusive, endLocalExclusive) kao i ostatak MES-a).
class OperationalFyBounds {
  const OperationalFyBounds({
    required this.startLocalInclusive,
    required this.endLocalExclusive,
  });

  final DateTime startLocalInclusive;
  final DateTime endLocalExclusive;

  /// Kalendarska godina kao operativni period 01.01.–01.01. sljedeće godine.
  static OperationalFyBounds forCalendarYear(int y) {
    return OperationalFyBounds(
      startLocalInclusive: DateTime(y, 1, 1),
      endLocalExclusive: DateTime(y + 1, 1, 1),
    );
  }
}

/// Jedan izvor za **aktivnu poslovnu godinu** tenanta na klijentu.
///
/// Redoslijed: `companies.operationalCalendarYear` (scheduler) → `financial_years/{id}`
/// → aktivna godina u šifrarniku → `null` ako još nema podataka.
class OperationalBusinessYearContext {
  OperationalBusinessYearContext._();

  static DateTime _dayLocal(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static OperationalFyBounds? _fromFinancialYearDoc(Map<String, dynamic> m) {
    final s = m['startDate'];
    final e = m['endDate'];
    if (s is! Timestamp || e is! Timestamp) return null;
    final sl = _dayLocal(s.toDate());
    final el = _dayLocal(e.toDate());
    final endExclusive = el.add(const Duration(days: 1));
    return OperationalFyBounds(
      startLocalInclusive: sl,
      endLocalExclusive: endExclusive,
    );
  }

  static Future<OperationalFyBounds?> _fromActiveFinancialYearSubcollection(
    FirebaseFirestore fs,
    String companyId,
  ) async {
    final q = await fs
        .collection('companies')
        .doc(companyId)
        .collection('financial_years')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return _fromFinancialYearDoc(q.docs.first.data());
  }

  /// Vraća granice za filtare / izvještaje ili `null` ako tenant još nema definisanu godinu.
  static Future<OperationalFyBounds?> resolveBoundsForCompany({
    required String companyId,
    FirebaseFirestore? firestore,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return null;
    final fs = firestore ?? FirebaseFirestore.instance;

    final companySnap = await fs.collection('companies').doc(cid).get();
    final root = companySnap.data();
    final mirror = root == null ? null : root['operationalCalendarYear'];
    if (mirror is Map) {
      final fid = (mirror['financialYearId'] ?? '').toString().trim();
      if (fid.isNotEmpty) {
        final fy = await fs
            .collection('companies')
            .doc(cid)
            .collection('financial_years')
            .doc(fid)
            .get();
        if (fy.exists) {
          final b = _fromFinancialYearDoc(fy.data() ?? {});
          if (b != null) return b;
        }
      }
      final yRaw = mirror['year'];
      final y = yRaw is int ? yRaw : int.tryParse(yRaw?.toString() ?? '');
      if (y != null && y > 1900 && y < 2500) {
        return OperationalFyBounds.forCalendarYear(y);
      }
    }

    return _fromActiveFinancialYearSubcollection(fs, cid);
  }

  /// `financialYearId` iz ogledala ili aktivnog dokumenta; prazan string ako nema.
  static Future<String> resolveFinancialYearIdForCompany({
    required String companyId,
    FirebaseFirestore? firestore,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return '';
    final fs = firestore ?? FirebaseFirestore.instance;

    final companySnap = await fs.collection('companies').doc(cid).get();
    final mirror = companySnap.data()?['operationalCalendarYear'];
    if (mirror is Map) {
      final fid = (mirror['financialYearId'] ?? '').toString().trim();
      if (fid.isNotEmpty) return fid;
      final yRaw = mirror['year'];
      final y = yRaw is int ? yRaw : int.tryParse(yRaw?.toString() ?? '');
      if (y != null) return '$y';
    }

    final q = await fs
        .collection('companies')
        .doc(cid)
        .collection('financial_years')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return q.docs.first.id;
    return '';
  }

  /// Zadnji uključeni kalendarski dan u FY.
  static DateTime lastLocalDayInclusive(OperationalFyBounds b) {
    return b.endLocalExclusive.subtract(const Duration(days: 1));
  }

  /// Ograniči odabrani dan na interval FY (OOE / kalendari).
  static DateTime clampLocalCalendarDay(DateTime day, OperationalFyBounds b) {
    final x = DateTime(day.year, day.month, day.day);
    if (x.isBefore(b.startLocalInclusive)) return b.startLocalInclusive;
    final last = lastLocalDayInclusive(b);
    if (x.isAfter(last)) return last;
    return x;
  }

  /// Granice za Material [showDatePicker]. Bez FY zadržava širok raspon oko [referenceDay].
  static ({DateTime firstDate, DateTime lastDate}) materialDatePickerBounds({
    OperationalFyBounds? fy,
    required DateTime referenceDay,
  }) {
    if (fy != null) {
      return (
        firstDate: fy.startLocalInclusive,
        lastDate: lastLocalDayInclusive(fy),
      );
    }
    final y = referenceDay.year;
    return (
      firstDate: DateTime(y - 2, 1, 1),
      lastDate: DateTime(y + 2, 12, 31),
    );
  }
}
