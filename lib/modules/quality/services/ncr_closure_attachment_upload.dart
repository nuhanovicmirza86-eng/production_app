import 'dart:typed_data';
/// M1-I12-D — upload priloga zatvaranja (foto / dokument) preko Callable.
class NcrClosureAttachmentUploader {
  static const int maxBytes = 7 * 1024 * 1024;

  static String? validateBeforeUpload({
    required Uint8List bytes,
    required String contentType,
  }) {
    if (bytes.isEmpty) {
      return 'Datoteka je prazna. Odaberite drugi fajl.';
    }
    if (bytes.length > maxBytes) {
      return 'Datoteka je prevelika (maks. 7 MB). Odaberite manji fajl.';
    }
    if (!_allowedContentTypes.contains(contentType.toLowerCase())) {
      return 'Tip datoteke nije dozvoljen. Dozvoljene su fotografije (JPG, PNG, WEBP), '
          'PDF i Office dokumenti (DOCX, XLSX).';
    }
    return null;
  }

  static const Set<String> _allowedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  static String? guessMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    return null;
  }
}

class NcrClosureUploadedAttachment {
  const NcrClosureUploadedAttachment({
    required this.label,
    required this.storagePath,
    required this.fileName,
  });

  final String label;
  final String storagePath;
  final String fileName;

  Map<String, String> toPayload() => {
        'label': label,
        'storagePath': storagePath,
      };
}

class NcrClosureAttachmentUploadInfo {
  const NcrClosureAttachmentUploadInfo({
    required this.uploadUrl,
    required this.storagePath,
    required this.contentType,
  });

  final String uploadUrl;
  final String storagePath;
  final String contentType;
}
