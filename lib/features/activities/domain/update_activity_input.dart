/// Partial update -- only non-null fields are sent. Per the API,
/// location is all-or-nothing: if you're changing it at all, send
/// every one of its 4 sub-fields (no partial location merge support).
class UpdateActivityInput {
  final String? title;
  final String? description;
  final ({
    double latitude,
    double longitude,
    String? addressText,
    String? venueName,
  })?
  location;

  const UpdateActivityInput({this.title, this.description, this.location});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (title != null) json['title'] = title;
    if (description != null) json['description'] = description;
    if (location != null) {
      json['location'] = {
        'latitude': location!.latitude,
        'longitude': location!.longitude,
        'address_text': location!.addressText ?? '',
        'venue_name': location!.venueName ?? '',
      };
    }
    return json;
  }
}
