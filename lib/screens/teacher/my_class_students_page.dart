import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import '../admin/admin_dashboard.dart';

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
                          style: TextStyle(color: AppTheme.textDark, fontSize: 14),
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
                                        roll,
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text("GR Number: $gr", style: TextStyle(fontSize: 12, color: AppTheme.textDark.withOpacity(0.7))),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
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
                                            if (phone != '—' && phone.isNotEmpty) ...[
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  "Contact: $phone",
                                                  style: TextStyle(fontSize: 11, color: AppTheme.textDark.withOpacity(0.5)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(Icons.edit_rounded, color: AppTheme.primary.withOpacity(0.7), size: 20),
                                      onPressed: () => _showEditStudentDialog(filteredDocs[idx].id, data),
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

  void _showEditStudentDialog(String docId, Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final phoneCtrl = TextEditingController(text: data['phone'] ?? '');
    final addressCtrl = TextEditingController(text: data['address'] ?? '');
    String currentGender = data['gender'] ?? 'Boy';
    DateTime? dob = data['dob'] != null ? DateTime.tryParse(data['dob']) : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text(
                "Edit Student Profile",
                style: TextStyle(color: Color(0xFF6E432E), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildReadOnlyField("Roll No", data['rollNo']?.toString() ?? '—'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildReadOnlyField("GR No", data['grNumber']?.toString() ?? '—'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(nameCtrl, "Student Name", Icons.person_rounded),
                      const SizedBox(height: 12),
                      _buildDialogField(phoneCtrl, "Parent Contact", Icons.phone_rounded, keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _buildDialogField(addressCtrl, "Address", Icons.home_rounded),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text("Gender:", style: TextStyle(color: Color(0xFF6E432E), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<String>(
                              value: currentGender.toLowerCase() == 'male' || currentGender.toLowerCase() == 'boy' ? 'Boy' : 'Girl',
                              dropdownColor: AppTheme.cardBg,
                              style: const TextStyle(color: Color(0xFF6E432E), fontSize: 13),
                              underline: Container(height: 1, color: AppTheme.primary),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => currentGender = val);
                              },
                              items: const [
                                DropdownMenuItem(value: 'Boy', child: Text("Boy")),
                                DropdownMenuItem(value: 'Girl', child: Text("Girl")),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text("DOB:", style: TextStyle(color: Color(0xFF6E432E), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: dob ?? DateTime(2010),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() => dob = picked);
                                }
                              },
                              child: Text(
                                dob != null ? "${dob!.day}/${dob!.month}/${dob!.year}" : "Select Date",
                                style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF9E7153))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    await FirebaseFirestore.instance.collection('students').doc(docId).update({
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'gender': currentGender,
                      if (dob != null) 'dob': dob!.toIso8601String(),
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Student profile saved successfully")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.textDark,
                  ),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.textDark.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.textDark.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(color: AppTheme.textDark.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.textDark, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textDark.withOpacity(0.55), fontSize: 12),
        prefixIcon: Icon(icon, color: AppTheme.primary.withOpacity(0.7), size: 16),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.2))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
      ),
    );
  }
}
