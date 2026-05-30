import 'package:flutter/material.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {

  final List<Map<String, String>> schedule = [];

  void _showSubjectDialog({int? index}) {
    String sub = index != null ? schedule[index]['subject']! : "";
    String time = index != null ? schedule[index]['time']! : "";
    String room = index != null ? schedule[index]['room']! : "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? "Add Class" : "Edit Class"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: sub),
              onChanged: (val) => sub = val, 
              decoration: const InputDecoration(labelText: "Subject Name"),
            ),
            TextField(
              controller: TextEditingController(text: time),
              onChanged: (val) => time = val, 
              decoration: const InputDecoration(labelText: "Time (e.g. 10-11 AM)"),
            ),
            TextField(
              controller: TextEditingController(text: room),
              onChanged: (val) => room = val, 
              decoration: const InputDecoration(labelText: "Room/Link"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (sub.isNotEmpty && time.isNotEmpty) {
                setState(() {
                  if (index == null) {
                    schedule.add({"time": time, "subject": sub, "room": room, "color": "0xFFAB47BC"});
                  } else {
                    schedule[index] = {"time": time, "subject": sub, "room": room, "color": schedule[index]['color']!};
                  }
                });
                Navigator.pop(context);
              }
            },
            child: Text(index == null ? "Add" : "Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Timetable", style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
        backgroundColor: const Color(0xFF4A80F0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF4A80F0),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: const Text(
              "Manage your daily classes easily.",
              style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          
          Expanded(
            child: schedule.isEmpty 
              ? const Center(child: Text("No classes added yet. Click + to start!"))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: schedule.length,
                  itemBuilder: (context, index) {
                    final item = schedule[index];
                    return Dismissible(
                      key: UniqueKey(),
                      onDismissed: (direction) {
                        setState(() { schedule.removeAt(index); });
                      },
                      background: Container(
                        color: Colors.red, 
                        alignment: Alignment.centerRight, 
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 3,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          leading: CircleAvatar(
                            backgroundColor: Color(int.parse(item['color']!)).withOpacity(0.2),
                            child: Icon(Icons.book, color: Color(int.parse(item['color']!))),
                          ),
                          title: Text(item['subject']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text("${item['time']} ${item['room']!.isNotEmpty ? '| ${item['room']!}' : ''}"),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showSubjectDialog(index: index);
                              } else if (value == 'delete') {
                                setState(() { schedule.removeAt(index); });
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text("Edit")),
                              const PopupMenuItem(value: 'delete', child: Text("Delete")),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubjectDialog(),
        backgroundColor: const Color(0xFF4A80F0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}