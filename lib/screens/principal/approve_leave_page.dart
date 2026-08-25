import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_system/services/mongodb_service.dart';

// ── Warli colour palette (shared) ──────────────────────────
class WC {
  static const bg         = Color(0xFFF7EEDC);
  static const brown      = Color(0xFF6E432E);
  static const brownLight = Color(0xFF9E7153);
  static const terra      = Color(0xFFD67845);
  static const amber      = Color(0xFFE29A3B);
  static const green      = Color(0xFF528751);
  static const red        = Color(0xFFC75146);
  static const cardBg     = Color(0xFFFEF9EB);
  static const divider    = Color(0xFFE6D6B8);
}

class ApproveLeavePage extends StatefulWidget {
  const ApproveLeavePage({super.key});
  @override
  State<ApproveLeavePage> createState() => _ApproveLeavePageState();
}

class _ApproveLeavePageState extends State<ApproveLeavePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedClass = 'All';
  String _selectedStatus = 'All';
  DateTime? _selectedDate;
  List<String> _classOptions = ['All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('classes').get();
      final list = snap.docs.map((c) {
        return c.id.contains('_') ? c.id.split('_').last : c.id;
      }).toSet().toList();
      list.sort();
      if (mounted) {
        setState(() {
          _classOptions = ['All', ...list];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance
        .collection('leave_requests')
        .doc(docId)
        .update({'status': status});
  }

  Future<void> _confirmReject(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WC.cardBg,
        title: Text("Reject Leave",
            style: TextStyle(color: WC.brown, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to reject this leave?",
            style: TextStyle(color: WC.brownLight)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: WC.brownLight))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Reject",
                  style: TextStyle(color: WC.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed == true) await _updateStatus(docId, 'rejected');
  }

  bool _showOnlyCurrentDay = true;

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempClass = _selectedClass;
        String tempStatus = _selectedStatus;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: WC.cardBg,
              title: const Text(
                "Filter Applications",
                style: TextStyle(color: WC.brown, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SizedBox(
                width: 320,
                height: 280,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Column (Left)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("BY CLASS", style: TextStyle(color: WC.brownLight, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _classOptions.length,
                              itemBuilder: (context, index) {
                                final c = _classOptions[index];
                                final isSel = tempClass == c;
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() => tempClass = c);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSel ? WC.terra : WC.brownLight,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSel
                                              ? Center(
                                                  child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: WC.terra,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(c, style: TextStyle(color: WC.brown, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 16, color: WC.divider),
                    // Status Column (Right)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("BY STATUS", style: TextStyle(color: WC.brownLight, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: 7,
                              itemBuilder: (context, index) {
                                final list = ['All', 'Pending', 'Approved', 'Rejected', 'Arrived', 'Exit Complete', 'Completed'];
                                final s = list[index];
                                final isSel = tempStatus == s;
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() => tempStatus = s);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSel ? WC.terra : WC.brownLight,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSel
                                              ? Center(
                                                  child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: WC.terra,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(s, style: TextStyle(color: WC.brown, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedClass = 'All';
                      _selectedStatus = 'All';
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Reset", style: TextStyle(color: WC.brownLight)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedClass = tempClass;
                      _selectedStatus = tempStatus;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Apply", style: TextStyle(color: WC.brown, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickFilterDate() async {
    if (_selectedDate != null) {
      setState(() => _selectedDate = null);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: WC.brown,
              onPrimary: Colors.white,
              onSurface: WC.brown,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: WC.terra.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WC.terra.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: WC.brown, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 11,
              color: WC.terra,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        Positioned.fill(
          child: Image.asset('assets/images/background.png', fit: BoxFit.cover),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: WC.brown),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(child: Text("Leave Applications",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: WC.brown))),
              ]),
            ),

            // Search and Filters Panel (Beside All/Show Prev Row)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: WC.brown, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search student...',
                        hintStyle: TextStyle(color: WC.brownLight.withOpacity(0.6), fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: WC.brown, size: 18),
                        prefixIconColor: WC.brown,
                        suffixIcon: PopupMenuButton<String>(
                          icon: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomFilterIcon(
                                color: (_selectedClass != 'All' || _selectedStatus != 'All' || _selectedDate != null)
                                    ? WC.terra
                                    : WC.brown,
                              ),
                              if (_selectedClass != 'All' || _selectedStatus != 'All' || _selectedDate != null)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: WC.terra,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          tooltip: 'Show filter options',
                          color: WC.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: WC.brown.withOpacity(0.15)),
                          ),
                          onSelected: (value) {
                            if (value == 'class_status') {
                              _showFilterDialog();
                            } else if (value == 'date') {
                              _pickFilterDate();
                            } else if (value == 'clear') {
                              setState(() {
                                _selectedClass = 'All';
                                _selectedStatus = 'All';
                                _selectedDate = null;
                              });
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'class_status',
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (_selectedClass != 'All' || _selectedStatus != 'All') ? WC.terra : Colors.transparent,
                                      border: Border.all(color: WC.brownLight, width: 1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Filter by Class & Status',
                                    style: TextStyle(
                                      color: WC.brown,
                                      fontSize: 13,
                                      fontWeight: (_selectedClass != 'All' || _selectedStatus != 'All') ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'date',
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (_selectedDate != null) ? WC.terra : Colors.transparent,
                                      border: Border.all(color: WC.brownLight, width: 1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Filter by Date',
                                    style: TextStyle(
                                      color: WC.brown,
                                      fontSize: 13,
                                      fontWeight: (_selectedDate != null) ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedClass != 'All' || _selectedStatus != 'All' || _selectedDate != null) ...[
                              const PopupMenuDivider(height: 1),
                              PopupMenuItem<String>(
                                value: 'clear',
                                child: const Row(
                                  children: [
                                    Icon(Icons.clear_all_rounded, size: 16, color: WC.terra),
                                    SizedBox(width: 8),
                                    Text(
                                      'Clear All Filters',
                                      style: TextStyle(
                                        color: WC.terra,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: WC.brown.withOpacity(0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: WC.brown.withOpacity(0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: WC.brown, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showOnlyCurrentDay = !_showOnlyCurrentDay;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      _showOnlyCurrentDay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: WC.brown,
                      size: 16,
                    ),
                    label: Text(
                      _showOnlyCurrentDay ? "Show Prev" : "Hide Prev",
                      style: const TextStyle(
                        color: WC.brown,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Active Filters Chips (displays when filters are active)
            if (_selectedClass != 'All' || _selectedStatus != 'All' || _selectedDate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (_selectedClass != 'All')
                            _buildFilterChip("Class: $_selectedClass", () {
                              setState(() => _selectedClass = 'All');
                            }),
                          if (_selectedStatus != 'All')
                            _buildFilterChip("Status: $_selectedStatus", () {
                              setState(() => _selectedStatus = 'All');
                            }),
                          if (_selectedDate != null)
                            _buildFilterChip("Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}", () {
                              setState(() => _selectedDate = null);
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(child: _LeaveList(
                filter: 'all',
                showOnlyCurrentDay: _showOnlyCurrentDay,
                searchQuery: _searchQuery,
                selectedClass: _selectedClass,
                selectedStatus: _selectedStatus,
                selectedDate: _selectedDate,
                onUpdate: _updateStatus,
                onReject: _confirmReject)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Leave List
// ─────────────────────────────────────────────
class _LeaveList extends StatelessWidget {
  final String filter;
  final bool showOnlyCurrentDay;
  final String searchQuery;
  final String selectedClass;
  final String selectedStatus;
  final DateTime? selectedDate;
  final Future<void> Function(String, String) onUpdate;
  final Future<void> Function(String) onReject;

  const _LeaveList({
    required this.filter,
    required this.showOnlyCurrentDay,
    required this.searchQuery,
    required this.selectedClass,
    required this.selectedStatus,
    required this.selectedDate,
    required this.onUpdate,
    required this.onReject,
  });

  bool _isCurrentDay(Map<String, dynamic> data) {
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

  String _getEffectiveStatus(Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final exitStatus = (data['exitStatus'] ?? 'pending_exit').toString();
    
    // Check if past
    bool isPast = false;
    final toDateVal = data['toDate'] ?? data['fromDate'];
    if (toDateVal is String && toDateVal.isNotEmpty) {
      try {
        final parsed = DateTime.tryParse(toDateVal);
        if (parsed != null) {
          final endOfDay = DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
          if (DateTime.now().isAfter(endOfDay)) {
            isPast = true;
          }
        }
      } catch (_) {}
    }

    if (status == 'pending') return 'Pending';
    if (status == 'rejected') return 'Rejected';
    
    if (isPast) return 'Completed';
    if (exitStatus == 'arrived') return 'Arrived';
    if (exitStatus == 'exited') return 'Exit Complete';
    return 'Approved';
  }

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection('leave_requests')
        .orderBy('timestamp', descending: true);
    if (filter != 'all') q = q.where('type', isEqualTo: filter);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return Center(
            child: Text("Error loading", style: TextStyle(color: WC.brown)));
        if (!snap.hasData) return Center(
            child: CircularProgressIndicator(color: WC.terra));

        var docs = snap.data!.docs;

        // Apply filter in memory if showOnlyCurrentDay is true
        if (showOnlyCurrentDay) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _isCurrentDay(data);
          }).toList();
        }

        // Apply Search Query
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase().trim();
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? 'student';
            final name = (type == 'student'
                ? (data['studentName'] ?? '')
                : (data['teacherName'] ?? '')).toString().toLowerCase();
            final classId = (data['classId'] ?? '').toString().toLowerCase();
            return name.contains(query) || classId.contains(query);
          }).toList();
        }

        // Apply Class Filter
        if (selectedClass != 'All') {
          final targetClass = selectedClass.toLowerCase().trim();
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final classId = (data['classId'] ?? '').toString().toLowerCase();
            final cleanClassId = classId.contains('_') ? classId.split('_').last : classId;
            return cleanClassId.trim() == targetClass;
          }).toList();
        }

        // Apply Status Filter
        if (selectedStatus != 'All') {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final effStatus = _getEffectiveStatus(data);
            return effStatus.toLowerCase() == selectedStatus.toLowerCase();
          }).toList();
        }

        // Apply Date Filter
        if (selectedDate != null) {
          final filterDateStr = "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fromDate = (data['fromDate'] ?? '').toString();
            final toDate = (data['toDate'] ?? '').toString();
            
            if (fromDate == filterDateStr || toDate == filterDateStr) return true;
            try {
              final start = DateTime.tryParse(fromDate);
              final end = DateTime.tryParse(toDate);
              if (start != null && end != null) {
                final target = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
                final sDay = DateTime(start.year, start.month, start.day);
                final eDay = DateTime(end.year, end.month, end.day);
                return (target.isAfter(sDay) || target.isAtSameMomentAs(sDay)) &&
                       (target.isBefore(eDay) || target.isAtSameMomentAs(eDay));
              }
            } catch (_) {}
            return false;
          }).toList();
        }

        if (docs.isEmpty) return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_rounded, size: 64,
                color: WC.brownLight.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(showOnlyCurrentDay ? "No leave requests today" : "No leave requests",
                style: TextStyle(color: WC.brownLight, fontSize: 16)),
          ],
        ));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _LeaveCard(
              docId: doc.id,
              data: data,
              onApprove: () => onUpdate(doc.id, 'approved'),
              onReject: () => onReject(doc.id),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Leave Card
// ─────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove, onReject;

  const _LeaveCard(
      {required this.docId, required this.data,
        required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(docId)
          .snapshots(),
      builder: (ctx, snap) {
        final live = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String, dynamic>
            : data;

        return _LeaveCardContent(
          docId: docId,
          data: live,
          onApprove: onApprove,
          onReject: onReject,
        );
      },
    );
  }
}

class _LeaveCardContent extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove, onReject;

  const _LeaveCardContent(
      {required this.docId, required this.data,
        required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final type      = data['type'] ?? 'student';
    final status    = data['status'] ?? 'pending';
    final isStudent = type == 'student';
    final isPending = status == 'pending';
    final isToday   = data['isToday'] == true; // ← check isToday flag

    final name    = isStudent
        ? (data['studentName'] ?? 'Unknown')
        : (data['teacherName'] ?? 'Unknown Teacher');
    final subInfo = isStudent
        ? "Class ${data['classId'] ?? '-'}"
        : (data['teacherEmail'] ?? '');
    final reason  = data['reason'] ?? '';

    // ── Date / Time values depending on isToday ───────────
    final from = isToday
        ? (data['fromTime'] ?? data['fromDate'] ?? '')
        : (data['fromDate'] ?? '');
    final to = isToday
        ? (data['toTime'] ?? data['toDate'] ?? '')
        : (data['toDate'] ?? '');
    final todayDate = data['fromDate'];
    // ── Exit tracking ─────────────────────────────────────
    final exitStatus = (data['exitStatus'] ?? 'pending_exit').toString();
    final hasExited  = exitStatus == 'exited';

    String exitTimeStr = '';
    if (hasExited && data['exitTime'] != null) {
      final raw = data['exitTime'];
      if (raw is Timestamp) {
        final dt = raw.toDate().toLocal();
        exitTimeStr =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } else {
        exitTimeStr = raw.toString();
      }
    }

    final initials = name.isNotEmpty
        ? name.trim().split(' ').where((String e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    // Check if past
    bool isPast = false;
    final toDateVal = data['toDate'] ?? data['fromDate'];
    if (toDateVal is String && toDateVal.isNotEmpty) {
      try {
        final parsed = DateTime.tryParse(toDateVal);
        if (parsed != null) {
          final endOfDay = DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
          if (DateTime.now().isAfter(endOfDay)) {
            isPast = true;
          }
        }
      } catch (_) {}
    }

    Color stColor; Color stBg; String stLabel;
    if (status == 'pending') {
      stColor = WC.amber; stBg = WC.amber.withOpacity(0.15);
      stLabel = "Pending";
    } else if (status == 'rejected') {
      stColor = WC.red; stBg = WC.red.withOpacity(0.12);
      stLabel = "Rejected";
    } else {
      if (isPast) {
        stColor = Colors.grey; stBg = Colors.grey.withOpacity(0.15);
        stLabel = "Completed";
      } else if (exitStatus == 'arrived') {
        stColor = WC.green; stBg = WC.green.withOpacity(0.12);
        stLabel = "Arrived";
      } else if (exitStatus == 'exited') {
        stColor = WC.green; stBg = WC.green.withOpacity(0.12);
        stLabel = "Exit Complete";
      } else {
        stColor = WC.green; stBg = WC.green.withOpacity(0.12);
        stLabel = "Approved";
      }
    }

    final trackingDotColor = isPast 
        ? Colors.grey 
        : (hasExited ? WC.green : WC.amber);
    final trackingLabel = isPast
        ? "Completed"
        : (hasExited 
            ? "Live" 
            : (status == 'pending' ? "Waiting" : "Watching"));

    final exitColor = hasExited ? WC.green : WC.terra;
    final exitBg    = hasExited
        ? WC.green.withOpacity(0.10) : WC.terra.withOpacity(0.10);
    final exitLabel = hasExited ? "Exited" : "Pending Exit";
    final exitIcon  = hasExited
        ? Icons.exit_to_app_rounded : Icons.hourglass_top_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: WC.cardBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WC.divider),
        boxShadow: [BoxShadow(color: WC.brown.withOpacity(0.10),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ────────────────────────────────────────
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: WC.terra.withOpacity(0.15),
              child: Text(initials, style: const TextStyle(
                  color: WC.terra, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: WC.brown)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: WC.brown.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(isStudent ? "Student" : "Teacher",
                        style: const TextStyle(color: WC.brown,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Text(subInfo, style: TextStyle(
                      color: WC.brownLight, fontSize: 11)),
                ]),
              ],
            )),
            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: stBg,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(stLabel, style: TextStyle(
                  color: stColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),

          const SizedBox(height: 10),
          Divider(color: WC.divider, height: 1),
          const SizedBox(height: 10),

          // ── Reason ────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 14, color: WC.brownLight),
            const SizedBox(width: 6),
            Expanded(child: Text(reason, style: TextStyle(
                color: WC.brown, fontSize: 13, height: 1.4))),
          ]),

          const SizedBox(height: 10),

          // ── Dates OR Times (based on isToday) ─────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: WC.amber.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WC.amber.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(
                // clock icon for same-day time, calendar for date range
                isToday
                    ? Icons.access_time_rounded
                    : Icons.calendar_today_rounded,
                size: 13,
                color: WC.amber,
              ),
              const SizedBox(width: 6),
              // "Today •" prefix when isToday so context is clear
              if (isToday)
                Text("$todayDate •  ",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: WC.brownLight)),
              Text("$from  →  $to",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WC.brown)),
            ]),
          ),

          const SizedBox(height: 10),

          // ── Exit Tracking ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: exitBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: exitColor.withOpacity(0.30)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Row(children: [
                Icon(Icons.door_front_door_rounded, size: 15, color: exitColor),
                const SizedBox(width: 6),
                Text("Exit Tracking",
                    style: TextStyle(color: exitColor,
                        fontWeight: FontWeight.w800, fontSize: 12,
                        letterSpacing: 0.5)),
                const Spacer(),
                Container(width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: trackingDotColor,
                        shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(trackingLabel,
                    style: TextStyle(fontSize: 10, color: WC.brownLight)),
              ]),

              const SizedBox(height: 10),

              _ExitInfoRow(icon: Icons.person_rounded, label: "Name", value: name),

              if (isStudent) ...[
                const SizedBox(height: 6),
                _ExitInfoRow(
                  icon: Icons.class_rounded,
                  label: "Class",
                  value: data['classId']?.toString() ?? '-',
                ),
              ],

              const SizedBox(height: 8),

              Row(children: [
                Icon(exitIcon, size: 14, color: exitColor),
                const SizedBox(width: 6),
                Text("Exit Status:",
                    style: TextStyle(fontSize: 12, color: WC.brownLight)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: exitColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: exitColor.withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(exitIcon, size: 11, color: exitColor),
                    const SizedBox(width: 5),
                    Text(exitLabel, style: TextStyle(
                        color: exitColor, fontWeight: FontWeight.bold,
                        fontSize: 11)),
                  ]),
                ),
              ]),

              if (hasExited && exitTimeStr.isNotEmpty) ...[
                const SizedBox(height: 6),
                _ExitInfoRow(
                  icon: Icons.access_time_filled_rounded,
                  label: "Exit Time",
                  value: exitTimeStr,
                  valueColor: WC.green,
                ),
              ],
            ]),
          ),

          // ── Action buttons ────────────────────────────────
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: onReject,
                icon: Icon(Icons.close_rounded, size: 16, color: WC.red),
                label: Text("Reject", style: TextStyle(color: WC.red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: WC.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                label: const Text("Approve", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WC.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
              )),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Exit info row helper
// ─────────────────────────────────────────────
class _ExitInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _ExitInfoRow(
      {required this.icon, required this.label,
        required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: WC.brownLight),
      const SizedBox(width: 6),
      Text("$label: ", style: TextStyle(fontSize: 12, color: WC.brownLight)),
      Expanded(child: Text(value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: valueColor ?? WC.brown),
          overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class CustomFilterIcon extends StatelessWidget {
  final Color color;
  const CustomFilterIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 12,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(height: 2, width: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
          Container(height: 2, width: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
          Container(height: 2, width: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
        ],
      ),
    );
  }
}