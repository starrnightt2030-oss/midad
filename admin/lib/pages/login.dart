import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> _signIn() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await db.auth.signInWithPassword(email: email.text.trim(), password: password.text);
    } on AuthException catch (e) {
      setState(() => error = e.message.contains('Invalid login') ? 'البريد أو كلمة المرور غير صحيحة' : e.message);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2D1B4E), kBg]),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('أثير', textAlign: TextAlign.center, style: t.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('لوحة الإدارة', textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    onSubmitted: (_) => busy ? null : _signIn(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(onPressed: busy ? null : _signIn, child: Text(busy ? 'جارٍ الدخول…' : 'دخول')),
                  const SizedBox(height: 16),
                  Text('الحساب يُنشأ من Supabase: Authentication ← Users ← Add user.',
                      textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: Colors.white54)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
