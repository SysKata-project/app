class AppConfig {
  const AppConfig({
    required this.environment,
    required this.useFakeServices,
    required this.apiBaseUrl,
  });
  factory AppConfig.fromEnvironment() {
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'development',
    );
    const fake = bool.fromEnvironment('USE_FAKE_SERVICES', defaultValue: true);
    const url = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.example.invalid',
    );
    if (!['development', 'staging', 'production'].contains(environment)) {
      throw ArgumentError('Unknown environment');
    }
    if (environment != 'development' && fake) {
      throw ArgumentError('Fake services are restricted to development');
    }
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError('API_BASE_URL must be an HTTPS origin');
    }
    return AppConfig(
      environment: environment,
      useFakeServices: fake,
      apiBaseUrl: uri,
    );
  }
  final String environment;
  final bool useFakeServices;
  final Uri apiBaseUrl;
}
