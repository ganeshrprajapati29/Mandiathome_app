class ApiConfig {
  /// 👉 Change this to your VPS address after deployment, e.g. 'http://72.60.41.224:5055'
  /// or your domain 'https://api.mandiathome.com'.
  /// For Android emulator + local backend use 'http://10.0.2.2:5055'.
  static const String host = String.fromEnvironment('API_HOST', defaultValue: 'http://72.60.41.224:5055');

  static const String baseUrl = '$host/api';

  /// Resolves relative upload paths (/uploads/x.jpg) into full URLs.
  static String image(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$host$path';
  }
}
