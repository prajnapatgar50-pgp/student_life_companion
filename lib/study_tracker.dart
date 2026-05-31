import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudyTrackerPage extends StatefulWidget {
  const StudyTrackerPage({super.key});

  @override
  State<StudyTrackerPage> createState() => _StudyTrackerPageState();
}

class _StudyTrackerPageState extends State<StudyTrackerPage> {
  List<double> weeklyData = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  @override
  void initState() {
    super.initState();
    _getSavedHours(); 
  }

  Future<void> _getSavedHours() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Fetches study hours data directly from Firebase Firestore
      final snapshot = await firestore
          .collection('study_hours')
          .where('student_name', isEqualTo: 'Prajna')
          .get();

      List<double> firebaseWeeklyHours = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['completed_at'] != null && data['duration_seconds'] != null) {
          DateTime completedDate = DateTime.parse(data['completed_at']);
          int seconds = data['duration_seconds'] as int;
          double hours = seconds / 3600; // Converts seconds to hours for graph

          // Find the weekday index (Sun=0, Mon=1, ..., Sat=6)
          int graphIndex = (completedDate.weekday == 7) ? 0 : completedDate.weekday;
          
          // Sum up the hours for that specific day
          firebaseWeeklyHours[graphIndex] += hours;
        }
      }

      setState(() {
        weeklyData = firebaseWeeklyHours;
      });
      
      print("Weekly study tracker data synced from Firebase successfully! 📊");
    } catch (e) {
      print("Error fetching study tracker data from Firestore: $e");
      
      // Fallback to local memory if internet or Firebase fails
      final prefs = await SharedPreferences.getInstance();
      List<String>? storedHours = prefs.getStringList('weekly_study_hours');
      if (storedHours != null) {
        setState(() {
          weeklyData = storedHours.map((h) => double.parse(h)).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int weekday = DateTime.now().weekday; 
    int todayIndex = (weekday == 7) ? 0 : weekday; 
    
    double todayHours = (weeklyData.isNotEmpty && todayIndex < weeklyData.length) 
        ? weeklyData[todayIndex] 
        : 0.0;
        
    int hours = todayHours.toInt();
    int minutes = ((todayHours - hours) * 60).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF1E2124), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              "$hours hr, $minutes min", 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 45, 
                fontWeight: FontWeight.bold, 
                fontFamily: 'Serif'
              )
            ),
            const Text(
              "Today", 
              style: TextStyle(color: Colors.grey, fontSize: 18, fontFamily: 'Serif')
            ),
            const SizedBox(height: 60),
            
            SizedBox(
              height: 300, 
              child: BarChart(
                BarChartData(
                  maxY: weeklyData.reduce((a, b) => a > b ? a : b) > 8 ? weeklyData.reduce((a, b) => a > b ? a : b) + 2 : 8,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2, 
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withAlpha(30), 
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) => Text(
                          "${value.toInt()}h", 
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 14, 
                            fontStyle: FontStyle.italic
                          )
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45, 
                        getTitlesWidget: (value, meta) {
                          const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                          int index = value.toInt() % 7;
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              days[index], 
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 13, 
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold
                              )
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withAlpha(30), width: 1),
                    ),
                  ),
                  barGroups: List.generate(weeklyData.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: weeklyData[i] > 8 ? 8 : weeklyData[i], 
                          color: i == todayIndex ? const Color(0xFF81D4FA) : Colors.white10, 
                          width: 22,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}