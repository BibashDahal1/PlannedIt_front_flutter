List<T> parseListResponse<T>(
  dynamic data,
  T Function(Map<String, dynamic> json) fromJson, {
  required String resourceName,
}) {
  final rawResults = _extractList(data, resourceName);

  return rawResults
      .map((item) {
        if (item is! Map) {
          throw FormatException('Invalid item in $resourceName response');
        }
        return fromJson(Map<String, dynamic>.from(item));
      })
      .toList(growable: false);
}

List<dynamic> _extractList(dynamic data, String resourceName) {
  if (data is List) return data;

  if (data is Map) {
    final results = data['results'];
    if (results is List || results is Map) {
      return _extractList(results, resourceName);
    }

    final nestedData = data['data'];
    if (nestedData is List || nestedData is Map) {
      return _extractList(nestedData, resourceName);
    }
  }

  throw FormatException('Unexpected $resourceName response');
}
