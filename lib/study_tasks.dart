import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudyTasksPage extends StatefulWidget {
  const StudyTasksPage({super.key});
  @override
  State<StudyTasksPage> createState() => _StudyTasksPageState();
}

class _StudyTasksPageState extends State<StudyTasksPage> {
  List<Map<String, dynamic>> _tasks = [];
  final TextEditingController _controller = TextEditingController();
  DateTime? _selectedSubmitDate; 

  @override
  void initState() {
    super.initState();
    _loadTasks(); 
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? taskString = prefs.getString('user_tasks');
    if (taskString != null) {
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(json.decode(taskString));
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('user_tasks', json.encode(_tasks));
  }

  // ---DD-MM-YYYY ---
  String _formatDate(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "No Date Set";
    try {
      DateTime dt = DateTime.parse(dateTimeStr);
      String day = dt.day.toString().padLeft(2, '0');
      String month = dt.month.toString().padLeft(2, '0');
      String year = dt.year.toString();
      
      return "$day-$month-$year"; // (Ex: 21-05-2026)
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Study Tasks"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _tasks.isEmpty 
          ? const Center(child: Text("No tasks")) 
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  leading: Checkbox(
                    value: _tasks[index]["isDone"], 
                    onChanged: (v) {
                      setState(() => _tasks[index]["isDone"] = v);
                      _saveTasks();
                    }
                  ),
                  title: Text(
                    _tasks[index]["title"],
                    style: TextStyle(
                      decoration: _tasks[index]["isDone"] ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "Submit Date: ${_formatDate(_tasks[index]["date"])}",
                    style: TextStyle(
                      fontSize: 12, 
                      color: _tasks[index]["isDone"] ? Colors.grey : Colors.blue.shade700,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red), 
                    onPressed: () {
                      setState(() => _tasks.removeAt(index));
                      _saveTasks();
                    }
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _pickSubmitDate(BuildContext context, StateSetter dialogState) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), 
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      dialogState(() {
        _selectedSubmitDate = picked;
      });
    }
  }

  void _showAddDialog() {
    _selectedSubmitDate = null; 
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( 
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("New Task"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: "Ex: reading, homework"),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedSubmitDate == null 
                            ? "No date selected" 
                            : "Submit Date: ${_selectedSubmitDate!.day.toString().padLeft(2, '0')}-${_selectedSubmitDate!.month.toString().padLeft(2, '0')}-${_selectedSubmitDate!.year}",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _pickSubmitDate(context, setDialogState),
                  child: const Text("Select Submit Date", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (_controller.text.isNotEmpty) {
                    String dateStr = _selectedSubmitDate != null 
                        ? _selectedSubmitDate!.toIso8601String() 
                        : DateTime.now().toIso8601String();
                        await _saveTaskToFirestore(_controller.text, dateStr); // Save to Firestore
                    setState(() {
                      _tasks.add({
                        "title": _controller.text, 
                        "isDone": false,
                        "date": dateStr
                      });
                      _controller.clear();
                    });
                    _saveTasks();
                    Navigator.pop(context);
                  }
                }, 
                child: const Text("Add")
              )
            ],
          );
        },
      ),
    );
  }
  Future<void> _saveTaskToFirestore(String title, String submitDate) async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Automatically creates 'study_tasks' collection in Firebase and adds data
    await firestore.collection('study_tasks').add({
      'student_name': 'Prajna',
      'task_title': title,
      'submit_date': submitDate,
      'is_completed': false,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    print("Task saved successfully to Firebase Firestore! 🔥");
  } catch (e) {
    print("Error saving task to Firestore: $e");
  }
}
}