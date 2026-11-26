import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/account.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/story_card.dart';

/// حسابي: تسجيل الدخول أو إنشاء حساب، وحالة الاشتراك وطريقة الاشتراك.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _signup = false, _busy = false, _hide = true;
  String? _msg;

  Future<void> _submit() async {
    final acc = context.read<AccountStore>();
    if (!_email.text.contains('@') || _pass.text.length < 6) {
      setState(() => _msg = 'اكتب بريدًا صحيحًا وكلمة مرور من ٦ أحرف على الأقل');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = _signup ? await acc.signUp(_email.text, _pass.text) : await acc.signIn(_email.text, _pass.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountStore>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AtheerBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
            Row(children: [
              GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Text('حسابي', style: MidadText.title(size: 24)),
            ]),
            const SizedBox(height: 24),
            if (acc.signedIn) ..._signedIn(acc) else ..._form(),
            const SizedBox(height: 24),
            SubscribeCard(account: acc),
          ]),
        ),
      ),
    );
  }

  List<Widget> _signedIn(AccountStore acc) => [
        Glass(
          radius: 22,
          opacity: 0.1,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(backgroundColor: MidadColors.accent, child: Icon(Icons.person_rounded, color: MidadColors.ink)),
              const SizedBox(width: 12),
              Expanded(child: Text(acc.email ?? '', style: MidadText.ui(weight: FontWeight.w700))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Icon(acc.premium ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, color: acc.premium ? MidadColors.accent : Colors.white60),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  acc.premium
                      ? (acc.until == null ? 'مشترك — اشتراك دائم' : 'مشترك حتى ${acc.until!.year}/${acc.until!.month}/${acc.until!.day}')
                      : 'غير مشترك',
                  style: MidadText.ui(weight: FontWeight.w600),
                ),
              ),
              TextButton(onPressed: acc.refreshStatus, child: const Text('تحديث')),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: acc.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('تسجيل الخروج'),
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
        ),
      ];

  List<Widget> _form() => [
        Text(_signup ? 'حساب جديد' : 'تسجيل الدخول', style: MidadText.title(size: 20)),
        const SizedBox(height: 6),
        Text('الحساب يحفظ اشتراكك ويفتحه على أي جهاز.', style: MidadText.ui(size: 13, color: Colors.white70)),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: _dec('البريد الإلكتروني', Icons.alternate_email_rounded),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _pass,
          obscureText: _hide,
          textDirection: TextDirection.ltr,
          onSubmitted: (_) => _submit(),
          decoration: _dec('كلمة المرور', Icons.lock_outline_rounded).copyWith(
            suffixIcon: IconButton(
              tooltip: _hide ? 'إظهار' : 'إخفاء',
              onPressed: () => setState(() => _hide = !_hide),
              icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            ),
          ),
        ),
        if (_msg != null) ...[
          const SizedBox(height: 10),
          Text(_msg!, style: MidadText.ui(size: 13, color: const Color(0xFFF2A7A0))),
        ],
        const SizedBox(height: 16),
        _busy
            ? const Center(child: CircularProgressIndicator())
            : AccentButton(label: _signup ? 'إنشاء الحساب' : 'دخول', onTap: _submit),
        TextButton(
          onPressed: () => setState(() {
            _signup = !_signup;
            _msg = null;
          }),
          child: Text(_signup ? 'عندي حساب، سجّل الدخول' : 'ليس لديك حساب؟ أنشئ حسابًا'),
        ),
      ];

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: MidadColors.surfaceHigh.op(0.7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );
}

/// بطاقة «اشترك»: المزايا والسعر وطريقة الدفع (من اللوحة).
class SubscribeCard extends StatelessWidget {
  final AccountStore account;
  const SubscribeCard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    if (account.premium) return const SizedBox.shrink();
    final price = account.infoText('price');
    final how = account.infoText('subscribe_text', 'ادفع الاشتراك ثم أرسل بريد حسابك، ويُفعَّل خلال وقت قصير.');
    final wa = account.infoText('whatsapp').replaceAll(RegExp(r'[^0-9]'), '');
    return Glass(
      radius: 22,
      opacity: 0.1,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.workspace_premium_rounded, color: MidadColors.accent),
          const SizedBox(width: 8),
          Text('اشترك في ${AppConfig.appName}', style: MidadText.title(size: 18)),
          const Spacer(),
          if (price.isNotEmpty) Text(price, style: MidadText.ui(weight: FontWeight.w700, color: MidadColors.accent)),
        ]),
        const SizedBox(height: 10),
        for (final b in const ['كل القصص والحكايات المقفولة', 'صوت الراوي والقراءة الحية كاملة', 'تحميل القصص للاستماع بدون إنترنت'])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.check_rounded, size: 18, color: MidadColors.accent),
              const SizedBox(width: 6),
              Expanded(child: Text(b, style: MidadText.ui(size: 13))),
            ]),
          ),
        const SizedBox(height: 8),
        Text(how, style: MidadText.ui(size: 12, color: Colors.white70, height: 1.6)),
        const SizedBox(height: 12),
        if (!account.signedIn)
          Text('سجّل الدخول أولًا حتى يُربط الاشتراك بحسابك.', style: MidadText.ui(size: 12, color: Colors.white60))
        else if (wa.isNotEmpty)
          AccentButton(
            label: 'اشترك عبر واتساب',
            icon: Icons.chat_rounded,
            height: 46,
            onTap: () => launchUrl(
              Uri.parse('https://wa.me/$wa?text=${Uri.encodeComponent('أريد الاشتراك في ${AppConfig.appName}. بريد حسابي: ${account.email}')}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
      ]),
    );
  }
}

/// تُعرض عند فتح قصة مقفولة لغير المشترك.
Future<void> showPaywall(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: MidadColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('هذه القصة للمشتركين', textAlign: TextAlign.center, style: MidadText.title(size: 20)),
          const SizedBox(height: 14),
          Consumer<AccountStore>(builder: (_, acc, __) => SubscribeCard(account: acc)),
          const SizedBox(height: 12),
          Consumer<AccountStore>(
            builder: (_, acc, __) => acc.signedIn
                ? TextButton(onPressed: () => acc.refreshStatus(), child: const Text('اشتركت بالفعل؟ حدّث الحالة'))
                : AccentButton(
                    label: 'تسجيل الدخول أو إنشاء حساب',
                    height: 48,
                    onTap: () {
                      Navigator.pop(c);
                      Navigator.of(context).push(fadeRoute(const AccountScreen()));
                    },
                  ),
          ),
        ]),
      ),
    ),
  );
}
