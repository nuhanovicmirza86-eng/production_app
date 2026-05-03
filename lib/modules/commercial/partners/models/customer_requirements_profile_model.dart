import 'package:cloud_firestore/cloud_firestore.dart';

/// `customer_requirements_profiles/{customerId}` — CSR za Launch Intelligence / IATF.
class CustomerRequirementsProfileModel {
  const CustomerRequirementsProfileModel({
    required this.customerId,
    required this.companyId,
    this.customerNameSnapshot,
    this.ppapLevel = 'none',
    this.specialRequirements = '',
    this.changeNotificationWeeks,
    this.packagingNotes = '',
    this.documentationRequirements = '',
    this.reactionPlanPolicy = '',
    this.tolerancePolicy = '',
    this.csrDocumentReference = '',
    this.communicationContacts = const [],
    this.updatedAt,
    this.updatedBy = '',
  });

  final String customerId;
  final String companyId;
  final String? customerNameSnapshot;
  final String ppapLevel;
  final String specialRequirements;
  final int? changeNotificationWeeks;
  final String packagingNotes;
  final String documentationRequirements;
  final String reactionPlanPolicy;
  final String tolerancePolicy;
  final String csrDocumentReference;
  final List<CustomerRequirementsContact> communicationContacts;
  final DateTime? updatedAt;
  final String updatedBy;

  static String _s(dynamic v) => (v ?? '').toString();

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  static List<CustomerRequirementsContact> _contacts(dynamic v) {
    if (v is! List) return const [];
    final out = <CustomerRequirementsContact>[];
    for (final x in v) {
      if (x is Map) {
        out.add(CustomerRequirementsContact(
          name: _s(x['name']),
          role: _s(x['role']),
          email: _s(x['email']),
          phone: _s(x['phone']),
        ));
      }
    }
    return out;
  }

  factory CustomerRequirementsProfileModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final w = data['changeNotificationWeeks'];
    int? weeks;
    if (w is int) {
      weeks = w;
    } else if (w is num) {
      weeks = w.toInt();
    }
    return CustomerRequirementsProfileModel(
      customerId: doc.id,
      companyId: _s(data['companyId']),
      customerNameSnapshot: () {
        final s = _s(data['customerNameSnapshot']);
        return s.isEmpty ? null : s;
      }(),
      ppapLevel: _s(data['ppapLevel']).isEmpty ? 'none' : _s(data['ppapLevel']),
      specialRequirements: _s(data['specialRequirements']),
      changeNotificationWeeks: weeks,
      packagingNotes: _s(data['packagingNotes']),
      documentationRequirements: _s(data['documentationRequirements']),
      reactionPlanPolicy: _s(data['reactionPlanPolicy']),
      tolerancePolicy: _s(data['tolerancePolicy']),
      csrDocumentReference: _s(data['csrDocumentReference']),
      communicationContacts: _contacts(data['communicationContacts']),
      updatedAt: _ts(data['updatedAt']),
      updatedBy: _s(data['updatedBy']),
    );
  }

  Map<String, dynamic> toCallablePatch() {
    return {
      'ppapLevel': ppapLevel,
      'specialRequirements': specialRequirements,
      'changeNotificationWeeks': changeNotificationWeeks,
      'packagingNotes': packagingNotes,
      'documentationRequirements': documentationRequirements,
      'reactionPlanPolicy': reactionPlanPolicy,
      'tolerancePolicy': tolerancePolicy,
      'csrDocumentReference': csrDocumentReference,
      'communicationContacts': communicationContacts
          .map(
            (c) => {
              'name': c.name,
              'role': c.role,
              'email': c.email,
              'phone': c.phone,
            },
          )
          .toList(),
    };
  }

  factory CustomerRequirementsProfileModel.empty({
    required String companyId,
    required String customerId,
    String? customerNameSnapshot,
  }) {
    return CustomerRequirementsProfileModel(
      companyId: companyId,
      customerId: customerId,
      customerNameSnapshot: customerNameSnapshot,
    );
  }
}

class CustomerRequirementsContact {
  const CustomerRequirementsContact({
    this.name = '',
    this.role = '',
    this.email = '',
    this.phone = '',
  });

  final String name;
  final String role;
  final String email;
  final String phone;
}
