import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'config.dart';
import 'pages/home.dart';
import 'pages/login.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(url: AdminConfig.supabaseUrl, anonKey: AdminConfig.supabaseKey)
        .timeout(const Duration(seconds: 20));
  } catch (e) {
    runApp(_BootError(error: e.toString()));
    return;
  }
  runApp(const AdminApp());
}

/// تظهر بدل الصفحة الفارغة لو تعذّر الاتصال بقاعدة البيانات عند الفتح.
class _BootError extends StatelessWidget {
  final String error;
  const _BootError({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: adminTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 12),
                const Text('تعذّر الاتصال بقاعدة البيانات. تأكد من الإنترنت ثم أعد تحميل الصفحة.', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أثير — لوحة الإدارة',
      debugShowCheckedModeBanner: false,
      theme: adminTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// يعرض الدخول، ثم يتحقق أن الحساب أدمن قبل فتح اللوحة.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, _) {
        final session = db.auth.currentSession;
        if (session == null) return const LoginPage();
        return FutureBuilder<bool>(
          key: ValueKey(session.user.id),
          future: db.rpc('claim_admin').then((v) => v == true),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snap.data != true) return NotAdminPage(error: snap.error?.toString());
            return const AdminHome();
          },
        );
      },
    );
  }
}

class NotAdminPage extends StatelessWidget {
  final String? error;
  const NotAdminPage({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text(error == null ? 'هذا الحساب ليس له صلاحية الإدارة.' : 'تعذّر التحقق من الصلاحية. تأكد من تشغيل ملفات قاعدة البيانات.',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: () => db.auth.signOut(), child: const Text('تسجيل الخروج')),
            ]),
          ),
        ),
      ),
    );
  }
}
