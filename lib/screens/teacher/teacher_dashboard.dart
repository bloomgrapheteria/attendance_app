import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'mark_attendance_page.dart';
import 'create_leave_page.dart';
import '../principal/approve_leave_page.dart';
import '/login_page.dart';
import 'my_class_students_page.dart';
import '/services/auth_service.dart';
import '../admin/admin_dashboard.dart'; // ← shared AppTheme + WarliAppBar + WarliButton + WarliField

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});
  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String? _displayName;
  String? _classId;
  bool _loadingName = true;
  bool _showOnlyTodayLeaves = true;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _loadingName = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final name = doc.data()?['name'] as String?;
      final classId = doc.data()?['classId'] as String?;
      setState(() {
        _displayName = (name != null && name.isNotEmpty) ? name : (user.displayName ?? 'Teacher');
        _classId = classId;
        _loadingName = false;
      });
    } catch (_) {
      setState(() { _displayName = user.displayName ?? 'Teacher'; _loadingName = false; });
    }
  }

  String get _todayDate {
    final n = DateTime.now();
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days   = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return "${days[n.weekday]}, ${n.day} ${months[n.month]} ${n.year}";
  }

  // ── Bottom sheet to edit display name ───────────────────────
  void _showEditNameSheet() {
    final controller = TextEditingController(text: _displayName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text("Edit Your Name",
                  style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text("This name appears on your dashboard.",
                  style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 13)),
              const SizedBox(height: 20),
              WarliField(controller: controller, label: "Your Name", icon: Icons.person_outline_rounded),
              const SizedBox(height: 20),
              WarliButton(
                label: "Save Name",
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) return;
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  await user.updateDisplayName(newName);
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({'name': newName}, SetOptions(merge: true));
                  setState(() => _displayName = newName);
                  if (mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: currentUser != null
                ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots()
                : null,
            builder: (context, userSnapshot) {
              if (userSnapshot.hasData && userSnapshot.data != null) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData != null) {
                  _displayName = userData['name'] as String?;
                  _classId = userData['classId'] as String?;
                  _loadingName = false;
                }
              }

              return Column(
                children: [
              // ── AppBar ────────────────────────────────────────
              WarliAppBar(
                title: "Teacher Dashboard",
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: currentUser != null
                          ? FirebaseFirestore.instance
                              .collection('notifications')
                              .where('teacherEmail', isEqualTo: currentUser.email)
                              .where('isRead', isEqualTo: false)
                              .snapshots()
                          : null,
                      builder: (context, unreadSnap) {
                        final hasUnread = unreadSnap.hasData && unreadSnap.data!.docs.isNotEmpty;
                        return Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_rounded, color: AppTheme.textDark, size: 22),
                              onPressed: () => _showNotificationsSheet(context),
                            ),
                            if (hasUnread)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.textDark, size: 22),
                      onPressed: () async {
                        await authService.logout();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                              (r) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Welcome card ──────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.78),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Welcome Back 👋",
                                    style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 13)),
                                const SizedBox(height: 4),
                                _loadingName
                                    ? Container(height: 24, width: 140,
                                    decoration: BoxDecoration(
                                        color: AppTheme.textDark.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6)))
                                    : Text(_displayName ?? 'Teacher',
                                    style: const TextStyle(
                                        color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 20)),
                                const SizedBox(height: 8),
                                Text(_todayDate,
                                    style: TextStyle(color: AppTheme.textDark.withOpacity(0.6), fontSize: 12)),
                              ],
                            ),
                          ),
                          // Edit name button
                          GestureDetector(
                            onTap: _showEditNameSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.textDark.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.textDark.withOpacity(0.2)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.edit_rounded, color: AppTheme.textDark, size: 14),
                                const SizedBox(width: 5),
                                Text("Edit Name",
                                    style: TextStyle(color: AppTheme.textDark, fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // ── Standing Principal Status Banner ──
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('standing_principals')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          bool isStanding = false;
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final userEmail = currentUser?.email ?? '';
                          final userUid = currentUser?.uid ?? '';
                          
                          debugPrint("Standing Principal Check: userEmail=$userEmail, userUid=$userUid, delegationsTotal=${snapshot.data!.docs.length}");
                          
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final email = data['teacherEmail'] ?? '';
                            final uid = data['teacherUid'] ?? '';
                            final startStr = data['startDate'] ?? '';
                            final endStr = data['endDate'] ?? '';
                            
                            debugPrint("  - Checking delegation: name=${data['teacherName']}, dbEmail=$email, dbUid=$uid, start=$startStr, end=$endStr");
                            
                            final matchesEmail = (email.isNotEmpty && email.toLowerCase() == userEmail.toLowerCase());
                            final matchesUid = (email.isNotEmpty && email == userUid) || (uid.isNotEmpty && uid == userUid);
                            
                            if (matchesEmail || matchesUid) {
                              final startParts = startStr.split('-');
                              final endParts = endStr.split('-');
                              if (startParts.length == 3 && endParts.length == 3) {
                                final start = DateTime(
                                  int.parse(startParts[0]),
                                  int.parse(startParts[1]),
                                  int.parse(startParts[2]),
                                );
                                final end = DateTime(
                                  int.parse(endParts[0]),
                                  int.parse(endParts[1]),
                                  int.parse(endParts[2]),
                                );
                                if ((today.isAfter(start) || today.isAtSameMomentAs(start)) &&
                                    (today.isBefore(end) || today.isAtSameMomentAs(end))) {
                                  isStanding = true;
                                  debugPrint("    -> ACTIVE DELEGATION MATCH FOUND!");
                                  break;
                                }
                              }
                            }
                          }
                          
                          if (!isStanding) return const SizedBox();
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF2E9), // Light warm peach/terra
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFD67845), width: 1.5), // Terra border
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD67845).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.gavel_rounded,
                                      color: Color(0xFFD67845),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Standing Principal Active",
                                          style: TextStyle(
                                            fontFamily: 'Georgia',
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6E432E), // WC.brown
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "You have been delegated principal authorities for today. You can now view and manage all student/teacher leave applications.",
                                          style: TextStyle(
                                            color: const Color(0xFF9E7153), // WC.brownLight
                                            fontSize: 12,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // ── Quick actions ─────────────────────────
                      WarliSectionTitle(title: "QUICK ACTIONS"),
                      const SizedBox(height: 10),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.how_to_reg_rounded,
                              title: "Mark\nAttendance",
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => const MarkAttendancePage())),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.event_note_rounded,
                              title: "Create Leave\nApplication",
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => const CreateLeavePage())),
                            ),
                          ),
                          if (_classId != null && _classId!.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.people_alt_rounded,
                                title: "My Class\nStudents",
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => MyClassStudentsPage(classId: _classId!))),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Standing Principal dynamic option ──
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('standing_principals')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          bool isStanding = false;
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final userEmail = currentUser?.email ?? '';
                          final userUid = currentUser?.uid ?? '';
                          
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final email = data['teacherEmail'] ?? '';
                            final uid = data['teacherUid'] ?? '';
                            final startStr = data['startDate'] ?? '';
                            final endStr = data['endDate'] ?? '';
                            
                            final matchesEmail = (email.isNotEmpty && email.toLowerCase() == userEmail.toLowerCase());
                            final matchesUid = (email.isNotEmpty && email == userUid) || (uid.isNotEmpty && uid == userUid);
                            
                            if (matchesEmail || matchesUid) {
                              final startParts = startStr.split('-');
                              final endParts = endStr.split('-');
                              if (startParts.length == 3 && endParts.length == 3) {
                                final start = DateTime(
                                  int.parse(startParts[0]),
                                  int.parse(startParts[1]),
                                  int.parse(startParts[2]),
                                );
                                final end = DateTime(
                                  int.parse(endParts[0]),
                                  int.parse(endParts[1]),
                                  int.parse(endParts[2]),
                                );
                                if ((today.isAfter(start) || today.isAtSameMomentAs(start)) &&
                                    (today.isBefore(end) || today.isAtSameMomentAs(end))) {
                                  isStanding = true;
                                  break;
                                }
                              }
                            }
                          }
                          
                          if (!isStanding) return const SizedBox();
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DashTile(
                              icon: Icons.assignment_ind_rounded,
                              title: "Manage Leaves (Standing Principal)",
                              subtitle: "Approve or reject leave requests as delegated principal",
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => const ApproveLeavePage())),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ── Leave History ─────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: WarliSectionTitle(title: "LEAVE HISTORY (LAST 30 DAYS)"),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showOnlyTodayLeaves = !_showOnlyTodayLeaves;
                              });
                            },
                            icon: Icon(
                              _showOnlyTodayLeaves ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppTheme.primary,
                              size: 16,
                            ),
                            label: Text(
                              _showOnlyTodayLeaves ? "Show Previous" : "Hide Previous",
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildLeaveHistory(),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  ),
);
}

  bool _isToday(Map<String, dynamic> data) {
    // 1. Check if timestamp is today
    final ts = data['timestamp'];
    DateTime? date;
    if (ts is Timestamp) {
      date = ts.toDate();
    } else if (ts is DateTime) {
      date = ts;
    } else if (ts is String) {
      date = DateTime.tryParse(ts);
    }
    final now = DateTime.now();
    if (date != null && date.year == now.year && date.month == now.month && date.day == now.day) {
      return true;
    }

    // 2. Check if fromDate is today
    final fromDateStr = data['fromDate']?.toString();
    if (fromDateStr != null) {
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      if (fromDateStr == todayStr || fromDateStr.startsWith(todayStr)) {
        return true;
      }
      try {
        final parsed = DateTime.tryParse(fromDateStr);
        if (parsed != null && parsed.year == now.year && parsed.month == now.month && parsed.day == now.day) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Widget _buildLeaveHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leave_requests').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final email = user.email;
        final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

        final leaves = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Filter by time: last 30 days
          final timestamp = data['timestamp'];
          DateTime? dt;
          if (timestamp is Timestamp) {
            dt = timestamp.toDate();
          } else if (timestamp is String) {
            dt = DateTime.tryParse(timestamp);
          }
          
          // Fallback to fromDate if timestamp is null
          if (dt == null && data['fromDate'] != null) {
            dt = DateTime.tryParse(data['fromDate'].toString());
          }
          
          // If still null, default to now so it is not hidden
          dt ??= DateTime.now();

          if (dt.isBefore(oneMonthAgo)) return false;

          // Filter by relation: teacher email OR classId matches
          final isMyTeacherLeave = data['type'] == 'teacher' && data['teacherEmail'] == email;
          
          final cleanClassId = _classId != null && _classId!.contains('_') ? _classId!.split('_').last : _classId;
          final cleanLeaveClassId = data['classId'] != null && data['classId'].toString().contains('_') ? data['classId'].toString().split('_').last : data['classId'];
          
          final isMyStudentLeave = data['type'] == 'student' && cleanClassId != null && cleanLeaveClassId == cleanClassId;

          if (!(isMyTeacherLeave || isMyStudentLeave)) return false;

          if (_showOnlyTodayLeaves) {
            return _isToday(data);
          }
          return true;
        }).toList();

        // Sort by timestamp descending
        leaves.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          final aTime = aData['timestamp'];
          final bTime = bData['timestamp'];
          
          DateTime? aDt = aTime is Timestamp ? aTime.toDate() : (aTime is String ? DateTime.tryParse(aTime) : null);
          DateTime? bDt = bTime is Timestamp ? bTime.toDate() : (bTime is String ? DateTime.tryParse(bTime) : null);
          
          aDt ??= aData['fromDate'] != null ? DateTime.tryParse(aData['fromDate'].toString()) : null;
          bDt ??= bData['fromDate'] != null ? DateTime.tryParse(bData['fromDate'].toString()) : null;
          
          if (aDt == null) return 1;
          if (bDt == null) return -1;
          return bDt.compareTo(aDt);
        });

        if (leaves.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, color: AppTheme.primary.withOpacity(0.3), size: 36),
                  const SizedBox(height: 8),
                   Text(
                    _showOnlyTodayLeaves ? "No leave requests today" : "No leave history for the past 30 days",
                    style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            final data = leaves[index].data() as Map<String, dynamic>;
            final type = data['type'] ?? 'student';
            final status = data['status'] ?? 'pending';
            final reason = data['reason'] ?? '';
            final fromDate = data['fromDate'] ?? '';
            final toDate = data['toDate'] ?? '';
            final name = type == 'student' ? (data['studentName'] ?? 'Student') : (data['teacherName'] ?? 'Teacher');

            Color statusColor = Colors.orange;
            Color cardBgColor = AppTheme.cardBg.withOpacity(0.85);
            Color borderColor = AppTheme.primary.withOpacity(0.12);

            if (status == 'approved') {
              statusColor = Colors.green;
              cardBgColor = Colors.green.withOpacity(0.08);
              borderColor = Colors.green.withOpacity(0.3);
            } else if (status == 'rejected') {
              statusColor = Colors.red;
              cardBgColor = Colors.red.withOpacity(0.08);
              borderColor = Colors.red.withOpacity(0.3);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      type == 'student' ? Icons.face_rounded : Icons.person_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                        const SizedBox(height: 2),
                        Text(
                          "Reason: $reason",
                          style: TextStyle(color: AppTheme.textDark.withOpacity(0.6), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$fromDate to $toDate",
                          style: TextStyle(color: AppTheme.textDark.withOpacity(0.4), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active_rounded, color: AppTheme.primary, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          "Notifications",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () async {
                        final snap = await FirebaseFirestore.instance
                            .collection('notifications')
                            .where('teacherEmail', isEqualTo: user.email)
                            .get();
                        for (var doc in snap.docs) {
                          await doc.reference.update({'isRead': true});
                        }
                      },
                      child: const Text("Mark all read", style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('teacherEmail', isEqualTo: user.email)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = List.from(snapshot.data!.docs);
                    docs.sort((a, b) {
                      final aTs = (a.data() as Map)['timestamp'] as Timestamp?;
                      final bTs = (b.data() as Map)['timestamp'] as Timestamp?;
                      if (aTs == null && bTs == null) return 0;
                      if (aTs == null) return 1;
                      if (bTs == null) return -1;
                      return bTs.compareTo(aTs);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No notifications yet",
                          style: TextStyle(color: AppTheme.textDark.withOpacity(0.4)),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, idx) {
                        final doc = docs[idx];
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Notification';
                        final body = data['body'] ?? '';
                        final isRead = data['isRead'] == true;
                        
                        return Card(
                          color: isRead ? AppTheme.cardBg : AppTheme.primary.withOpacity(0.08),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isRead ? AppTheme.primary.withOpacity(0.1) : AppTheme.primary.withOpacity(0.3),
                              width: isRead ? 1 : 1.5,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.notifications_rounded,
                              color: isRead ? AppTheme.textDark.withOpacity(0.5) : AppTheme.primary,
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                body,
                                style: TextStyle(
                                  color: AppTheme.textDark.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            trailing: !isRead
                                ? IconButton(
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.primary),
                                    onPressed: () => doc.reference.update({'isRead': true}),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

// ─────────────────────────────────────────────
//  Full-width action tile (local to teacher)
// ─────────────────────────────────────────────
class _DashTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _DashTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withOpacity(0.75),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 12)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.primary.withOpacity(0.4), size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Grid / Column Action Card
// ─────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.textDark,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}