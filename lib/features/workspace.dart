import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app/theme.dart';
import '../core/surfaces.dart';
import 'records.dart';

const demo = [
  [
    ['Paracetamol 500 mg', 'Tablet', 'Dawa Distributors', '240', '2028-08-30'],
    ['Amoxicillin 250 mg', 'Capsule', 'MedSupply Tanzania', '18', '2028-05-10'],
    ['ORS Sachets', 'Sachet', 'Dawa Distributors', '86', '2028-10-15'],
    ['Vitamin C 1000 mg', 'Tablet', 'Afya Wholesale', '9', '2028-07-12'],
  ],
  [['Amina M.', '+255 700 000 001', 'Sample returning client']],
  [['Dawa Distributors', 'Dar es Salaam', '+255 700 000 011']],
  <List<String>>[],
];
const icons = [Icons.medication_outlined, Icons.people_outline, Icons.local_shipping_outlined, Icons.notifications_outlined];

class Workspace extends StatefulWidget {
  const Workspace({super.key});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with WidgetsBindingObserver {
  final prefs = SharedPreferencesAsync();
  final notifications = FlutterLocalNotificationsPlugin();
  late List<List<PharmacyRecord>> records;
  int nextId = 1, section = 0;
  bool ready = false, unlocked = kIsWeb, busy = false, notificationsReady = false;
  String query = '';
  DateTime? away;
  bool get android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && unlocked) away = DateTime.now();
    if (state == AppLifecycleState.resumed && away != null) {
      if (!kIsWeb && DateTime.now().difference(away!) > const Duration(minutes: 2)) {
        lock();
      }
      away = null;
    }
  }

  void lock() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() { unlocked = false; query = ''; });
  }

  Future<void> load() async {
    try {
      final raw = await prefs.getString('altra_flutter_records');
      if (raw == null) {
        records = demo.map((rows) => rows.map((v) => PharmacyRecord(nextId++, v)).toList()).toList();
      } else {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        records = (saved['sections'] as List).map((rows) => (rows as List).map(
          (r) => PharmacyRecord.fromJson(r as Map<String, dynamic>),
        ).toList()).toList();
        nextId = saved['nextId'] as int;
      }
    } catch (_) {
      if (mounted) setState(() => loadFailed = true);
      return;
    }
    if (android) {
      try {
        await notifications.initialize(const InitializationSettings(android: AndroidInitializationSettings('altra_notification')));
        notificationsReady = true;
      } catch (_) { notificationsReady = false; }
    }
    if (mounted) setState(() => ready = true);
  }

  bool loadFailed = false;

  Future<void> unlock() async {
    if (busy) return;
    if (kIsWeb) { setState(() => unlocked = true); return; }
    setState(() => busy = true);
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock your Altra Pharmacy workspace',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (mounted && ok) setState(() => unlocked = true);
    } catch (_) {
      message('Set up your phone’s PIN, pattern, password or fingerprint in Android Settings.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> commit(int group, List<PharmacyRecord> rows, int id) async {
    if (busy || !unlocked) return false;
    setState(() => busy = true);
    final revised = [...records];
    revised[group] = rows;
    try {
      await prefs.setString('altra_flutter_records', jsonEncode({'sections': revised, 'nextId': id}));
      if (mounted) setState(() { records = revised; nextId = id; });
      return true;
    } catch (_) {
      message('Could not save changes to this device.');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> schedule(PharmacyRecord row) async {
    if (!android || !notificationsReady) return;
    try {
      await notifications.cancel(row.id);
      final parts = row.values[1].split('-').map(int.parse).toList();
      final location = tz.getLocation('Africa/Dar_es_Salaam');
      final time = tz.TZDateTime(location, parts[0], parts[1], parts[2], 9);
      if (!time.isAfter(tz.TZDateTime.now(location))) return;
      await notifications.zonedSchedule(
        row.id, 'Altra Pharmacy reminder', 'Unlock Altra to view your reminders.', time,
        const NotificationDetails(android: AndroidNotificationDetails('altra_reminders', 'Pharmacy reminders')),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) { message('Saved, but Android could not schedule the notification.'); }
  }

  Future<void> enableNotifications() async {
    if (!notificationsReady) { message('Android notifications are unavailable.'); return; }
    try {
      final plugin = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (await plugin?.requestNotificationsPermission() == false) {
        message('Allow notifications in Android Settings to receive alerts.');
        return;
      }
      for (final record in records[3]) { await schedule(record); }
      message('Future reminders are scheduled for around 9 a.m. Tanzania time.');
    } catch (_) { message('Check notification permissions in Android Settings.'); }
  }

  Future<void> importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withReadStream: true);
      if (result == null || !mounted || !unlocked) return;
      final file = result.files.single;
      if (file.size > 1024 * 1024 || file.readStream == null) throw const FormatException('Choose a CSV file under 1 MB.');
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readStream!) {
        if (bytes.length + chunk.length > 1024 * 1024) throw const FormatException('Choose a CSV file under 1 MB.');
        bytes.add(chunk);
      }
      final parsed = parseMedicines(utf8.decode(bytes.takeBytes()));
      if (!mounted || !unlocked) return;
      final accept = await confirm('Import medicines?', '${parsed.length} new records will be added. Existing stock will not be changed.', 'Import');
      if (accept != true || !mounted || !unlocked) return;
      var id = nextId;
      final imported = parsed.map((values) => PharmacyRecord(id++, values)).toList();
      if (await commit(0, [...records[0], ...imported], id)) message('${imported.length} medicines imported.');
    } on FormatException catch (error) { message(error.message); }
    catch (_) { message('Could not read the selected CSV.'); }
  }

  Future<bool?> confirm(String title, String body, String action) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(title: Text(title), content: Text(body), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
    ]),
  );

  Future<void> edit(PharmacyRecord? previous) async {
    final group = section;
    final result = await showModalBottomSheet<PharmacyRecord>(
      context: context, isScrollControlled: true, showDragHandle: true, useSafeArea: true,
      builder: (_) => RecordEditor(section: group, record: previous, nextId: nextId),
    );
    if (!mounted || result == null || !unlocked) return;
    final rows = [...records[group]];
    if (result.id == -1 && previous != null) {
      rows.removeWhere((row) => row.id == previous.id);
      if (await commit(group, rows, nextId) && group == 3 && notificationsReady) {
        try { await notifications.cancel(previous.id); } catch (_) { message('Could not cancel the Android notification.'); }
      }
    } else {
      if (previous == null) { rows.add(result); }
      else { rows[rows.indexOf(previous)] = result; }
      if (await commit(group, rows, previous == null ? nextId + 1 : nextId) && group == 3) await schedule(result);
    }
  }

  String details(PharmacyRecord row) {
    final v = row.values;
    if (section != 0) return '${v[1]} · ${v[2]}';
    final stock = int.parse(v[3]);
    final status = v[4].compareTo(todayInTanzania()) < 0 ? 'Expired' : stock == 0 ? 'Out of stock' : stock < 20 ? 'Low stock' : 'In stock';
    return '$stock units · $status\nExpires ${v[4]} · ${v[2]}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Altra Pharmacy'), actions: [
      if (ready && unlocked) IconButton(onPressed: lock, icon: const Icon(Icons.lock_outline), tooltip: 'Lock workspace'),
    ]),
    bottomNavigationBar: ready && unlocked ? NavigationBar(
      selectedIndex: section,
      onDestinationSelected: (value) => setState(() { section = value; query = ''; }),
      destinations: [for (var i = 0; i < sections.length; i++) NavigationDestination(icon: Icon(icons[i]), label: sections[i])],
    ) : null,
    body: Stack(children: [
      const Positioned.fill(child: AmbientMintBackdrop()),
      if (!ready) Center(child: loadFailed ? const Text('Could not read local records. Restart and try again.') : const CircularProgressIndicator())
      else SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: ListView(
        key: ValueKey(unlocked ? section : -1), padding: const EdgeInsets.all(20), children: [
          Reveal(child: GlassSurface(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DAR ES SALAAM  /  PHARMACY WORKSPACE', style: AppTypography.caption),
              const SizedBox(height: 10),
              Text(unlocked ? sections[section] : 'Karibu, Altra team!', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(unlocked ? '${records[section].length} records · Stored on this device' : 'Unlock with your phone’s screen lock. Demo data only.'),
              if (!unlocked) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: busy ? null : unlock, icon: const Icon(Icons.lock_open), label: Text(kIsWeb ? 'Open browser demo' : 'Unlock workspace'))],
            ],
          ))),
          if (unlocked) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: busy ? null : () => edit(null), icon: const Icon(Icons.add), label: Text(['Add medicine', 'Add client', 'Add supplier', 'Add reminder'][section])),
              if (section == 0) OutlinedButton.icon(onPressed: busy ? null : importCsv, icon: const Icon(Icons.upload_file), label: const Text('Import CSV')),
              if (section == 3 && android) OutlinedButton.icon(onPressed: enableNotifications, icon: const Icon(Icons.notifications_active_outlined), label: const Text('Enable alerts')),
            ]),
            const SizedBox(height: 10),
            TextField(onChanged: (value) => setState(() => query = value.trim().toLowerCase()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search records', filled: true)),
            const SizedBox(height: 12),
            if (!records[section].any(matches)) const Padding(padding: EdgeInsets.all(12), child: Text('No matching records.')),
            for (final row in records[section].where(matches)) Padding(
              key: ValueKey(row.id), padding: const EdgeInsets.only(bottom: 9), child: SpringScaleTap(
                label: 'Edit ${row.values.first}', onTap: () { if (!busy) edit(row); }, child: GlassSurface(radius: 18, child: ListTile(
                  leading: row.photo == null ? Icon(icons[section], color: AppColors.auraMintDeep) : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(row.photo!), width: 44, height: 44, fit: BoxFit.cover)),
                  title: Text(row.values.first), subtitle: Text(details(row)), trailing: const Icon(Icons.arrow_outward, size: 18),
                )),
              ),
            ),
          ],
        ],
      )))),
    ]),
  );
  bool matches(PharmacyRecord row) => row.values.any((value) => value.toLowerCase().contains(query));
}

class RecordEditor extends StatefulWidget {
  const RecordEditor({super.key, required this.section, required this.record, required this.nextId});
  final int section, nextId;
  final PharmacyRecord? record;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  late final controllers = [for (var i = 0; i < fields[widget.section].length; i++) TextEditingController(text: widget.record?.values[i])];
  late String? photo = widget.record?.photo;
  String? error;
  bool selecting = false;
  @override
  void dispose() { for (final controller in controllers) { controller.dispose(); } super.dispose(); }

  Future<void> picture(ImageSource source) async {
    setState(() => selecting = true);
    try {
      final image = await ImagePicker().pickImage(source: source, maxWidth: 640, maxHeight: 640, imageQuality: 72);
      if (image == null) return;
      if (await image.length() > 500 * 1024) throw const FormatException('Choose a photo smaller than 500 KB.');
      final encoded = base64Encode(await image.readAsBytes());
      if (mounted) setState(() { photo = encoded; error = null; });
    } on FormatException catch (e) { if (mounted) setState(() => error = e.message); }
    catch (_) { if (mounted) setState(() => error = 'Could not access the selected photo or camera.'); }
    finally { if (mounted) setState(() => selecting = false); }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.record == null ? 'New record' : 'Edit record', style: AppTypography.title),
      for (var i = 0; i < controllers.length; i++) Padding(
        padding: const EdgeInsets.only(top: 10), child: TextField(
          controller: controllers[i],
          keyboardType: fields[widget.section][i] == 'Stock' ? TextInputType.number : null,
          decoration: InputDecoration(filled: true, labelText: fields[widget.section][i], hintText: ['Due', 'Expiry'].contains(fields[widget.section][i]) ? 'YYYY-MM-DD' : null),
        ),
      ),
      if (widget.section == 0) ...[
        if (photo != null) Padding(padding: const EdgeInsets.only(top: 10), child: Image.memory(base64Decode(photo!), height: 90)),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: selecting ? null : () => picture(ImageSource.gallery), child: const Text('Choose photo')),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) TextButton(onPressed: selecting ? null : () => picture(ImageSource.camera), child: const Text('Take photo')),
          if (photo != null) TextButton(onPressed: selecting ? null : () => setState(() => photo = null), child: const Text('Remove photo')),
        ]),
      ],
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 8),
      FilledButton(onPressed: selecting ? null : () {
        final values = controllers.map((c) => c.text.trim()).toList();
        final issue = validateRecord(widget.section, values);
        if (issue != null) { setState(() => error = issue); return; }
        Navigator.pop(context, PharmacyRecord(widget.record?.id ?? widget.nextId, values, photo));
      }, child: const Text('Save record')),
      if (widget.record != null) TextButton(onPressed: selecting ? null : () async {
        final action = widget.section == 3 ? 'Complete reminder' : 'Delete record';
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('$action?'), actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ]));
        if (context.mounted && ok == true) Navigator.pop(context, PharmacyRecord(-1, []));
      }, child: Text(widget.section == 3 ? 'Mark complete' : 'Delete record')),
    ]),
  );
}
