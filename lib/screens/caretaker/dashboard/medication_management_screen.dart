import 'package:flutter/material.dart';
import '../../../theme/caretaker_theme.dart';
import '../../elderly/medication/AddMedicationScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class MedicationManagementScreen extends StatefulWidget {
  final String? userId;

  const MedicationManagementScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<MedicationManagementScreen> createState() =>
      _MedicationManagementScreenState();
}

class _MedicationManagementScreenState
    extends State<MedicationManagementScreen> {
  bool _isMonthlyReport = false;
  late Stream<QuerySnapshot> _medicationsStream;

  @override
  void initState() {
    super.initState();
    _medicationsStream = _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('medications')
        .snapshots();
  }

  TimeOfDay? _parse12hTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.isEmpty) return null;
      final hm = parts[0].split(':');
      if (hm.length < 2) return null;
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

  // ─── Add medicine ────────────────────────────────────────────────────────
  void _addMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(userId: widget.userId ?? 'Unknown'),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Medicine added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Edit medicine ───────────────────────────────────────────────────────
  void _editMedicine(String docId, Map<String, dynamic> med) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddMedicationScreen(
              userId: widget.userId ?? 'Unknown',
              existingMedication: med,
              existingDocId: docId,
            ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✏️ ${med['name']} updated!'),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Delete medicine ─────────────────────────────────────────────────────
  void _deleteMedicine(String docId, String medName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red.shade700, size: 32),
              const SizedBox(width: 12),
              const Text('Delete Medicine'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete $medName?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _firestore
                    .collection('users')
                    .doc(widget.userId)
                    .collection('medications')
                    .doc(docId)
                    .delete();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ $medName deleted'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Toggle taken ────────────────────────────────────────────────────────
  Future<void> _toggleTaken(String docId, bool isTakenToday, int timeIndex) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (isTakenToday) {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('medications')
          .doc(docId)
          .update({
            'takenDates': FieldValue.arrayRemove([dateStr, '${dateStr}_$timeIndex']),
            'takenToday': false, // Legacy
            'status': 'upcoming',
          });
    } else {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('medications')
          .doc(docId)
          .update({
            'takenDates': FieldValue.arrayUnion([dateStr, '${dateStr}_$timeIndex']),
            'takenToday': true, // Legacy
            'lastTaken': FieldValue.serverTimestamp(),
            'status': 'taken',
          });
    }
  }


  // ─── Build UI ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.userId == null || widget.userId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Medication'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: Text('No user linked.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Medication',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.teal,
              size: 28,
            ),
            onPressed: _addMedicine,
            tooltip: 'Add Medicine',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _medicationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          
          final dayName = DateFormat('EEEE').format(DateTime.now());
          List<Map<String, dynamic>> flatListToday = [];
          for (var doc in docs) {
            final med = doc.data() as Map<String, dynamic>;
            final days = (med['days'] == null) ? '' : (med['days'] is List ? med['days'].join(', ') : med['days'].toString()).toLowerCase();
            
            if (days.contains('daily') || days.contains(dayName.toLowerCase())) {
              final times = med['times'] as List<dynamic>?;
              if (times != null && times.isNotEmpty) {
                for (var i = 0; i < times.length; i++) {
                  flatListToday.add({
                    'docId': doc.id,
                    'data': med,
                    'timeStr': times[i].toString(),
                    'timeIndex': i,
                  });
                }
              } else {
                flatListToday.add({
                  'docId': doc.id,
                  'data': med,
                  'timeStr': (med['time'] as String?) ?? '',
                  'timeIndex': 0,
                });
              }
            }
          }
          
          flatListToday.sort((a, b) {
            final tA = _parse12hTime(a['timeStr']);
            final tB = _parse12hTime(b['timeStr']);
            if (tA == null || tB == null) return 0;
            if (tA.hour != tB.hour) return tA.hour.compareTo(tB.hour);
            return tA.minute.compareTo(tB.minute);
          });

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Progress ──────────────────────────────────────────
                  _buildProgressSection(flatListToday),

                  const SizedBox(height: 24),


                  // ── Today's schedule ──────────────────────────────────
                  _buildScheduleSection(flatListToday),

                  const SizedBox(height: 32),

                  // ── Weekly adherence ──────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            const Text(
                              'Adherence Analytics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                ),
                                child: ToggleButtons(
                                    constraints: const BoxConstraints(minHeight: 32, minWidth: 70),
                                    borderRadius: BorderRadius.circular(20),
                                    fillColor: Colors.teal.shade100,
                                    selectedColor: Colors.teal.shade900,
                                    color: Colors.grey.shade700,
                                    isSelected: [!_isMonthlyReport, _isMonthlyReport],
                                    onPressed: (index) {
                                        setState(() {
                                            _isMonthlyReport = index == 1;
                                        });
                                    },
                                    children: const [
                                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Weekly', style: TextStyle(fontSize: 13))),
                                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Monthly', style: TextStyle(fontSize: 13))),
                                    ],
                                )
                            )
                        ]
                    ),
                    const SizedBox(height: 16),
                    _buildAdherenceReport(docs, isMonthly: _isMonthlyReport),
                  ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedicine,
        backgroundColor: Colors.teal,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Medicine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── Progress section ─────────────────────────────────────────────────────
  Widget _buildProgressSection(List<Map<String, dynamic>> flatList) {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    int taken = 0;
    for (var item in flatList) {
      final med = item['data'] as Map<String, dynamic>;
      final timeIndex = item['timeIndex'] as int;
      final takenDates = med['takenDates'] as List<dynamic>? ?? [];
      final legacyTaken = (timeIndex == 0) && (takenDates.contains(dateStr) || (med['takenToday'] == true && dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now())));
      if (takenDates.contains('${dateStr}_$timeIndex') || legacyTaken) {
        taken++;
      }
    }
    final total = flatList.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today\'s Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              total == 0 ? 'No medicines' : '$taken of $total taken',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : taken / total,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade400),
          ),
        ),
      ],
    );
  }


  // ─── Schedule section ─────────────────────────────────────────────────────
  Widget _buildScheduleSection(List<Map<String, dynamic>> flatList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Schedule',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        if (flatList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No medications added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "+ Add Medicine" to get started',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: flatList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = flatList[index];
              return _buildMedicationCard(item['docId'], item['data'], item['timeStr'], item['timeIndex']);
            },
          ),
      ],
    );
  }

  // ─── Medication card ──────────────────────────────────────────────────────
  Widget _buildMedicationCard(String docId, Map<String, dynamic> med, String time, int timeIndex) {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final takenDates = med['takenDates'] as List<dynamic>? ?? [];
    
    final legacyTaken = (timeIndex == 0) && (takenDates.contains(dateStr) || (med['takenToday'] == true && dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now())));
    final isTaken = takenDates.contains('${dateStr}_$timeIndex') || legacyTaken;
    
    bool isOverdue = false;
    if (!isTaken) {
      final now = TimeOfDay.now();
      final t = _parse12hTime(time);
      if (t != null && (now.hour > t.hour || (now.hour == t.hour && now.minute > t.minute + 30))) {
        isOverdue = true;
      }
    }

    Color statusColor = Colors.grey;
    Color bgColor = Colors.grey.shade50;
    Widget statusIcon = const Icon(
      Icons.radio_button_unchecked,
      color: Colors.grey,
    );
    String statusText = 'Upcoming';

    if (isTaken) {
      statusColor = Colors.green;
      bgColor = Colors.green.shade50;
      statusIcon = Icon(Icons.check_circle, color: Colors.green.shade700);
      statusText = 'Taken';
    } else if (isOverdue) {
      statusColor = Colors.red;
      bgColor = Colors.red.shade50;
      statusIcon = Icon(Icons.cancel, color: Colors.red.shade700);
      statusText = 'Overdue';
    }

    final note = med['note'] as String? ?? '';

    return GestureDetector(
      onLongPress: () => _showMedicationOptions(docId, med),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
              children: [
                // Toggle taken on tap
                GestureDetector(
                  onTap: () => _toggleTaken(docId, isTaken, timeIndex),
                  child: statusIcon,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${med['name'] ?? ''} ${med['dose'] ?? ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          decoration:
                              isTaken ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if ((med['doctorName'] as String? ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Prescribed by: ${med['doctorName']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      onPressed: () => _editMedicine(docId, med),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      onPressed:
                          () => _deleteMedicine(docId, med['name'] ?? ''),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete',
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Food timing note
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 48),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 14,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Long press options ───────────────────────────────────────────────────
  void _showMedicationOptions(String docId, Map<String, dynamic> med) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                med['name'] ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.edit, color: Colors.blue.shade700),
                title: const Text('Edit Medicine'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMedicine(docId, med);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade700),
                title: const Text('Delete Medicine'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMedicine(docId, med['name'] ?? '');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ─── Weekly adherence ─────────────────────────────────────────────────────
  Widget _buildAdherenceReport(List<QueryDocumentSnapshot> docs, {bool isMonthly = false}) {
    int daysToAnalyze = isMonthly ? 30 : 7;
    int totalPillsPastDays = 0;
    int missedPillsPastDays = 0;
    
    int todayMissed = 0;
    int todayTotal = 0;
    
    Map<String, int> medicineMissedCount = {};
    List<Map<String, String>> missedHistory = []; // Tracks { 'name': 'Aspirin', 'date': '2026-03-10', 'time': '8:00 AM' }
    bool thresholdBreached = false;

    final now = DateTime.now();
    
    // We analyze past N days tracking up to today.
    for (int i = 0; i < daysToAnalyze; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final dayName = DateFormat('EEEE').format(date).toLowerCase();
        
        for (var doc in docs) {
            final med = doc.data() as Map<String, dynamic>;
            final medName = med['name'] as String? ?? 'Unknown';
            
            // Check if created after this date, if so, skip counting it for this past date
            final createdAtTimestamp = med['createdAt'] as Timestamp?;
            final createdAt = createdAtTimestamp?.toDate() ?? DateTime(1970);
            final createdDateStr = DateFormat('yyyy-MM-dd').format(createdAt);
            
            // If the date we are checking (dateStr) is BEFORE the creation date (createdDateStr), skip it.
            if (dateStr.compareTo(createdDateStr) < 0) {
                continue;
            }

            final days = (med['days'] == null) ? '' : (med['days'] is List ? med['days'].join(', ') : med['days'].toString()).toLowerCase();
            
            if (days.contains('daily') || days.contains(dayName)) {
                // Determine total timings for this med
                final times = med['times'] as List<dynamic>?;
                int timesCount = (times != null && times.isNotEmpty) ? times.length : 1;

                final takenDates = med['takenDates'] as List<dynamic>? ?? [];
                final legacyDayTaken = takenDates.contains(dateStr);
                for (int tIdx = 0; tIdx < timesCount; tIdx++) {
                    final scheduleTimeStr = (times != null && times.isNotEmpty)
                        ? times[tIdx].toString()
                        : (med['time'] as String? ?? '');
                    final tObj = _parse12hTime(scheduleTimeStr);

                    // Only count today's doses once they're due (not in the future)
                    if (i == 0) {
                        final isDue = tObj == null
                            ? true
                            : (now.hour > tObj.hour ||
                                (now.hour == tObj.hour && now.minute >= tObj.minute));
                        if (!isDue) {
                            continue;
                        }
                        todayTotal++;
                    }

                    totalPillsPastDays++;

                    // Legacy takenToday only applies to today (i == 0)
                    final legacyTaken =
                        legacyDayTaken || (i == 0 && med['takenToday'] == true);
                    final isTaken =
                        takenDates.contains('${dateStr}_$tIdx') || legacyTaken;
                    
                    if (!isTaken) {
                        // If checking today, only count as missed if the time has passed
                        if (i == 0) {
                            // Check if overdue
                            if (tObj != null && (now.hour > tObj.hour || (now.hour == tObj.hour && now.minute > tObj.minute + 30))) {
                                todayMissed++;
                                missedPillsPastDays++;
                                medicineMissedCount[medName] = (medicineMissedCount[medName] ?? 0) + 1;
                                missedHistory.add({'name': medName, 'date': dateStr, 'time': scheduleTimeStr});
                            }
                        } else {
                            // Completely missed past day (and it was verified to be created on or before this day)
                            missedPillsPastDays++;
                            medicineMissedCount[medName] = (medicineMissedCount[medName] ?? 0) + 1;
                            missedHistory.add({'name': medName, 'date': dateStr, 'time': scheduleTimeStr});
                        }
                    }
                }
            }
        }
    }
    
    // Sort missed counts descending
    var sortedMissedEntryList = medicineMissedCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
        
    if (sortedMissedEntryList.isNotEmpty && sortedMissedEntryList.first.value > 3) {
        thresholdBreached = true;
    }

    double adherence = 100.0;
    if (totalPillsPastDays > 0) {
        adherence = ((totalPillsPastDays - missedPillsPastDays) / totalPillsPastDays) * 100;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (thresholdBreached) ...[
            Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                        BoxShadow(
                            color: Colors.red.shade200,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                        )
                    ]
                ),
                child: Row(
                    children: [
                        const Icon(Icons.warning, color: Colors.white, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    const Text('CRITICAL ALERT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const Text('A medication has been missed >3 times recently.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                ]
                            )
                        )
                    ]
                )
            )
        ],
        Text(
          isMonthly ? 'Monthly Adherence Report' : 'Weekly Adherence Report',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        // Summary Cards
        Row(
           children: [
               Expanded(
                   child: _buildReportCard(
                       title: isMonthly ? 'Past 30 Days' : 'Past 7 Days',
                       metrics: [
                           'Total Pills: $totalPillsPastDays',
                           'Missed: $missedPillsPastDays',
                           'Adherence: ${adherence.toStringAsFixed(1)}%'
                       ],
                       color: adherence >= 80 ? Colors.green.shade50 : Colors.red.shade50,
                       iconColor: adherence >= 80 ? Colors.green.shade700 : Colors.red.shade700,
                   )
               ),
               const SizedBox(width: 12),
               Expanded(
                   child: _buildReportCard(
                       title: 'Today',
                       metrics: [
                           'Total Pills: $todayTotal',
                           'Missed: $todayMissed',
                       ],
                       color: Colors.blue.shade50,
                       iconColor: Colors.blue.shade700,
                   )
               ),
           ]
        ),
        
        const SizedBox(height: 16),
        if (sortedMissedEntryList.isNotEmpty) ...[
            Text(
              isMonthly ? 'Frequently Missed Medications (Monthly)' : 'Frequently Missed Medications (Weekly)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...sortedMissedEntryList.map((e) {
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: e.value > 3 ? Colors.red.shade100 : (e.value > 1 ? Colors.orange.shade50 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: e.value > 3 ? Border.all(color: Colors.red.shade300) : null,
                    ),
                    child: Row(
                        children: [
                            Icon(e.value > 3 ? Icons.error : (e.value > 1 ? Icons.warning : Icons.info), color: e.value > 3 ? Colors.red.shade800 : (e.value > 1 ? Colors.orange.shade700 : Colors.grey.shade600)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                            Text('Missed ${e.value} times', style: TextStyle(fontWeight: FontWeight.bold, color: e.value > 3 ? Colors.red.shade900 : Colors.black87)),
                        ]
                    )
                );
            }).toList(),
            const SizedBox(height: 16),
        ],

        if (missedHistory.isNotEmpty) ...[
            const Text(
              'Detailed Missed History log',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: missedHistory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                        final item = missedHistory[index];
                        return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                                children: [
                                    const Icon(Icons.circle, size: 8, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    Text('${item['date']} at ${item['time']}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                ]
                            )
                        );
                    }
                )
            )
        ]
      ],
    );
  }

  Widget _buildReportCard({required String title, required List<String> metrics, required Color color, required Color iconColor}) {
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                      children: [
                          Icon(Icons.bar_chart, color: iconColor, size: 20),
                          const SizedBox(width: 8),
                          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
                      ]
                  ),
                  const SizedBox(height: 12),
                  ...metrics.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(m, style: const TextStyle(fontSize: 14)),
                  )).toList()
              ]
          )
      );
  }
}
