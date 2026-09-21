import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'branding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
  runApp(const MachineryApp());
}

SupabaseClient get supabase => Supabase.instance.client;

class MachineryApp extends StatelessWidget {
  const MachineryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: CKBranding.companyName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: CKBranding.accent,
          primary: CKBranding.accent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: CKBranding.primary,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: AppConfig.isConfigured
          ? const AuthGate()
          : const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'App is not configured.\nBuild with SUPABASE_URL and SUPABASE_ANON_KEY (see DEPLOY.md).',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------- helpers

String fmtNum(dynamic v) {
  if (v == null) return '-';
  final d = double.tryParse(v.toString());
  if (d == null) return v.toString();
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
}

Color statusColor(String s) {
  switch (s) {
    case 'approved':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    default:
      return Colors.orange;
  }
}

Widget statusChip(String s) => Chip(
      label: Text(s.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: statusColor(s),
      visualDensity: VisualDensity.compact,
    );

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

String errText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  return e.toString();
}

Future<String?> askText(BuildContext context, String title, String label,
    {bool required = true}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c,
          maxLines: 3,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder())),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (required && c.text.trim().isEmpty) return;
            Navigator.pop(ctx, c.text.trim());
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- auth

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final session = supabase.auth.currentSession;
        if (session == null) return const LoginPage();
        return HomePage(key: ValueKey(session.user.id));
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await supabase.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } catch (e) {
      setState(() => error = 'Login failed. Check email and password.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(CKBranding.logoAsset, height: 110),
                  const SizedBox(height: 16),
                  Text(CKBranding.companyName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(CKBranding.tagline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 32),
                  TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: password,
                      obscureText: true,
                      onSubmitted: (_) => loading ? null : login(),
                      decoration: const InputDecoration(
                          labelText: 'Password', border: OutlineInputBorder())),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: loading ? null : login,
                    child: Text(loading ? 'Signing in...' : 'Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------- home

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<Map<String, dynamic>> profile() async {
    final id = supabase.auth.currentUser!.id;
    return await supabase
        .from('profiles')
        .select('full_name, role, active')
        .eq('id', id)
        .single();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Map<String, dynamic>>(
        future: profile(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text(CKBranding.companyName)),
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Could not load your profile.'),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: () => supabase.auth.signOut(),
                      child: const Text('Sign out')),
                ]),
              ),
            );
          }
          if (!snap.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final p = snap.data!;
          if (p['active'] != true) {
            return Scaffold(
              appBar: AppBar(title: const Text(CKBranding.companyName)),
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Your account is disabled. Contact admin.'),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: () => supabase.auth.signOut(),
                      child: const Text('Sign out')),
                ]),
              ),
            );
          }
          final admin = p['role'] == 'admin';
          return Scaffold(
            appBar: AppBar(
              title: Text(admin ? 'Admin Dashboard' : 'Employee Dashboard'),
              actions: [
                IconButton(
                    tooltip: 'Sign out',
                    onPressed: () => supabase.auth.signOut(),
                    icon: const Icon(Icons.logout)),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Welcome, ${p['full_name']}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                _tile(context, Icons.add_circle, 'Daily Running Record',
                    'Enter today’s machine readings', const NewRecordPage()),
                _tile(context, Icons.history, 'My Records',
                    'View submitted running records', const MyRecordsPage()),
                if (admin) ...[
                  _tile(context, Icons.fact_check, 'Review Records',
                      'Check, edit, approve or reject submissions',
                      const AdminRecordsPage()),
                  _tile(context, Icons.precision_manufacturing, 'Machines',
                      'Add and manage machines',
                      const MasterDataPage(machines: true)),
                  _tile(context, Icons.location_on, 'Sites',
                      'Add and manage sites / customers',
                      const MasterDataPage(machines: false)),
                ],
              ],
            ),
          );
        },
      );

  Widget _tile(BuildContext context, IconData icon, String title, String sub,
          Widget page) =>
      Card(
        child: ListTile(
          leading: Icon(icon, color: CKBranding.accent),
          title: Text(title),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => page)),
        ),
      );
}

// ---------------------------------------------------------------- new record

class NewRecordPage extends StatefulWidget {
  const NewRecordPage({super.key});
  @override
  State<NewRecordPage> createState() => _NewRecordPageState();
}

class _NewRecordPageState extends State<NewRecordPage> {
  final opening = TextEditingController();
  final closing = TextEditingController();
  final fuel = TextEditingController();
  final operator = TextEditingController();
  final work = TextEditingController();
  final downtime = TextEditingController();
  final remarks = TextEditingController();
  String? machineId;
  String? siteId;
  DateTime date = DateTime.now();
  List<Map<String, dynamic>> machines = [];
  List<Map<String, dynamic>> sites = [];
  bool loading = true, saving = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      machines = List<Map<String, dynamic>>.from(
          await supabase.from('machines').select().eq('active', true).order('name'));
      sites = List<Map<String, dynamic>>.from(
          await supabase.from('sites').select().eq('active', true).order('name'));
    } catch (e) {
      loadError = errText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  double get hours {
    final a = double.tryParse(opening.text) ?? 0;
    final b = double.tryParse(closing.text) ?? 0;
    return (b - a).clamp(0, double.infinity).toDouble();
  }

  Future<void> save() async {
    final o = double.tryParse(opening.text);
    final c = double.tryParse(closing.text);
    if (machineId == null || siteId == null || o == null || c == null) {
      snack(context, 'Select machine/site and enter meter readings.');
      return;
    }
    if (c < o) {
      snack(context, 'Closing meter cannot be less than opening meter.');
      return;
    }
    final f = fuel.text.trim().isEmpty ? null : double.tryParse(fuel.text);
    final d = downtime.text.trim().isEmpty ? null : double.tryParse(downtime.text);
    if ((fuel.text.trim().isNotEmpty && (f == null || f < 0)) ||
        (downtime.text.trim().isNotEmpty && (d == null || d < 0))) {
      snack(context, 'Fuel and downtime must be valid positive numbers.');
      return;
    }
    setState(() => saving = true);
    try {
      await supabase.from('running_records').insert({
        'employee_id': supabase.auth.currentUser!.id,
        'machine_id': machineId,
        'site_id': siteId,
        'record_date': DateFormat('yyyy-MM-dd').format(date),
        'opening_meter': o,
        'closing_meter': c,
        'fuel_liters': f,
        'operator_name': operator.text.trim(),
        'work_description': work.text.trim(),
        'downtime_hours': d,
        'remarks': remarks.text.trim(),
      });
      if (mounted) {
        snack(context, 'Record submitted for admin review.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) snack(context, 'Could not save record: ${errText(e)}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (loadError != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Daily Running Record')),
          body: Center(child: Text(loadError!)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Running Record')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              trailing: Text(DateFormat('dd MMM yyyy').format(date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime.now().subtract(const Duration(days: 60)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => date = picked);
              },
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              value: machineId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Machine', border: OutlineInputBorder()),
              items: machines
                  .map((m) => DropdownMenuItem(
                      value: m['id'].toString(),
                      child: Text('${m['name']} (${m['code']})')))
                  .toList(),
              onChanged: (v) => setState(() => machineId = v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              value: siteId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Site / Customer', border: OutlineInputBorder()),
              items: sites
                  .map((s) => DropdownMenuItem(
                      value: s['id'].toString(), child: Text(s['name'])))
                  .toList(),
              onChanged: (v) => setState(() => siteId = v)),
          const SizedBox(height: 12),
          _field(opening, 'Opening meter reading', TextInputType.number),
          _field(closing, 'Closing meter reading', TextInputType.number),
          Card(
              child: ListTile(
                  title: const Text('Calculated running hours'),
                  trailing: Text(hours.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 12),
          _field(fuel, 'Fuel used (litres)', TextInputType.number),
          _field(operator, 'Operator name', TextInputType.text),
          _field(work, 'Work performed', TextInputType.multiline),
          _field(downtime, 'Downtime (hours)', TextInputType.number),
          _field(remarks, 'Remarks', TextInputType.multiline),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.send),
              label: Text(saving ? 'Submitting...' : 'Submit Record')),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, TextInputType type) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
              controller: c,
              keyboardType: type,
              maxLines: type == TextInputType.multiline ? 3 : 1,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder())));
}

// ---------------------------------------------------------------- my records

class MyRecordsPage extends StatefulWidget {
  const MyRecordsPage({super.key});
  @override
  State<MyRecordsPage> createState() => _MyRecordsPageState();
}

class _MyRecordsPageState extends State<MyRecordsPage> {
  Future<List<Map<String, dynamic>>> getRows() async =>
      List<Map<String, dynamic>>.from(await supabase
          .from('running_records')
          .select('*, machines(name,code), sites(name), profiles!running_records_employee_id_fkey(full_name)')
          .eq('employee_id', supabase.auth.currentUser!.id)
          .order('record_date', ascending: false)
          .order('created_at', ascending: false));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Records')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: getRows(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text(errText(snap.error!)));
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snap.data!;
            if (rows.isEmpty) return const Center(child: Text('No records yet.'));
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) => _RecordCard(
                    record: rows[i], admin: false, onChanged: () => setState(() {})),
              ),
            );
          },
        ),
      );
}

class _RecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final bool admin;
  final VoidCallback onChanged;
  const _RecordCard(
      {required this.record, required this.admin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final who = admin ? '${r['profiles']?['full_name'] ?? ''} • ' : '';
    return Card(
      child: ListTile(
        title: Text('${r['record_date']} • ${r['machines']?['name'] ?? ''}'),
        subtitle: Text(
            '$who${fmtNum(r['running_hours'])} hrs • ${r['sites']?['name'] ?? ''}'),
        trailing: statusChip(r['status'].toString()),
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RecordDetailPage(record: r, admin: admin)));
          onChanged();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- detail

class RecordDetailPage extends StatefulWidget {
  final Map<String, dynamic> record;
  final bool admin;
  const RecordDetailPage({super.key, required this.record, required this.admin});
  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  late Map<String, dynamic> r;
  List<Map<String, dynamic>> history = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    r = widget.record;
    if (widget.admin) loadHistory();
  }

  Future<void> refresh() async {
    final row = await supabase
        .from('running_records')
        .select('*, machines(name,code), sites(name), profiles!running_records_employee_id_fkey(full_name)')
        .eq('id', r['id'])
        .single();
    if (mounted) setState(() => r = row);
    if (widget.admin) await loadHistory();
  }

  Future<void> loadHistory() async {
    final rows = await supabase
        .from('record_edit_history')
        .select('*, profiles(full_name)')
        .eq('record_id', r['id'])
        .order('edited_at', ascending: false);
    if (mounted) setState(() => history = List<Map<String, dynamic>>.from(rows));
  }

  Future<void> review(String status) async {
    String? reason;
    if (status == 'rejected') {
      reason = await askText(context, 'Reject record', 'Reason for rejection');
      if (reason == null) return;
    }
    setState(() => busy = true);
    try {
      await supabase.rpc('review_record',
          params: {'p_id': r['id'], 'p_status': status, 'p_reason': reason});
      await refresh();
      if (mounted) snack(context, 'Record $status.');
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget row(String k, dynamic v) => ListTile(
        dense: true,
        title: Text(k, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        subtitle: Text((v == null || v.toString().isEmpty) ? '-' : v.toString(),
            style: const TextStyle(fontSize: 15, color: Colors.black87)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Record Details')),
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                statusChip(r['status'].toString()),
                const Spacer(),
                Text('${fmtNum(r['running_hours'])} hrs',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
            ),
            row('Date', r['record_date']),
            row('Employee', r['profiles']?['full_name']),
            row('Machine', '${r['machines']?['name']} (${r['machines']?['code']})'),
            row('Site', r['sites']?['name']),
            row('Opening meter', fmtNum(r['opening_meter'])),
            row('Closing meter', fmtNum(r['closing_meter'])),
            row('Fuel (litres)', fmtNum(r['fuel_liters'])),
            row('Operator', r['operator_name']),
            row('Work performed', r['work_description']),
            row('Downtime (hours)', fmtNum(r['downtime_hours'])),
            row('Remarks', r['remarks']),
            if (widget.admin) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                      onPressed: busy ? null : () => review('approved'),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve')),
                  OutlinedButton.icon(
                      onPressed: busy ? null : () => review('rejected'),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject')),
                  OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final saved = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AdminEditPage(record: r)));
                              if (saved == true) await refresh();
                            },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit')),
                ]),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Audit history',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (history.isEmpty)
                const ListTile(dense: true, title: Text('No changes yet.')),
              ...history.map((h) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(h['reason']?.toString() ?? ''),
                    subtitle: Text(
                        '${h['profiles']?['full_name'] ?? ''} • ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(h['edited_at']).toLocal())}'),
                  )),
              const SizedBox(height: 24),
            ],
          ],
        ),
      );
}

// ---------------------------------------------------------------- admin

class AdminRecordsPage extends StatefulWidget {
  const AdminRecordsPage({super.key});
  @override
  State<AdminRecordsPage> createState() => _AdminRecordsPageState();
}

class _AdminRecordsPageState extends State<AdminRecordsPage> {
  String filter = 'pending';

  Future<List<Map<String, dynamic>>> getRows() async {
    var q = supabase
        .from('running_records')
        .select('*, profiles!running_records_employee_id_fkey(full_name), machines(name,code), sites(name)');
    final data = filter == 'all'
        ? await q.order('record_date', ascending: false).limit(300)
        : await q
            .eq('status', filter)
            .order('record_date', ascending: false)
            .limit(300);
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Review Records')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['pending', 'approved', 'rejected', 'all']
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s[0].toUpperCase() + s.substring(1)),
                            selected: filter == s,
                            onSelected: (_) => setState(() => filter = s),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: getRows(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text(errText(snap.error!)));
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return const Center(child: Text('No records.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _RecordCard(
                        record: rows[i],
                        admin: true,
                        onChanged: () => setState(() {})),
                  ),
                );
              },
            ),
          ),
        ]),
      );
}

class AdminEditPage extends StatefulWidget {
  final Map<String, dynamic> record;
  const AdminEditPage({super.key, required this.record});
  @override
  State<AdminEditPage> createState() => _AdminEditPageState();
}

class _AdminEditPageState extends State<AdminEditPage> {
  late final opening = TextEditingController(text: fmtNum(widget.record['opening_meter']));
  late final closing = TextEditingController(text: fmtNum(widget.record['closing_meter']));
  late final fuel = TextEditingController(text: _s(widget.record['fuel_liters']));
  late final operator = TextEditingController(text: widget.record['operator_name']?.toString() ?? '');
  late final work = TextEditingController(text: widget.record['work_description']?.toString() ?? '');
  late final downtime = TextEditingController(text: _s(widget.record['downtime_hours']));
  late final remarks = TextEditingController(text: widget.record['remarks']?.toString() ?? '');
  final reason = TextEditingController();
  bool saving = false;

  static String _s(dynamic v) => v == null ? '' : fmtNum(v);

  Future<void> save() async {
    final o = double.tryParse(opening.text);
    final c = double.tryParse(closing.text);
    if (o == null || c == null || c < o) {
      snack(context, 'Enter valid meter readings (closing ≥ opening).');
      return;
    }
    if (reason.text.trim().isEmpty) {
      snack(context, 'Please enter the reason for this edit.');
      return;
    }
    setState(() => saving = true);
    try {
      await supabase.rpc('admin_edit_record', params: {
        'p_id': widget.record['id'],
        'p_opening': o,
        'p_closing': c,
        'p_fuel': fuel.text.trim().isEmpty ? null : double.tryParse(fuel.text),
        'p_operator': operator.text.trim(),
        'p_work': work.text.trim(),
        'p_downtime':
            downtime.text.trim().isEmpty ? null : double.tryParse(downtime.text),
        'p_remarks': remarks.text.trim(),
        'p_reason': reason.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget f(TextEditingController c, String label, {bool num = false, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: lines,
          keyboardType: num ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit Record')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          f(opening, 'Opening meter', num: true),
          f(closing, 'Closing meter', num: true),
          f(fuel, 'Fuel (litres)', num: true),
          f(operator, 'Operator name'),
          f(work, 'Work performed', lines: 3),
          f(downtime, 'Downtime (hours)', num: true),
          f(remarks, 'Remarks', lines: 3),
          f(reason, 'Reason for edit (required)', lines: 2),
          FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving...' : 'Save changes')),
        ]),
      );
}

// ---------------------------------------------------------------- master data

class MasterDataPage extends StatefulWidget {
  final bool machines;
  const MasterDataPage({super.key, required this.machines});
  @override
  State<MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterDataPageState extends State<MasterDataPage> {
  String get table => widget.machines ? 'machines' : 'sites';

  Future<List<Map<String, dynamic>>> getRows() async =>
      List<Map<String, dynamic>>.from(
          await supabase.from(table).select().order('name'));

  Future<void> add() async {
    final a = TextEditingController(), b = TextEditingController(), c = TextEditingController();
    final m = widget.machines;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m ? 'Add machine' : 'Add site'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: a, decoration: InputDecoration(labelText: m ? 'Code (e.g. JCB-001)' : 'Site name')),
            TextField(controller: b, decoration: InputDecoration(labelText: m ? 'Name' : 'Customer name')),
            TextField(controller: c, decoration: InputDecoration(labelText: m ? 'Model' : 'Address')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    if (a.text.trim().isEmpty || (m && b.text.trim().isEmpty)) {
      if (mounted) snack(context, 'Required fields missing.');
      return;
    }
    try {
      await supabase.from(table).insert(m
          ? {'code': a.text.trim(), 'name': b.text.trim(), 'model': c.text.trim()}
          : {'name': a.text.trim(), 'customer_name': b.text.trim(), 'address': c.text.trim()});
      setState(() {});
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.machines ? 'Machines' : 'Sites')),
        floatingActionButton:
            FloatingActionButton(onPressed: add, child: const Icon(Icons.add)),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: getRows(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text(errText(snap.error!)));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snap.data!;
            if (rows.isEmpty) return const Center(child: Text('Nothing added yet. Tap +'));
            return ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                return SwitchListTile(
                  title: Text(widget.machines ? '${r['name']} (${r['code']})' : r['name']),
                  subtitle: Text(widget.machines
                      ? (r['model'] ?? '').toString()
                      : (r['customer_name'] ?? '').toString()),
                  value: r['active'] == true,
                  onChanged: (v) async {
                    try {
                      await supabase.from(table).update({'active': v}).eq('id', r['id']);
                      setState(() {});
                    } catch (e) {
                      if (context.mounted) snack(context, errText(e));
                    }
                  },
                );
              },
            );
          },
        ),
      );
}
