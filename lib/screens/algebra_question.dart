import 'package:flutter/material.dart';
import 'dart:math';

class AlgebraDecimalGame extends StatefulWidget {
  final Function(bool) onCorrectAnswer;

  const AlgebraDecimalGame({super.key, required this.onCorrectAnswer});

  @override
  State<AlgebraDecimalGame> createState() => _AlgebraDecimalGameState();
}

class _AlgebraDecimalGameState extends State<AlgebraDecimalGame> {
  late double dividend;
  late double divisor;
  bool _completed = false;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _generateProblem();
  }

  void _generateProblem() {
    final random = Random();
    // Generate a divisor with 1 or 2 decimal places (e.g., 0.5, 1.25)
    int decimalPlaces = random.nextBool() ? 1 : 2;
    double rawDivisor = (random.nextInt(90) + 10) / pow(10, decimalPlaces); // 0.10 to 0.99 or similar
    
    // Generate dividend
    double rawDividend = (random.nextInt(1000) + 100) / 10; // 10.0 to 109.9

    setState(() {
      divisor = double.parse(rawDivisor.toStringAsFixed(2));
      dividend = double.parse(rawDividend.toStringAsFixed(2));
      _completed = false;
      _moves = 0;
    });
  }

  void _shiftDecimal() {
    setState(() {
      dividend = double.parse((dividend * 10).toStringAsFixed(2));
      divisor = double.parse((divisor * 10).toStringAsFixed(2));
      _moves++;
    });

    // Check if divisor is whole number
    if (divisor % 1 == 0) {
      setState(() {
        _completed = true;
      });
      // Delay slightly before proceeding
      Future.delayed(const Duration(seconds: 1), () {
        widget.onCorrectAnswer(true); // Always true for this interactive type? Or maybe track mistakes?
        // Assuming interactive manipulation is "correct" once achieved.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "تخلص من الفواصل في المقسوم عليه",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            "اضغط على الزر لتحريك الفاصلة حتى يصبح المقسوم عليه عدداً صحيحاً",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNumberBox(dividend, label: "المقسوم"),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text("÷", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              ),
              _buildNumberBox(divisor, label: "المقسوم عليه", isTarget: true),
            ],
          ),

          const SizedBox(height: 40),

          if (!_completed)
            ElevatedButton.icon(
              onPressed: _shiftDecimal,
              icon: const Icon(Icons.arrow_forward),
              label: const Text("حرك الفاصلة (×10)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            )
          else
            Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 10),
                const Text("أحسنت!", style: TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildNumberBox(double num, {String? label, bool isTarget = false}) {
    // Format to remove trailing .0 if integer
    String text = num.toString();
    if (text.endsWith(".0")) text = text.substring(0, text.length - 2);

    return Column(
      children: [
        if (label != null) Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: isTarget && text.contains(".") ? Colors.orange[50] : Colors.white,
            border: Border.all(
              color: isTarget && text.contains(".") ? Colors.orange : Colors.grey,
              width: 2
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(2, 2))
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
          ),
        ),
      ],
    );
  }
}