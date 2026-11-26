import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'home.dart';

/// المستمعون: بحث بالبريد، وتفعيل أو إلغاء الاشتراك يدويًا.
class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await db.rpc('admin_find_users', params: {'p_query': _q.text.trim()});
      users = [for (final u in (r as List? ?? const [])) Map<String, dynamic>.from(u as Map)];
      error = null;
    } catch (e) {
      error = 'تعذّر التحميل. تأكد من تشغيل ملف 0004_members.sql.\n$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _grant(Map<String, dynamic> u) async {
    final choice = await showDialog<Duration?>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('تفعيل اشتراك ${u['email']}'),
        children: [
          for (final (label, d) in const [('شهر', Duration(days: 31)), ('٣ شهور', Duration(days: 92)), ('سنة', Duration(days: 366)), ('دائم', Duration.zero)])
            SimpleDialogOption(onPressed: () => Navigator.pop(c, d), child: Padding(padding: const EdgeInsets.all(6), child: Text(label))),
        ],
      ),
    );
    if (choice == null) return;
    // التمديد يبدأ من نهاية الاشتراك الحالي لو ما زال ساريًا
    final current = DateTime.tryParse('${u['until'] ?? ''}');
    final start = current != null && current.isAfter(DateTime.now()) ? current : DateTime.now();
    final until = choice == Duration.zero ? null : start.add(choice).toUtc().toIso8601String();
    await _set(u, true, until);
  }

  Future<void> _set(Map<String, dynamic> u, bool on, String? until) async {
    try {
      await db.rpc('admin_set_premium', params: {'p_user': u['id'], 'p_on': on, 'p_until': until});
      if (mounted) toast(context, on ? 'تم التفعيل' : 'تم الإلغاء');
      _load();
    } catch (e) {
      if (mounted) toast(context, 'تعذّر: $e');
    }
  }

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    return d == null ? '' : '${d.year}/${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final subs = users.where((u) => u['premium'] == true).length;
    return Column(children: [
      PageHeader(title: 'المستمعون', subtitle: '${users.length} حساب • $subs مشترك'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: TextField(
          controller: _q,
          textDirection: TextDirection.ltr,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            hintText: 'ابحث بالبريد',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_back_rounded)),
          ),
        ),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(error!, textAlign: TextAlign.center)))
                : users.isEmpty
                    ? const Center(child: Text('لا يوجد مستمعون بعد. يظهرون هنا بعد إنشاء حساب من التطبيق.', textAlign: TextAlign.center))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: users.length,
                          itemBuilder: (_, i) {
                            final u = users[i];
                            final on = u['premium'] == true;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(on ? Icons.workspace_premium_rounded : Icons.person_outline_rounded, color: on ? kAccent : null),
                                title: Text('${u['email']}', textDirection: TextDirection.ltr, textAlign: TextAlign.right),
                                subtitle: Text(on
                                    ? (u['until'] == null ? 'مشترك — دائم' : 'مشترك حتى ${_date(u['until'] as String?)}')
                                    : 'انضم ${_date(u['created_at'] as String?)}'),
                                trailing: Wrap(children: [
                                  TextButton(onPressed: () => _grant(u), child: Text(on ? 'تمديد' : 'تفعيل')),
                                  if (on)
                                    IconButton(
                                      tooltip: 'إلغاء الاشتراك',
                                      onPressed: () async {
                                        if (await confirm(context, 'إلغاء الاشتراك', 'سيُلغى اشتراك ${u['email']}.', ok: 'إلغاء الاشتراك')) _set(u, false, null);
                                      },
                                      icon: const Icon(Icons.block_rounded),
                                    ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    ]);
  }
}
