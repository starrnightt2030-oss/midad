/// إعدادات التطبيق العامة.
///
/// [remoteContentBase] هو رابط مجلد المحتوى على الإنترنت.
/// التطبيق يقرأ منه `catalog.json` عند كل تشغيل وكل مرة يرجع فيها المستخدم للتطبيق،
/// فأي كتاب أو عالم تضيفه في مجلد `content/` على GitHub يظهر للمستخدمين تلقائيًا
/// بدون بناء نسخة جديدة. لو مفيش إنترنت، يستخدم النسخة المحفوظة ثم المدمجة.
class AppConfig {
  static const String appName = 'أثير';
  static const String appNameLatin = 'ATHEER';
  static const String tagline = 'قصص وحكايات .. وحكم من الحياة';

  /// رقم الإصدار والبناء يحقنهما GitHub Actions وقت البناء تلقائيًا.
  static const String version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const int build = int.fromEnvironment('BUILD_NUMBER', defaultValue: 1);

  static const String developer = 'Mohamedd-Eldawly';
  static const String githubRepo = 'starrnightt2030-oss/midad';
  static const String developerGithub = 'https://github.com/starrnightt2030-oss';

  static const String remoteContentBase = 'https://raw.githubusercontent.com/$githubRepo/main/content/';

  /// مجلد المحتوى المدمج داخل التطبيق (نسخة احتياطية تعمل بدون إنترنت).
  static const String bundledContentBase = 'content/';

  static const Duration remoteTimeout = Duration(seconds: 8);
}
