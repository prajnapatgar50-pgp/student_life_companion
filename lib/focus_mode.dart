import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FocusModePage extends StatefulWidget {
  final VoidCallback? onExitFocus; 

  const FocusModePage({super.key, this.onExitFocus});

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> with WidgetsBindingObserver {
  static const platform = MethodChannel('focus_mode_channel');
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isFocusActive = false;
  Timer? _timeCheckTimer;
  
  int _totalFocusSeconds = 0;
  Timer? _focusDurationTimer;
  DateTime? _appBackgroundTime;
  bool _cameFromAllowedApp = false;

  final List<Map<String, dynamic>> _allowedApps = [
    {'name': 'Student Life', 'icon': Icons.school, 'url': 'app://student_life'}, 
    {'name': 'Calculator', 'icon': Icons.calculate, 'url': 'https://www.google.com/search?q=calculator'},
    {'name': 'ChatGPT', 'icon': Icons.psychology, 'url': 'https://chatgpt.com'},
    {'name': 'Google', 'icon': Icons.search, 'url': 'https://www.google.com'},
    {'name': 'Phone', 'icon': Icons.phone, 'url': 'tel:'},
    {'name': 'Messages', 'icon': Icons.sms, 'url': 'sms:'},
    {'name': 'PhonePe', 'icon': Icons.account_balance_wallet, 'url': 'phonepe://'}, 
    {'name': 'PDF Reader', 'icon': Icons.picture_as_pdf, 'url': 'https://www.google.com/search?q=pdf+reader+online'},
    {'name': 'Files', 'icon': Icons.folder, 'url': 'content://media/external/file'},
    {'name': 'Gmail', 'icon': Icons.email, 'url': 'mailto:'},
    {'name': 'Photos', 'icon': Icons.photo, 'url': 'content://media/external/images/media'},
  ];

  Future<void> _startLockTask() async {
    try {
      await platform.invokeMethod('startLockTask');
    } catch (e) {
      debugPrint("Error starting lock task: $e");
    }
  }

  Future<void> _stopLockTask() async {
    try {
      await platform.invokeMethod('stopLockTask');
    } catch (e) {
      debugPrint("Error stopping lock task: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedTimes();
    
    // ಸೌಂಡ್ ಬರದೇ ಇರಲು ಟೈಮರ್ ಅನ್ನು 3 ಸೆಕೆಂಡ್ ಬದಲು 5 ಸೆಕೆಂಡಿಗೆ ಇಟ್ಟಿದ್ದೀನಿ
    _timeCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkTimeAndActivate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeCheckTimer?.cancel();
    _focusDurationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final startStr = prefs.getString('focus_start_time');
    final endStr = prefs.getString('focus_end_time');

    if (startStr != null && endStr != null) {
      setState(() {
        _startTime = TimeOfDay(hour: int.parse(startStr.split(':')[0]), minute: int.parse(startStr.split(':')[1]));
        _endTime = TimeOfDay(hour: int.parse(endStr.split(':')[0]), minute: int.parse(endStr.split(':')[1]));
      });
      _checkTimeAndActivate();
    }
  }

  // ಪಕ್ಕಾ ಟೈಮ್ ಕಂಪ್ಯಾರಿಸನ್ ಮತ್ತು ಅಲಾರ್ಮ್ ಸೌಂಡ್ ಫಿಕ್ಸ್ ಮಾಡಿರೋ ಲಾಜಿಕ್ ಇಲ್ಲಿದೆ ಅಕ್ಕ:
  void _checkTimeAndActivate() {
    if (_startTime == null || _endTime == null) return;

    final now = DateTime.now();
    
    // ಇವತ್ತಿನ ದಿನಾಂಕಕ್ಕೆ ಸಮಯವನ್ನು ಮ್ಯಾಚ್ ಮಾಡುವುದು
    final startDateTime = DateTime(now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
    var endDateTime = DateTime(now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);

    // ಒಂದು ವೇಳೆ ಎಂಡ್ ಟೈಮ್ ಮರುದಿನಕ್ಕೆ ಹೋಗಿದ್ದರೆ (ಉದಾಹರಣೆಗೆ 00:29)
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    // ಈಗಿನ ಸಮಯವು ಇವೆರಡರ ಮಧ್ಯೆ ಇದೆಯಾ ಚೆಕ್ ಮಾಡುವುದು
    if (now.isAfter(startDateTime) && now.isBefore(endDateTime)) {
      if (!_isFocusActive) {
        setState(() {
          _isFocusActive = true;
          _totalFocusSeconds = 0;
        });
        _startFocusDurationCounting(); 
      }
    } else {
      // ಫೋಕಸ್ ಮೋಡ್ ಸಮಯ ಮುಗಿದಿದ್ದರೆ ಮಾತ್ರ ಎಕ್ಸಿಟ್ ಮಾಡು
      if (_isFocusActive) {
        _exitFocusRoutine();
      }
    }
  }

  void _startFocusDurationCounting() {
    _startLockTask(); // ಕೇವಲ ಒಂದು ಬಾರಿ ಮಾತ್ರ ಲಾಕ್ ಟಾಸ್ಕ್ ರನ್ ಆಗುತ್ತೆ, ಸೌಂಡ್ ಬರಲ್ಲ!
    _focusDurationTimer?.cancel();
    _focusDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _totalFocusSeconds++;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isFocusActive) return;

    if (state == AppLifecycleState.paused) {
      _appBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _startLockTask(); 
      
      if (_appBackgroundTime != null) {
        final timeSpentOutside = DateTime.now().difference(_appBackgroundTime!).inSeconds;

        if (_cameFromAllowedApp) {
          _totalFocusSeconds += timeSpentOutside;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Unallowed App used! Time NOT counted. ❌"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      _cameFromAllowedApp = false;
    }
  }

  Future<void> _launchAllowedApp(String urlString) async {
    if (urlString == 'app://student_life') {
      await _stopLockTask(); 
      
      if (mounted) {
        setState(() {
          _cameFromAllowedApp = true; 
        });
        
        // ನಿನ್ನ ಫೋಟೋದಲ್ಲಿ ನೋಡಿದ `DashboardPage` ಹೆಸರನ್ನು ಇಲ್ಲಿ ಪಕ್ಕಾ ಹಾಕಿದ್ದೀನಿ ಅಕ್ಕ 🎓
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()), 
        );
        
        _startLockTask(); 
        setState(() {
          _cameFromAllowedApp = false;
        });
      }
      return;
    }
    
    final Uri url = Uri.parse(urlString);
    setState(() {
      _cameFromAllowedApp = true; 
    });
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      setState(() { _cameFromAllowedApp = false; });
    }
  }

  void _exitFocusRoutine() async {
    _focusDurationTimer?.cancel();
    await _saveDataToFirestore(_totalFocusSeconds);
   await _stopLockTask(); 
    if (widget.onExitFocus != null) {
      widget.onExitFocus!(); 
    } else {
      setState(() {
        _isFocusActive = false;
      });
    }
    await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  


  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (isStart) {
          _startTime = picked;
          prefs.setString('focus_start_time', '${picked.hour}:${picked.minute}');
        } else {
          _endTime = picked;
          prefs.setString('focus_end_time', '${picked.hour}:${picked.minute}');
        }
      });
      // ಸಮಯ ಸೆಟ್ ಮಾಡಿದ ತಕ್ಷಣ ಇಲ್ಲೇ ಒಂದು ಬಾರಿ ರನ್ ಮಾಡಿ ಸ್ಕ್ರೀನ್ ಆನ್ ಮಾಡುತ್ತದೆ
      _checkTimeAndActivate();
    }
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return "--:--";
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFocusActive, 
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFocusActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Are you sure you want to exit Focus Mode?,please use the Exit button below! 🚪"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: _isFocusActive ? const Color(0xFFF3F8F7) : Colors.white,
        appBar: !_isFocusActive 
          ? AppBar(
              title: const Text("Set Study Hours", style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF0D9488),
              elevation: 0,
            )
          : null,
        body: _isFocusActive ? _buildFocusUI() : _buildNormalUI(),
      ),
    );
  }

  Widget _buildFocusUI() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text("Focus Mode is active", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "${_formatTimeOfDay(_startTime)} ➔ ${_formatTimeOfDay(_endTime)}",
                  style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Text(
                  "Progress Time: ${(_totalFocusSeconds ~/ 60)}m ${_totalFocusSeconds % 60}s",
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Try the apps below:",
                style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: _allowedApps.length,
                itemBuilder: (context, index) {
                  final app = _allowedApps[index];
                  return InkWell(
                    onTap: () => _launchAllowedApp(app['url']),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))
                            ],
                          ),
                          child: Icon(app['icon'], size: 30, color: const Color(0xFF0D9488)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          app['name'],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Exit Focus Mode?"),
                    content: const Text("Are you sure you want to exit Focus Mode?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _exitFocusRoutine();
                        },
                        child: const Text("Yes, Exit", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text("Exit Focus Mode 🚪", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm_add, size: 70, color: Color(0xFF0D9488)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _selectTime(true),
                  icon: const Icon(Icons.access_time),
                  label: Text("Start: ${_formatTimeOfDay(_startTime)}"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectTime(false),
                  icon: const Icon(Icons.timer_off),
                  label: Text("End: ${_formatTimeOfDay(_endTime)}"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              "set your focus time.\n the app will automatically open the focus screen at the scheduled time.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _saveDataToFirestore(int totalSeconds) async {
  if (totalSeconds < 1) return; 

  try {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('study_hours').add({
      'student_name': 'Prajna', 
      'duration_seconds': totalSeconds,
      'duration_minutes': (totalSeconds / 60).toStringAsFixed(2),
      'completed_at': DateTime.now().toIso8601String(),
    });
    
    print("data saved successfully to firebase firestore 🔥");
  } catch (e) {
    print("error saving data to firestore: $e");
  }
}
}