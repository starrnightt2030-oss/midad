import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'home.dart';

/// الإعدادات: أرقام المحتوى، الحساب، وتذكير بحدود الخطة المجانية.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<Map<String, dynamic>?> _stats = _load();

  Future<Map<String, dynamic>?> _load() async {
    final r = await db.rpc('admin_stats');
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }

  @override
  Widget build(BuildContext context) {
    final user = db.auth.currentUser;
    return RefreshIndicator(
      onRefresh: () async => setState(() => _stats = _load()),
      child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const PageHeader(title: 'الإعدادات', subtitle: 'نظرة عامة على المحتوى والحساب'),
        FutureBuilder(
          future: _stats,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return Padding(padding: const EdgeInsets.all(20), child: Text('تعذّر تحميل الأرقام: ${snap.error}'));
            }
            final s = snap.data ?? const {};
            final items = [
              ('الأقسام', s['worlds'], Icons.grid_view_rounded),
              ('القصص', s['works'], Icons.auto_stories_rounded),
              ('منشورة', s['published'], Icons.public_rounded),
              ('بالاشتراك', s['premium'], Icons.lock_rounded),
              ('الفصول', s['chapters'], Icons.list_rounded),
              ('فصول بصوت', s['with_audio'], Icons.graphic_eq_rounded),
              ('المستمعون', s['users'], Icons.people_rounded),
              ('المشتركون', s['subscribers'], Icons.workspace_premium_rounded),
            ];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                for (final (label, value, icon) in items)
                  SizedBox(
                    width: 160,
                    child: Card(
                      color: kSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(icon, color: kAccent),
                          const SizedBox(height: 10),
                          Text('${value ?? 0}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                          Text(label, style: const TextStyle(color: Colors.white60)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            );
          },
        ),
        const SizedBox(height: 20),
        const _SubscribeSettings(),
        _Section(title: 'الحساب', children: [
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(user?.email ?? '—'),
            subtitle: const Text('مدير المحتوى'),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('تسجيل الخروج'),
            onTap: () => db.auth.signOut(),
          ),
        ]),
        const _Section(title: 'نصائح للخطة المجانية', children: [
          ListTile(
            leading: Icon(Icons.storage_rounded),
            title: Text('مساحة التخزين ١ جيجا'),
            subtitle: Text('استخدم صوت MP3 أو M4A بجودة 64 إلى 96 kbps، وغلاف JPG أو WebP أقل من 300 كيلوبايت.'),
          ),
          ListTile(
            leading: Icon(Icons.cloud_download_rounded),
            title: Text('نقل البيانات ٥ جيجا شهريًا'),
            subtitle: Text('كل استماع كامل يحسب من هذا الرصيد، فالملفات الأصغر تخدم مستمعين أكثر.'),
          ),
          ListTile(
            leading: Icon(Icons.visibility_off_rounded),
            title: Text('المسودات لا تظهر'),
            subtitle: Text('القصة تظهر في التطبيق فقط بعد تفعيل «منشورة»، والقسم كذلك.'),
          ),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        color: kSurface,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: kAccent)),
          ),
          ...children,
        ]),
      ),
    );
  }
}

/// طريقة الاشتراك التي تظهر للمستمعين في التطبيق.
class _SubscribeSettings extends StatefulWidget {
  const _SubscribeSettings();

  @override
  State<_SubscribeSettings> createState() => _SubscribeSettingsState();
}

class _SubscribeSettingsState extends State<_SubscribeSettings> {
  final price = TextEditingController();
  final whatsapp = TextEditingController();
  final text = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await db.from('app_settings').select().like('key', 'public.%');
      final m = {for (final r in rows) r['key'] as String: r['value']};
      if (!mounted) return;
      setState(() {
        price.text = '${m['public.price'] ?? ''}';
        whatsapp.text = '${m['public.whatsapp'] ?? ''}';
        text.text = '${m['public.subscribe_text'] ?? ''}';
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await db.from('app_settings').upsert([
        {'key': 'public.price', 'value': price.text.trim()},
        {'key': 'public.whatsapp', 'value': whatsapp.text.trim()},
        {'key': 'public.subscribe_text', 'value': text.text.trim()},
      ]);
      if (mounted) toast(context, 'تم الحفظ، وسيظهر في التطبيق');
    } catch (e) {
      if (mounted) toast(context, 'تعذّر الحفظ: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return _Section(title: 'الاشتراك في التطبيق', children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(children: [
          TextField(controller: price, decoration: const InputDecoration(labelText: 'السعر (مثال: ٥٠ جنيه شهريًا)')),
          const SizedBox(height: 10),
          TextField(
            controller: whatsapp,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رقم واتساب للاشتراك (بالكود الدولي، مثال 2010xxxxxxxx)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: text,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'طريقة الدفع (مثال: حوّل على فودافون كاش ثم ابعت صورة التحويل)'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'جارٍ…' : 'حفظ')),
          ),
        ]),
      ),
    ]);
  }
}
