class Env {
  Env._();
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://2n9h26n5-8000.inc1.devtunnels.ms/api/v1',
    // defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  static String get wsBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$wsScheme://${uri.host}$port';
  }
}
