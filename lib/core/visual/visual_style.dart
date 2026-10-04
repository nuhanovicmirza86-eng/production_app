/// Trajni vizualni jezik Operonix Productiona.
///
/// Content/layout preferenca (Standardno / Ikone) je zasebna os i ne živi ovdje.
enum VisualStyle {
  classic('classic'),
  premium('premium');

  const VisualStyle(this.storageValue);

  final String storageValue;

  static VisualStyle fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'premium':
        return VisualStyle.premium;
      default:
        return VisualStyle.classic;
    }
  }
}
