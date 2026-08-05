class FilmsozAppInfo {
  const FilmsozAppInfo._();

  static const String name = 'Filmsoz Studio';
  static const String version = '2.0.0';
  static const int buildNumber = 20;
  static const int projectFormatVersion = 3;
  static const String company = 'Filmsoz';
  static const String copyright = '© 2026 Filmsoz';

  static String get fullVersion => '$version+$buildNumber';
  static String get displayVersion => 'Версия $version (сборка $buildNumber)';
}
