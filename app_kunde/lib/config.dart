/// App-Konfiguration. `API_BASE_URL` wird beim Web-Build per
/// `--dart-define` gesetzt (siehe Dockerfile / docker-compose.yml).
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
