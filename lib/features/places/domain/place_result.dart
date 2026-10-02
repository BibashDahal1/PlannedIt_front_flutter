class PlaceResult {
  final String? name; // shop / venue / place name, when one exists
  final String? address; // street, area, city
  final double latitude;
  final double longitude;

  const PlaceResult({
    this.name,
    this.address,
    required this.latitude,
    required this.longitude,
  });

  String get title => name ?? address ?? 'Dropped pin';
  String get subtitle => name != null ? (address ?? '') : '';
}
