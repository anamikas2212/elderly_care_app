import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'medication_history_screen.dart';
import 'AddMedicationScreen.dart';
import '../../../services/notification_service.dart';
import '../../../services/user_id_helper.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

enum UserRole { elderly, caretaker }

class MedicationListScreen extends StatefulWidget {
  final String userId;
  final UserRole role;
  const MedicationListScreen({
    Key? key,
    required this.userId,
    required this.role,
  }) : super(key: key);
  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  DateTime _selectedDate = DateTime.now();
  Stream<QuerySnapshot>? _medicationsStream;
  late String _effectiveUserId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  Future<void> _initializeStreams() async {
    _effectiveUserId = widget.userId;
    if (widget.role == UserRole.elderly) {
      final resolvedUserId = await UserIdHelper.getCurrentUserId();
      if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
        _effectiveUserId = resolvedUserId;
      }
    }

    _medicationsStream =
        _firestore
            .collection('users')
            .doc(_effectiveUserId)
            .collection('medications')
            .snapshots();
    if (!mounted) return;
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _userId => _effectiveUserId;

  Future<void> _scheduleNotification(
    String docId,
    Map<String, dynamic> med,
  ) async {
    if (kIsWeb) return;

    final daysStr = _safeStringOrList(med['days']).toLowerCase();
    final times = med['times'] as List<dynamic>?;
    if (times != null && times.isNotEmpty) {
      for (var i = 0; i < times.length; i++) {
        _scheduleSingleNotification(
          docId,
          med,
          times[i].toString(),
          i,
          daysStr,
        );
      }
    } else {
      _scheduleSingleNotification(
        docId,
        med,
        _safeString(med['time']),
        0,
        daysStr,
      );
    }
  }

  Future<void> _scheduleSingleNotification(
    String docId,
    Map<String, dynamic> med,
    String timeStr,
    int timeIndex,
    String daysStr,
  ) async {
    final t = _parse12hTime(timeStr);
    if (t == null) return;

    final name = _safeString(med['name']);
    final dose = _safeString(med['dose']);

    // Daily schedule: repeat every day at time.
    if (daysStr.isEmpty || daysStr.contains('daily')) {
      final notifId = '${docId}_${timeIndex}_daily'.hashCode.abs() % 100000;
      await NotificationService.instance.scheduleMedication(
        id: notifId,
        userId: _userId,
        docId: docId,
        name: name,
        dose: dose,
        hour: t.hour,
        minute: t.minute,
        timeIndex: timeIndex,
        matchComponents: DateTimeComponents.time,
      );
      return;
    }

    // Weekly schedule: repeat on selected weekdays.
    final weekdays = _parseDaysToWeekdays(daysStr);
    for (final wd in weekdays) {
      final notifId = '${docId}_${timeIndex}_$wd'.hashCode.abs() % 100000;
      await NotificationService.instance.scheduleMedication(
        id: notifId,
        userId: _userId,
        docId: docId,
        name: name,
        dose: dose,
        hour: t.hour,
        minute: t.minute,
        timeIndex: timeIndex,
        weekday: wd,
        matchComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _scheduleAllNotifications() async {
    if (kIsWeb) return;
    final snapshot =
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('medications')
            .get();
    for (final doc in snapshot.docs) {
      _scheduleNotification(doc.id, doc.data() as Map<String, dynamic>);
    }
  }

  Future<void> _snoozeNotif(String docId, Map<String, dynamic> med) async {
    if (kIsWeb) return;
    final now = DateTime.now().add(const Duration(minutes: 10));
    await NotificationService.instance.scheduleMedication(
      id: docId.hashCode.abs() % 100000,
      userId: _userId,
      docId: docId,
      name: _safeString(med['name']),
      dose: _safeString(med['dose']),
      hour: now.hour,
      minute: now.minute,
      scheduledDate: tz.TZDateTime.from(now, tz.local),
      matchComponents: null,
    );
  }

  Future<void> _cancelNotif(String docId) async {
    if (kIsWeb) return;
    // The current NotificationService does not expose a raw cancel method,
    // but typically you'd cancel it here.
  }

  Future<void> _markAsTaken(String docId, String name, int timeIndex) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('medications')
          .doc(docId)
          .update({
            'lastTaken': Timestamp.fromDate(DateTime.now()),
            'takenToday': true, // Legacy
            'takenDates': FieldValue.arrayUnion([
              dateStr,
              '${dateStr}_$timeIndex',
            ]),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $name marked as taken'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error marking as taken: $e');
    }
  }

  Future<void> _snoozeMedication(String docId, Map<String, dynamic> med) async {
    final name = _safeString(med['name']);
    await _snoozeNotif(docId, med);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏰ $name snoozed for 10 minutes'),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _deleteMedication(String docId, String name) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              '🗑️ Delete Medication',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete $name?',
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 18)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _cancelNotif(docId);
                  await _firestore
                      .collection('users')
                      .doc(_userId)
                      .collection('medications')
                      .doc(docId)
                      .delete();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🗑️ $name deleted'),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  'Delete',
                  style: TextStyle(fontSize: 18, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _navigateToAdd({
    Map<String, dynamic>? existing,
    String? docId,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddMedicationScreen(
              userId: _userId,
              existingMedication: existing,
              existingDocId: docId,
            ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? '✅ Medication added successfully!'
                : '✏️ Medication updated successfully!',
          ),
          backgroundColor:
              existing == null ? Colors.green.shade700 : Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '💊 My Medications',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.role == UserRole.elderly)
            IconButton(
              icon: const Icon(Icons.history, size: 28),
              tooltip: 'History',
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => MedicationHistoryScreen(userId: _userId),
                    ),
                  ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.role == UserRole.elderly) _buildWeeklyCalendar(),
          Expanded(child: _buildMedicationList()),
        ],
      ),
      floatingActionButton:
          widget.role == UserRole.caretaker
              ? FloatingActionButton.extended(
                onPressed: () => _navigateToAdd(),
                backgroundColor: Colors.green.shade700,
                icon: const Icon(Icons.add, size: 28),
                label: const Text(
                  'Add Medicine',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              )
              : null,
    );
  }

  Widget _buildWeeklyCalendar() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              "Weekly Schedule",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final isSelected =
                  date.day == _selectedDate.day &&
                  date.month == _selectedDate.month &&
                  date.year == _selectedDate.year;
              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Colors.green.shade700
                            : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        isSelected
                            ? null
                            : Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(date).substring(0, 1),
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isSelected ? Colors.white : Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationList() {
    if (_isInitializing || _medicationsStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _medicationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _buildEmptyState();

        final dayName = DateFormat('EEEE').format(_selectedDate);

        List<Map<String, dynamic>> flatList = [];
        for (var doc in snapshot.data!.docs) {
          final med = doc.data() as Map<String, dynamic>;
          final days = _safeStringOrList(med['days']).toLowerCase();

          if (days.contains('daily') || days.contains(dayName.toLowerCase())) {
            final times = med['times'] as List<dynamic>?;
            if (times != null && times.isNotEmpty) {
              for (var i = 0; i < times.length; i++) {
                flatList.add({
                  'docId': doc.id,
                  'data': med,
                  'timeStr': times[i].toString(),
                  'timeIndex': i,
                });
              }
            } else {
              flatList.add({
                'docId': doc.id,
                'data': med,
                'timeStr': _safeString(med['time']),
                'timeIndex': 0,
              });
            }
          }
        }

        flatList.sort((a, b) {
          final timeA = _parse12hTime(a['timeStr'] as String);
          final timeB = _parse12hTime(b['timeStr'] as String);
          if (timeA == null || timeB == null) return 0;
          if (timeA.hour != timeB.hour) return timeA.hour.compareTo(timeB.hour);
          return timeA.minute.compareTo(timeB.minute);
        });

        if (flatList.isEmpty) {
          return Center(
            child: Text(
              'No medications for this day',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: flatList.length,
          itemBuilder: (context, index) {
            final item = flatList[index];
            return _buildMedicationCard(
              item['docId'],
              item['data'] as Map<String, dynamic>,
              item['timeStr'] as String,
              item['timeIndex'] as int,
              index + 1,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 120,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'No medications added yet',
            style: TextStyle(
              fontSize: 22,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.role == UserRole.caretaker)
            Text(
              'Tap the button below to add a medication',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(
    String docId,
    Map<String, dynamic> med,
    String specificTime,
    int timeIndex,
    int number,
  ) {
    final name = _safeString(med['name']);
    final dosage = _safeString(med['dose']);
    final time =
        specificTime.isNotEmpty ? specificTime : _safeString(med['time']);
    final days = _safeStringOrList(med['days']);
    final note = _safeString(med['note']);
    final doctorName = _safeString(
      med['doctorName'],
      fallback: 'Not specified',
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final takenDates = med['takenDates'] as List<dynamic>? ?? [];
    final missedDates = med['missedDates'] as List<dynamic>? ?? [];

    // Adherence logic: It's taken if the specific `${dateStr}_$timeIndex` is there, or legacy `dateStr`.
    // We check against `_selectedDate` (formatted dateStr) strictly, not `DateTime.now()` directly.
    final legacyTaken =
        (timeIndex == 0) &&
        (takenDates.contains(dateStr) ||
            (med['takenToday'] == true &&
                dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now())));
    final takenToday =
        takenDates.contains('${dateStr}_$timeIndex') || legacyTaken;

    final isMissed = missedDates.contains('${dateStr}_$timeIndex') || missedDates.contains(dateStr);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dosage.isNotEmpty)
                        Text(
                          dosage,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: takenToday
                        ? Colors.green.shade100
                        : (isMissed ? Colors.red.shade100 : Colors.orange.shade100),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    takenToday ? 'Taken' : (isMissed ? 'Missed' : 'Pending'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: takenToday
                          ? Colors.green.shade800
                          : (isMissed ? Colors.red.shade800 : Colors.orange.shade800),
                    ),
                  ),
                ),
                if (widget.role == UserRole.caretaker) ...[
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue.shade700),
                    onPressed:
                        () => _navigateToAdd(existing: med, docId: docId),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade700),
                    onPressed: () => _deleteMedication(docId, name),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _infoRow(Icons.calendar_today, 'Days:', days)),
                const SizedBox(width: 8),
                Expanded(
                  child: _infoRow(Icons.local_hospital, 'Doctor:', doctorName),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.note, 'Note:', note),
            ],
            if (widget.role == UserRole.elderly) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          takenToday
                              ? null
                              : () => _snoozeMedication(docId, med),
                      icon: const Icon(Icons.snooze),
                      label: const Text('Snooze'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          takenToday
                              ? null
                              : () => _markAsTaken(docId, name, timeIndex),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(takenToday ? 'Taken' : 'Take Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            takenToday
                                ? Colors.green.shade200
                                : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.shade200,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.green.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _safeStringOrList(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) return value.map((e) => e.toString()).join(', ');
    return value.toString();
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value.isEmpty ? fallback : value;
    return fallback;
  }

  TimeOfDay? _parse12hTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final hm = parts[0].split(':');
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
        if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  List<int> _parseDaysToWeekdays(String daysStr) {
    final out = <int>{};
    final parts =
        daysStr
            .split(RegExp(r'[,\\s]+'))
            .map((p) => p.trim().toLowerCase())
            .where((p) => p.isNotEmpty)
            .toList();

    for (final p in parts) {
      switch (p) {
        case 'mon':
        case 'monday':
          out.add(DateTime.monday);
          break;
        case 'tue':
        case 'tues':
        case 'tuesday':
          out.add(DateTime.tuesday);
          break;
        case 'wed':
        case 'wednesday':
          out.add(DateTime.wednesday);
          break;
        case 'thu':
        case 'thur':
        case 'thurs':
        case 'thursday':
          out.add(DateTime.thursday);
          break;
        case 'fri':
        case 'friday':
          out.add(DateTime.friday);
          break;
        case 'sat':
        case 'saturday':
          out.add(DateTime.saturday);
          break;
        case 'sun':
        case 'sunday':
          out.add(DateTime.sunday);
          break;
      }
    }

    return out.toList();
  }
}
