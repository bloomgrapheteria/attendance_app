import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';

class MyClassStudentsPage extends StatefulWidget {
  final String classId;
  const MyClassStudentsPage({super.key, required this.classId});

  @override
  State<MyClassStudentsPage> createState() => _MyClassStudentsPageState();
}

class _MyClassStudentsPageState extends State<MyClassStudentsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanClassId = widget.classId.contains('_') ? widget.classId.split('_').last : widget.classId;

    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(
            children: [
              WarliAppBar(
                title: "Class $cleanClassId Students",
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg.withOpacity(0.78),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "Search by Name, Roll, GR...",
                            prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary.withOpacity(0.55), size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Student List
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('students')
                              .where('classId', isEqualTo: cleanClassId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final docs = snapshot.data!.docs;

                            // Filter students
                            final filteredDocs = docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              final gr = (data['grNumber'] ?? '').toString().toLowerCase();
                              final roll = (data['rollNo'] ?? '').toString().toLowerCase();
                              return name.contains(_searchQuery) ||
                                  gr.contains(_searchQuery) ||
                                  roll.contains(_searchQuery);
                            }).toList();

                            // Sort alphabetically by name
                            filteredDocs.sort((a, b) {
                              final nameA = (a.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
                              final nameB = (b.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
                              return nameA.compareTo(nameB);
                            });

                            if (filteredDocs.isEmpty) {
                              return Center(
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? "No students found in this class"
                                      : "No matching students found",
                                  style: TextStyle(color: AppTheme.textDark.withOpacity(0.4)),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, idx) {
                                final data = filteredDocs[idx].data() as Map<String, dynamic>;
                                final name = data['name'] ?? 'Unknown';
                                final gr = data['grNumber']?.toString() ?? 'NA';
                                final roll = data['rollNo']?.toString() ?? '—';
                                final gender = data['gender']?.toString() ?? '—';
                                final phone = data['phone']?.toString() ?? '—';

                                return Card(
                                  color: AppTheme.cardBg,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: AppTheme.primary.withOpacity(0.12)),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text("Roll: $roll", style: const TextStyle(fontSize: 12)),
                                            const SizedBox(width: 12),
                                            Text("GR: $gr", style: const TextStyle(fontSize: 12)),
                                            const Spacer(),
                                            Text(
                                              gender.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: gender.toLowerCase() == 'male' || gender.toLowerCase() == 'boy'
                                                    ? Colors.blue.shade700
                                                    : Colors.pink.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (phone != '—' && phone.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text("Parent Contact: $phone", style: const TextStyle(fontSize: 12)),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
