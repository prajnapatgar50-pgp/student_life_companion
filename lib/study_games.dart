import 'package:flutter/material.dart';
import 'dart:math';

class StudyGamesPage extends StatefulWidget {
  const StudyGamesPage({super.key});

  @override
  State<StudyGamesPage> createState() => _StudyGamesPageState();
}

class _StudyGamesPageState extends State<StudyGamesPage> {
  late int num1, num2;
  late String operator;
  late double correctDisplayAnswer;
  int score = 0;
  final TextEditingController _answerController = TextEditingController();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    List<String> operators = ['+', '-', '×', '÷', '%', '√'];
    operator = operators[_random.nextInt(operators.length)];

    if (operator == '√') {
      int base = _random.nextInt(10) + 2; 
      num1 = base * base; 
      correctDisplayAnswer = base.toDouble();
    } else if (operator == '÷') {
      num2 = _random.nextInt(9) + 1;
      num1 = num2 * (_random.nextInt(10) + 1);
      correctDisplayAnswer = num1 / num2;
    } else if (operator == '%') {
      num1 = _random.nextInt(50) + 10;
      num2 = _random.nextInt(9) + 2;
      correctDisplayAnswer = (num1 % num2).toDouble();
    } else {
      num1 = _random.nextInt(20) + 1;
      num2 = _random.nextInt(20) + 1;
      if (operator == '+') correctDisplayAnswer = (num1 + num2).toDouble();
      if (operator == '-') correctDisplayAnswer = (num1 - num2).toDouble();
      if (operator == '×') correctDisplayAnswer = (num1 * num2).toDouble();
    }
    setState(() {});
  }

  void checkAnswer() {
    double? userAnswer = double.tryParse(_answerController.text);
    if (userAnswer != null && (userAnswer - correctDisplayAnswer).abs() < 0.1) {
      setState(() {
        score++;
        _answerController.clear();
        generateQuestion();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Correct! 🎉"), duration: Duration(milliseconds: 500), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong! Try again. ❌"), duration: Duration(milliseconds: 500), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String questionText = (operator == '√') ? "√$num1 = ?" : "$num1 $operator $num2 = ?";

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      resizeToAvoidBottomInset: true, 
      appBar: AppBar(
        title: const Text("Math Study Game"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView( 
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 50.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Score: $score", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 50),
              const Text("Solve this Challenge:", style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 15),
              Text(
                questionText,
                style: const TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _answerController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Enter your answer",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Submit Answer", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}