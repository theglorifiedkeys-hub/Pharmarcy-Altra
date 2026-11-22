import 'dart:async';
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
import '../core/dar_time.dart';
import '../core/lucide_icons.dart';
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

  Timer? clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    load();
  }

  @override
  void dispose() {
    clock?.cancel();
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
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
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !unlocked || section == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && unlocked && section != 0) setState(() { section = 0; query = ''; });
    },
    child: Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: AmbientMintBackdrop(center: Alignment(.5, -.02))),
        if (!ready)
          Center(child: loadFailed ? const Text('Could not read local records. Restart and try again.') : const CircularProgressIndicator())
        else
          SafeArea(
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: CustomScrollView(
              key: PageStorageKey(unlocked ? section : -1),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
                  sliver: SliverList.list(children: [
                    Reveal(child: _topRow()),
                    const SizedBox(height: 19),
                    _greeting(),
                    const SizedBox(height: 18),
                    if (unlocked) ...[
                      Reveal(delay: 90, child: _hero()),
                      const SizedBox(height: 20),
                      Reveal(delay: 135, child: _listHead()),
                      const SizedBox(height: 10),
                      _searchField(),
                      const SizedBox(height: 12),
                      if (visible.isEmpty) _empty() else ...[
                        for (final row in visible) _recordTile(row),
                        const SizedBox(height: 4),
                        Text('Tap a card to edit · saved on this device', style: AppTypography.caption.copyWith(color: AppColors.inkMuted)),
                      ],
                    ] else
                      Reveal(delay: 90, child: _lockedCard()),
                  ]),
                ),
              ],
            ))),
          ),
        if (ready && unlocked && MediaQuery.viewInsetsOf(context).bottom == 0)
          Positioned(left: 16, right: 16, bottom: 13, child: SafeArea(
            top: false,
            child: Reveal(delay: 220, child: Center(
              heightFactor: 1,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 648), child: _dock()),
            )),
          )),
      ]),
    ),
  );

  List<PharmacyRecord> get visible => records[section].where(matches).toList();

  Widget _topRow() => Row(children: [
    GlassSurface(radius: 999, blur: true, shadow: false, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(LucideIcons.mapPin, size: 15),
      const SizedBox(width: 7),
      Text('Dar es Salaam · EAT', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.label.copyWith(fontSize: 13)),
    ])),
    const Spacer(),
    SpringScaleTap(
      label: unlocked ? 'Lock workspace' : 'Unlock workspace',
      onTap: busy ? () {} : (unlocked ? lock : unlock),
      child: Container(
        width: 44, height: 44, alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: AppColors.badgeMintBg,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x14176047), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: unlocked
            ? const Text('A', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))
            : const Icon(Icons.lock_outline, size: 19),
      ),
    ),
  ]);

  Widget _greeting() {
    final time = darNow();
    final count = records[section].length;
    return Reveal(
      delay: 45,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${darDateLabel(time)} · EAT', style: AppTypography.caption.copyWith(letterSpacing: .2)),
        const SizedBox(height: 7),
        Text(
          unlocked ? '${darGreeting(time.hour)},\nAltra Pharmacy' : 'Karibu tena,\nAltra Pharmacy',
          style: const TextStyle(fontSize: 28, height: 1.12, letterSpacing: -.8, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 9),
        Text(
          unlocked
              ? '$count ${_unit(count)} · stored on this device'
              : 'Your shelf, clients and reminders stay offline. Unlock with your phone’s PIN or fingerprint.',
          style: AppTypography.caption.copyWith(height: 1.45),
        ),
      ]),
    );
  }

  Widget _hero() {
    final rows = records[section];
    final low = section == 0 ? rows.where((row) => (int.tryParse(row.values[3]) ?? 0) < 20).length : 0;
    final expiring = section == 0 ? rows.where((row) => daysUntil(row.values[4]) <= 60).length : 0;
    final body = switch (section) {
      0 => low == 0 && expiring == 0
          ? 'Stock levels look healthy today.'
          : '$low need restocking · $expiring expiring soon',
      1 => 'Every visit you save becomes a returning client you can call again.',
      2 => 'Keep your suppliers’ phone numbers close before shelves run dry.',
      _ => 'Android shows a gentle alert at 9 a.m. Dar es Salaam time.',
    };
    return GlassSurface(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icons[section], size: 17, color: AppColors.auraMintDeep),
          const SizedBox(width: 8),
          Flexible(child: Text(_heroCaption, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(
            color: AppColors.auraMintDeep, fontWeight: FontWeight.w600, letterSpacing: .7,
          ))),
        ]),
        const SizedBox(height: 12),
        Text(_heroTitle(rows.length), style: const TextStyle(fontSize: 21, height: 1.18, letterSpacing: -.6, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(body, style: AppTypography.caption.copyWith(height: 1.45)),
        const SizedBox(height: 15),
        Wrap(spacing: 8, runSpacing: 8, children: [
          PillButton('Add ${_one}', () { if (!busy) edit(null); }, icon: LucideIcons.plus, height: 44),
          if (section == 0) PillButton('Import CSV', () { if (!busy) importCsv(); }, icon: Icons.upload_file, dark: false, height: 44),
          if (section == 3 && android) PillButton('Enable alerts', enableNotifications, icon: Icons.notifications_active_outlined, dark: false, height: 44),
        ]),
      ]),
    );
  }

  String get _heroCaption => switch (section) {
    0 => 'INVENTORY · LEO',
    1 => 'RETURNING CLIENTS',
    2 => 'SUPPLIERS · DAR',
    _ => 'REMINDERS · 9 A.M. EAT',
  };

  String _heroTitle(int count) => switch (section) {
    0 => '$count ${count == 1 ? 'medicine' : 'medicines'} on the shelf',
    1 => '$count ${count == 1 ? 'client remembers' : 'clients remember'} you',
    2 => '$count ${count == 1 ? 'supply partner' : 'supply partners'}',
    _ => '$count ${count == 1 ? 'reminder' : 'reminders'} queued',
  };

  String get _one => switch (section) { 0 => 'medicine', 1 => 'client', 2 => 'supplier', _ => 'reminder' };

  String _unit(int count) => switch (section) {
    0 => count == 1 ? 'medicine' : 'medicines',
    1 => count == 1 ? 'client' : 'clients',
    2 => count == 1 ? 'supplier' : 'suppliers',
    _ => count == 1 ? 'reminder' : 'reminders',
  };

  Widget _listHead() => Row(children: [
    Text(sections[section], style: AppTypography.title),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: AppColors.badgeMintBg, borderRadius: BorderRadius.circular(99)),
      child: Text('${visible.length}', style: AppTypography.number.copyWith(
        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.auraMintDeep,
      )),
    ),
    const Spacer(),
    Text(query.isEmpty ? 'Orodha' : 'Matokeo', style: AppTypography.caption.copyWith(color: AppColors.inkMuted)),
  ]);

  Widget _searchField() => GlassSurface(
    radius: 999, blur: true, shadow: false,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      const Icon(Icons.search, size: 18, color: AppColors.inkMuted),
      const SizedBox(width: 10),
      Expanded(child: TextField(
        onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Search ${sections[section].toLowerCase()}',
          hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.inkMuted),
        ),
      )),
    ]),
  );

  Widget _empty() => GlassSurface(
    radius: 22,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    child: Column(children: [
      Icon(icons[section], size: 26, color: AppColors.inkMuted),
      const SizedBox(height: 9),
      Text(query.isEmpty ? 'Nothing here yet' : 'No matches for “$query”', textAlign: TextAlign.center, style: AppTypography.label),
      const SizedBox(height: 4),
      Text(
        query.isEmpty ? 'Use the + button below to add your first $_one.' : 'Try a different name, phone or supplier.',
        textAlign: TextAlign.center,
        style: AppTypography.caption.copyWith(height: 1.4),
      ),
    ]),
  );

  Widget _recordTile(PharmacyRecord row) => Padding(
    key: ValueKey(row.id),
    padding: const EdgeInsets.only(bottom: 9),
    child: SpringScaleTap(
      label: 'Edit ${row.values.first}',
      onTap: () { if (!busy) edit(row); },
      child: GlassSurface(
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(children: [
            Container(
              width: 42, height: 42, clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.badgeMintBg),
              child: row.photo == null
                  ? Icon(icons[section], size: 18, color: AppColors.auraMintDeep)
                  : Image.memory(base64Decode(row.photo!), fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.values.first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(details(row), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(height: 1.35)),
            ])),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.inkMuted),
          ]),
        ),
      ),
    ),
  );

  Widget _lockedCard() => GlassSurface(
    radius: 26,
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(LucideIcons.sparkles, size: 17, color: AppColors.auraMintDeep),
        const SizedBox(width: 8),
        Text('SALAMA · OFFLINE', style: AppTypography.caption.copyWith(
          color: AppColors.auraMintDeep, fontWeight: FontWeight.w600, letterSpacing: .7,
        )),
      ]),
      const SizedBox(height: 12),
      const Text('Unlock to open your shelf', style: TextStyle(fontSize: 21, height: 1.18, letterSpacing: -.6, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(
        kIsWeb ? 'Browser preview of the offline workspace with demo medicines.' : 'Altra asks for your phone’s screen lock. Nothing leaves this device.',
        style: AppTypography.caption.copyWith(height: 1.45),
      ),
      const SizedBox(height: 15),
      PillButton(
        kIsWeb ? 'Open browser demo' : 'Unlock workspace',
        busy ? () {} : unlock,
        icon: Icons.lock_open,
        height: 46,
      ),
    ]),
  );

  Widget _dock() {
    final tabs = [for (var i = 0; i < sections.length; i++) (icons[i], sections[i])];
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 300);
    return Row(children: [
      Expanded(child: GlassSurface(
        radius: 99, blur: true, padding: const EdgeInsets.all(5),
        child: LayoutBuilder(builder: (context, constraints) {
          final unit = constraints.maxWidth / 5;
          return SizedBox(height: 46, child: Stack(children: [
            AnimatedPositioned(
              duration: duration, curve: motionCurve,
              left: unit * section, width: unit * 2, top: 0, bottom: 0,
              child: const DecoratedBox(decoration: BoxDecoration(
                color: AppColors.badgeMintBg, borderRadius: BorderRadius.all(Radius.circular(99)),
              )),
            ),
            for (final (index, tab) in tabs.indexed)
              AnimatedPositioned(
                key: ValueKey(index),
                duration: duration, curve: motionCurve,
                left: unit * (index + (index > section ? 1 : 0)),
                width: unit * (index == section ? 2 : 1),
                top: 0, bottom: 0,
                child: SpringScaleTap(
                  label: tab.$2, selected: index == section,
                  onTap: () => setState(() { section = index; query = ''; }),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(tab.$1, size: 19, color: index == section ? AppColors.inkPrimary : AppColors.inkSecondary),
                    if (index == section) Flexible(child: Reveal(child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Text(tab.$2, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ))),
                  ]),
                ),
              ),
          ]));
        }),
      )),
      const SizedBox(width: 9),
      RepaintBoundary(child: SpringScaleTap(
        label: 'Add $_one',
        onTap: busy ? () {} : () => edit(null),
        child: Container(
          width: 56, height: 56, alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            gradient: const RadialGradient(
              center: Alignment(-.4, -.55),
              colors: [Color(0xffe8fff1), Color(0xffa9e6c4), Color(0xff4fb98a)],
            ),
            boxShadow: const [BoxShadow(color: Color(0x40176047), blurRadius: 16, offset: Offset(0, 4))],
          ),
          child: const Icon(LucideIcons.plus, size: 24, color: AppColors.inkPrimary),
        ),
      )),
    ]);
  }

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
