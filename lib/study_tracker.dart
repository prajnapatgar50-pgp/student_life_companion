import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final prefs = await SharedPreferences.getInstance();
    List<String>? storedHours = prefs.getStringList('weekly_study_hours');
    if (storedHours != null) {
      List<double> mainHours = storedHours.map((h) => double.parse(h)).toList();
      
      setState(() {
        weeklyData = [
          mainHours[0], // Sun
          mainHours[1], // Mon
          mainHours[2], // Tue
          mainHours[3], // Wed
          mainHours[4], // Thu
          mainHours[5], // Fri
          mainHours[6], // Sat
        ];
      });
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
                  maxY: 8, 
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