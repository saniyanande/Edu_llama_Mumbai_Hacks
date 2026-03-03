/// E6: Central config — override BASE_URL at build time with:
/// flutter run --dart-define=BASE_URL=http://YOUR_IP:6000/api
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:6000/api',
  );
}
