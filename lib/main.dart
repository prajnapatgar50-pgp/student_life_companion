import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart'; 
import 'study_games.dart';
import 'study_tracker.dart';
import 'pages/ask_ai.dart';
import 'timetable.dart';
import 'study_tasks.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'focus_mode.dart'; 
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  await Alarm.init(); 
  
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: StudentLoginPage(),
  ));
}

// --- 1.(LOGIN PAGE) ---
class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});

  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both Email ID and Password!"),
          backgroundColor: Colors.red,
        ),
      );
    } 
    else if(password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters long!"),
          backgroundColor: Colors.red,
        ),
      );
    }
    else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 80, color: Colors.blueAccent),
            const Text("Student Companion", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email ID", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true, 
              decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _handleLogin, 
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), 
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text("LOGIN"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2.(MAIN DASHBOARD) ---
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  TimeOfDay? startStudyTime;
  TimeOfDay? endStudyTime;
  String studentName = "Student"; 
  
  String selectedTheme = "Blue"; 
  Color primaryColor = const Color(0xFF4A80F0);
  Color scaffoldBgColor = Colors.white;
  Color textColor = Colors.black;

  List<double> actualStudyHours = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  bool isFocusModeOn = false; 
  StreamSubscription<AlarmSettings>? alarmSubscription;
  Timer? _timeCheckTimer; 
  
  Future<void> _loadWeeklyHours() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? storedHours = prefs.getStringList('weekly_study_hours');
    if (storedHours != null) {
      setState(() {
        actualStudyHours = storedHours.map((h) => double.parse(h)).toList();
      });
    }
  }

  Future<void> _loadProfileAndTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      studentName = prefs.getString('prof_username') ?? "Student";
      selectedTheme = prefs.getString('app_theme') ?? "Blue";
      _applyTheme(selectedTheme);
    });
    _loadSavedFocusTimes(); 
  }

  Future<void> _loadSavedFocusTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final startStr = prefs.getString('focus_start_time');
    final endStr = prefs.getString('focus_end_time');
    if (startStr != null && endStr != null) {
      setState(() {
        startStudyTime = TimeOfDay(hour: int.parse(startStr.split(':')[0]), minute: int.parse(startStr.split(':')[1]));
        endStudyTime = TimeOfDay(hour: int.parse(endStr.split(':')[0]), minute: int.parse(endStr.split(':')[1]));
      });
    }
  }

  void _applyTheme(String theme) {
    if (theme == "Black (Dark)") {
      primaryColor = const Color(0xFF1F1F1F);
      scaffoldBgColor = const Color(0xFF121212);
      textColor = Colors.white;
    } else if (theme == "Teal Green") {
      primaryColor = Colors.teal;
      scaffoldBgColor = Colors.teal.shade50;
      textColor = Colors.black;
    } else {
      primaryColor = const Color(0xFF4A80F0);
      scaffoldBgColor = Colors.white;
      textColor = Colors.black;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWeeklyHours();
    _loadProfileAndTheme();
    alarmSubscription?.cancel(); 
    try {
      alarmSubscription = Alarm.ringStream.stream.listen((alarmSettings) {
        if (alarmSettings.id == 101) {
          Alarm.stop(101);
          setState(() {
            isFocusModeOn = true; 
          });
          try{
            final platform = const MethodChannel('com.example.student_life_companion/lock');     
            platform.invokeMethod('startLockTask');
            debugPrint("screen pinning triggered automatically!");
            } catch(e){
              debugPrint("screen pinning error: $e");
            }
            if (!mounted) return;
          if(Theme.of(context).platform == TargetPlatform.android){
            final AndroidIntent intent = AndroidIntent(
              action: 'android.intent.action.MAIN',
              package: 'com.example.student_life_companion',
              componentName: 'com.example.student_life_companion.MainActivity',
              flags: <int> [],
            );
            intent.launch().catchError((e){
              debugPrint("intent launch error: $e");
            }
            );
          }
          _blockDistractingApps(); 
        } else if (alarmSettings.id == 102) {
          Alarm.stop(102);
          _stopStudySession();
        }
      });
    } catch (e) {
      debugPrint("Error setting up alarm listener: $e");
    }

    _timeCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {}); 
      }
    });
  }

  @override
  void dispose() {
    alarmSubscription?.cancel(); 
    _timeCheckTimer?.cancel();
    super.dispose();
  }

  void _blockDistractingApps() {
    debugPrint("Focus Mode ON: Restricted apps are locked.");
  }

  void _unblockApps() {
    debugPrint("Focus Mode OFF: All apps are available.");
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (isStart) {
          startStudyTime = picked;
          prefs.setString('focus_start_time', '${picked.hour}:${picked.minute}');
        } else {
          endStudyTime = picked;
          prefs.setString('focus_end_time', '${picked.hour}:${picked.minute}');
        }
      });

      if (startStudyTime != null && endStudyTime != null) {
        final now = DateTime.now();

        final startDateTime = DateTime(now.year, now.month, now.day, startStudyTime!.hour, startStudyTime!.minute);
        final startAlarmSettings = AlarmSettings(
          id: 101,
          dateTime: startDateTime,
          assetAudioPath: 'assets/alarm.mp3',
          loopAudio: true,
          vibrate: true,
          volumeSettings: const VolumeSettings.fixed(volume: 0.8),  
          notificationSettings: const NotificationSettings(
            title: 'Study Time Started!,pin student life companion',
            body: 'Strict Focus Mode is activating now! 📚',
            stopButton: 'start studying',
          ),
        );
      
        final endDateTime = DateTime(now.year, now.month, now.day, endStudyTime!.hour, endStudyTime!.minute);
        final endAlarmSettings = AlarmSettings(
          id: 102,
          dateTime: endDateTime,
          assetAudioPath: 'assets/alarm.mp3',
          loopAudio: true,
          vibrate: true,
          volumeSettings: const VolumeSettings.fixed(volume: 0.5),  
          notificationSettings: const NotificationSettings(
            title: 'Study Time Over!',
            body: 'Good job! Focus Mode is turning off. 🎉',
            stopButton: 'stop',
          ),
        );

        await Alarm.set(alarmSettings: startAlarmSettings);
        await Alarm.set(alarmSettings: endAlarmSettings);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Study Alarms scheduled automatically! 🎯")),
          );
        }
      }
    }
  }

  Future<void> _stopStudySession() async {
    Alarm.stop(102);
    setState(() {
      isFocusModeOn = false;
    });
    if (startStudyTime != null && endStudyTime != null) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, startStudyTime!.hour, startStudyTime!.minute);
      var end = DateTime(now.year, now.month, now.day, endStudyTime!.hour, endStudyTime!.minute);
      
      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }
      
      double hours = end.difference(start).inMinutes / 60.0;
      try {
        final prefs = await SharedPreferences.getInstance();
        double existingHours = prefs.getDouble('total_study_hours') ?? 0.0;
        double totalHours = existingHours + hours;
        await prefs.setDouble('total_study_hours', totalHours);
        debugPrint("study hours saved to database: $totalHours");
        _loadWeeklyHours();
      } catch (e){
        debugPrint("database save error: $e");
      }
      
      setState(() {
        int today = now.weekday - 1; 
        if (today >= 0 && today < actualStudyHours.length) {
          actualStudyHours[today] += hours;
        }
        startStudyTime = null;
        endStudyTime = null;
        isFocusModeOn = false;
      });

      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('focus_start_time');
        prefs.remove('focus_end_time');
      });

      _unblockApps();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Great! ${hours.toStringAsFixed(1)} hours added to Tracker.")),
      );
    }
  }

  bool _isCurrentlyStudyTime() {
    if (startStudyTime == null || endStudyTime == null) return false;
    
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, startStudyTime!.hour, startStudyTime!.minute);
    var endTime = DateTime(now.year, now.month, now.day, endStudyTime!.hour, endStudyTime!.minute);
    
    if (endTime.isBefore(startTime)) {
      endTime = endTime.add(const Duration(days: 1));
    }
    
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCurrentlyStudyTime() || isFocusModeOn) {
      return FocusModePage(onExitFocus: _stopStudySession); 
    }

    return Scaffold(
      backgroundColor: scaffoldBgColor, 
      appBar: AppBar(
        title: Text("Hi, $studentName 🎓", style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
              _loadProfileAndTheme(); 
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: primaryColor, 
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => _pickTime(context, true),
                    child: Text(startStudyTime == null ? "Start Time" : startStudyTime!.format(context), style: const TextStyle(color: Colors.white)),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white),
                  TextButton(
                    onPressed: () => _pickTime(context, false),
                    child: Text(endStudyTime == null ? "End Time" : endStudyTime!.format(context), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Core Features", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  featureCard(context, "Study Tasks", Icons.description, selectedTheme == "Black (Dark)" ? Colors.grey.shade900 : const Color(0xFFE3F2FD), Colors.blue),
                  featureCard(context, "Timetable", Icons.calendar_month, selectedTheme == "Black (Dark)" ? Colors.grey.shade900 : const Color(0xFFFFF3E0), Colors.orange),
                  featureCard(context, "Ask AI Helper", Icons.psychology, selectedTheme == "Black (Dark)" ? Colors.grey.shade900 : const Color(0xFFF3E5F5), Colors.purple),
                  featureCard(context, "Study Tracker", Icons.bar_chart, selectedTheme == "Black (Dark)" ? Colors.grey.shade900 : const Color(0xFFE0F2F1), Colors.teal),
                  featureCard(context, "Career Guide", Icons.explore, selectedTheme == "Black (Dark)" ? Colors.grey.shade900 : const Color(0xFFE8EAF6), Colors.indigo),
                  featureCard(context, "Study Games", Icons.videogame_asset, selectedTheme == "Black (Dark)" ? Colors.grey.shade900 : const Color(0xFFF1F8E9), Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget featureCard(BuildContext context, String title, IconData icon, Color bgColor, Color iconColor) {
    return InkWell(
      onTap: () {
        if (title == "Study Tasks") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const StudyTasksPage()));
        } else if (title == "Timetable") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage()));
        } else if (title == "Ask AI Helper") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AskAIHelperPage()));
        } else if (title == "Study Tracker") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const StudyTrackerPage()));
        } else if (title == "Career Guide") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CareerPage()));
        } else if (title == "Study Games") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const StudyGamesPage()));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: selectedTheme == "Black (Dark)" ? Border.all(color: Colors.grey.shade800) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }
}

// --- 3.(EDIT PROFILE PAGE) ---
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _bioController = TextEditingController();
  final _eduController = TextEditingController();
  final _collegeController = TextEditingController();
  final _goalController = TextEditingController();
  
  String _currentTheme = "Blue";
  final List<String> _themes = ["Blue", "Black (Dark)", "Teal Green"];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('prof_username') ?? "";
      _dobController.text = prefs.getString('prof_dob') ?? "";
      _bioController.text = prefs.getString('prof_bio') ?? "";
      _eduController.text = prefs.getString('prof_edu') ?? "";
      _collegeController.text = prefs.getString('prof_college') ?? "";
      _goalController.text = prefs.getString('prof_goal') ?? "";
      _currentTheme = prefs.getString('app_theme') ?? "Blue";
    });
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prof_username', _nameController.text);
    await prefs.setString('prof_dob', _dobController.text);
    await prefs.setString('prof_bio', _bioController.text);
    await prefs.setString('prof_edu', _eduController.text);
    await prefs.setString('prof_college', _collegeController.text);
    await prefs.setString('prof_goal', _goalController.text);
    await prefs.setString('app_theme', _currentTheme);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile & Theme Updated! 🎉")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: _currentTheme == "Black (Dark)" ? Colors.grey.shade900 : const Color(0xFF4A80F0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, backgroundColor: Color(0xFF4A80F0), child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 20),
            
            DropdownButtonFormField<String>(
              value: _currentTheme,
              decoration: const InputDecoration(labelText: "Choose Dashboard Theme Color", border: OutlineInputBorder()),
              items: _themes.map((String theme) {
                return DropdownMenuItem<String>(
                  value: theme,
                  child: Text(theme),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _currentTheme = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 15),
            
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _dobController, decoration: const InputDecoration(labelText: "Date of Birth (DD-MM-YYYY)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _bioController, decoration: const InputDecoration(labelText: "Bio", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _eduController, decoration: const InputDecoration(labelText: "Education (Course/Branch)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _collegeController, decoration: const InputDecoration(labelText: "College/University Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _goalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Daily Study Goal (Hours)", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveProfileData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), 
                backgroundColor: _currentTheme == "Black (Dark)" ? Colors.grey.shade800 : const Color(0xFF4A80F0), 
                foregroundColor: Colors.white
              ),
              child: const Text("SAVE PROFILE & THEME"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. ಕೆರಿಯರ್ ಪೇಜ್ (CAREER PAGE) ---
class CareerPage extends StatelessWidget {
  const CareerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Career Guide"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: const Center(
        child: Text(
          "Future Career Guidance Coming Soon!",
          style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
         ),
      ),
    );
  }
}