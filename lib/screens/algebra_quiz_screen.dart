import 'package:flutter/material.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

enum Operation { addition, subtraction, multiplication, division }

class AlgebraQuiz extends StatefulWidget {
  final void Function(bool firstTry) onCorrectAnswer;

  const AlgebraQuiz({super.key, required this.onCorrectAnswer});

  @override
  State<AlgebraQuiz> createState() => _AlgebraQuizState();
}

class _AlgebraQuizState extends State<AlgebraQuiz> {
  late Operation _operation;
  late double _num1;
  late double _num2;
  
  // For Division shifting logic
  late double _displayNum1; // Dividend (starts as _num1)
  late double _displayNum2; // Divisor (starts as _num2)
  bool _divisionReadyToSolve = true; // False if divisor has decimals

  // User Input State
  List<String> _userDigits = [];
  int _decimalIndex = -1; // -1: No decimal. 0: Before 1st digit. 1: After 1st digit...
  
  final Random _random = Random();
  String _message = "";
  bool _isCorrect = false;
  int _attempts = 0;
  
  // Quiz Flow State
  int _questionsAnswered = 0;
  int _score = 0;
  bool _quizCompleted = false;
  double _correctDelay = 2.0;
  double _wrongDelay = 4.0;

  @override
  void initState() {
    super.initState();
    _generateQuestion();
  }

  void _generateQuestion() {
    setState(() {
      _userDigits = [];
      _decimalIndex = -1;
      _message = "";
      _isCorrect = false;
      _attempts = 0;
      
      _operation = Operation.values[_random.nextInt(Operation.values.length)];

      // Helper to get random double with specific decimal places
      double randomVal(int max, int decimals) {
        double val = _random.nextDouble() * max;
        return double.parse(val.toStringAsFixed(decimals));
      }

      switch (_operation) {
        case Operation.addition:
        case Operation.subtraction:
          _num1 = randomVal(100, _random.nextInt(3)); // 0, 1, or 2 decimals
          _num2 = randomVal(100, _random.nextInt(3));
          if (_operation == Operation.subtraction && _num1 < _num2) {
            final temp = _num1; _num1 = _num2; _num2 = temp;
          }
          break;
        case Operation.multiplication:
          _num1 = randomVal(20, 1); // Keep numbers smaller for multiply
          _num2 = randomVal(10, 1);
          break;
        case Operation.division:
          // Generate a clean division problem
          double quotient = randomVal(15, 1);
          double divisor = randomVal(10, 1);
          if (divisor == 0) divisor = 1;
          
          _num2 = divisor;
          _num1 = double.parse((quotient * divisor).toStringAsFixed(2));
          break;
      }
      
      _displayNum1 = _num1;
      _displayNum2 = _num2;
      _checkDivisionStatus();
    });
  }

  void _checkDivisionStatus() {
    if (_operation == Operation.division) {
      if (_displayNum2 % 1 != 0) {
        _divisionReadyToSolve = false;
      } else {
        _divisionReadyToSolve = true;
      }
    } else {
      _divisionReadyToSolve = true;
    }
  }

  void _shiftDecimals() {
    setState(() {
      _displayNum1 = double.parse((_displayNum1 * 10).toStringAsFixed(2));
      _displayNum2 = double.parse((_displayNum2 * 10).toStringAsFixed(2));
      _checkDivisionStatus();
    });
  }

  // --- Input Logic ---

  void _addDigit(String digit) {
    if (_isCorrect || (!_divisionReadyToSolve && _operation == Operation.division)) return;
    setState(() {
      _userDigits.add(digit);
    });
  }

  void _backspace() {
    if (_isCorrect || (!_divisionReadyToSolve && _operation == Operation.division)) return;
    setState(() {
      if (_userDigits.isNotEmpty) {
        if (_decimalIndex == _userDigits.length) {
          _decimalIndex = -1;
        }
        if (_decimalIndex > _userDigits.length - 1) {
             _decimalIndex = -1; 
        }
        _userDigits.removeLast();
      }
    });
  }

  void _toggleDecimal(int index) {
    if (_isCorrect || (!_divisionReadyToSolve && _operation == Operation.division)) return;
    
    setState(() {
      if (_decimalIndex == index) {
        _decimalIndex = -1;
      } else {
        _decimalIndex = index;
      }
    });
  }

  double _calculateCorrectAnswer() {
    switch (_operation) {
      case Operation.addition: return _num1 + _num2;
      case Operation.subtraction: return _num1 - _num2;
      case Operation.multiplication: return _num1 * _num2;
      case Operation.division: return _num1 / _num2;
    }
  }

  Future<void> _checkAnswer() async {
    if (_userDigits.isEmpty) return;
    
    String resultStr = "";
    for (int i = 0; i < _userDigits.length; i++) {
      if (i == _decimalIndex) resultStr += ".";
      resultStr += _userDigits[i];
    }
    if (_decimalIndex == _userDigits.length) resultStr += ".";

    double? userVal = double.tryParse(resultStr);
    if (userVal == null) return;

    double correctVal = _calculateCorrectAnswer();
    
    // Allow small margin for floating point errors
    bool correct = (userVal - correctVal).abs() < 0.001;

    // Show Dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Auto close logic
        Future.delayed(Duration(milliseconds: (correct ? (_correctDelay * 1000).toInt() : (_wrongDelay * 1000).toInt())), () {
          if (ctx.mounted && Navigator.canPop(ctx)) {
            Navigator.pop(ctx);
          }
        });

        return AlertDialog(
          backgroundColor: correct ? Colors.green[50] : Colors.red[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                correct ? Icons.check_circle : Icons.cancel,
                color: correct ? Colors.green : Colors.red,
                size: 60,
              ),
              const SizedBox(height: 15),
              Text(
                correct ? "إجابة صحيحة!" : "إجابة خاطئة!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: correct ? Colors.green[800] : Colors.red[800],
                ),
              ),
              if (!correct) ...[
                const SizedBox(height: 10),
                const Text("الإجابة الصحيحة هي:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  correctVal.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0)(?!.*\d)"), ""), // Remove trailing zeros
                  style: const TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold)
                ),
              ]
            ],
          ),
        );
      },
    );

    setState(() {
      _isCorrect = correct;
      if (correct) {
         _score++;
         _questionsAnswered++;
         if (_questionsAnswered >= 10) {
           _quizCompleted = true;
         } else {
           // Auto advance logic or wait for "Next" button? 
           // User usually prefers "Next" button in Algebra usually to see the result, 
           // but "Balloon" implies feedback then move on.
           // However, let's keep the "Next Question" button for explicit flow 
           // OR auto-generate if correct.
           // Let's stick to explicit button or auto after delay if user prefers.
           // The code below adds a button if correct.
         }
      } else {
         _attempts++;
         // If wrong, do we move on?
         // Usually with random questions, we might want them to retry or fail.
         // "Show correct answer in red balloon" implies we gave them the answer, so maybe move on?
         // Or let them type it in?
         // Let's count it as answered but wrong, and move on.
         _questionsAnswered++;
         if (_questionsAnswered >= 10) _quizCompleted = true;
         
         // Force move next or let them see? 
         // Since we showed the answer, let's auto-generate next question after dialog closes?
         // Or show "Next" button.
         _isCorrect = true; // Mark as "done" so they can't edit, but they didn't get point.
      }
    });
  }
  
  void _nextQuestion() {
    if (_quizCompleted) return;
    _generateQuestion();
  }

  Future<void> _launchMadrasati() async {
    const url = 'https://madrasati.sa';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quizCompleted) return _buildResultScreen();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text("السؤال: ${_questionsAnswered + 1}/10", style: const TextStyle(fontWeight: FontWeight.bold)),
               Text("النقاط: $_score", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Instructions
          Text(
            _getInstructionText(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
          ),
          const SizedBox(height: 30),

          // Problem Display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10)]
            ),
            child: _operation == Operation.division 
              ? _buildDivisionLayout()
              : _buildVerticalLayout(),
          ),

          const SizedBox(height: 20),
          
          // Division Helper Button
          if (_operation == Operation.division && !_divisionReadyToSolve)
             ElevatedButton.icon(
               onPressed: _shiftDecimals,
               icon: const Icon(Icons.transform),
               label: const Text("تخلص من الفاصلة (×10)"),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.orange,
                 foregroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
               ),
             ),

          const SizedBox(height: 20),

          // Keypad
          _buildKeypad(),
          
          const SizedBox(height: 20),

          // Next Button (Only if question "processed" i.e. correct or wrong-shown)
          if (_isCorrect) // reusing _isCorrect flag to mean "Done with this question"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16)
                ),
                child: const Text("السؤال التالي", style: TextStyle(fontSize: 18)),
              ),
            ),
            
           const SizedBox(height: 20),
           
           // Settings & Madrasati
           Card(
             child: Padding(
               padding: const EdgeInsets.all(8.0),
               child: Column(
                 children: [
                   if (_questionsAnswered >= 4)
                     Padding(
                       padding: const EdgeInsets.only(bottom: 8.0),
                       child: SizedBox(
                         width: double.infinity,
                         child: ElevatedButton.icon(
                           icon: const Icon(Icons.school),
                           label: const Text("الانتقال إلى مدرستي"),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.green,
                             foregroundColor: Colors.white,
                           ),
                           onPressed: _launchMadrasati,
                         ),
                       ),
                     ),
                    const Text("مدة البالون (ثواني):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildSliderRow("عند الصحة", _correctDelay, 1, 10, Colors.green, (v) => setState(() => _correctDelay = v)),
                    _buildSliderRow("عند الخطأ", _wrongDelay, 3, 10, Colors.red, (v) => setState(() => _wrongDelay = v)),
                 ],
               ),
             ),
           )
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, double val, double min, double max, Color color, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(
          child: SizedBox(
            height: 30,
            child: Slider(
              value: val,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              label: val.toInt().toString(),
              activeColor: color,
              onChanged: onChanged,
            ),
          ),
        ),
        Text("${val.toInt()} ث", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
  
  Widget _buildResultScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              "انتهى التدريب!",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            Text(
              "نتيجتك: $_score / 10",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.school),
                label: const Text("الانتقال إلى مدرستي"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _launchMadrasati,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _questionsAnswered = 0;
                  _score = 0;
                  _quizCompleted = false;
                  _generateQuestion();
                });
              },
              child: const Text("إعادة التدريب", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  String _getInstructionText() {
    if (_operation == Operation.division) {
      if (!_divisionReadyToSolve) return "اضرب المقسوم والمقسوم عليه في 10 للتخلص من فاصلة المقسوم عليه.";
      return "الآن اقسم العددين. اضغط بين الأرقام لوضع الفاصلة.";
    }
    return "حل المسألة. اضغط في الفراغ بين الأرقام لوضع الفاصلة العشرية.";
  }

  // --- Layouts ---

  Widget _buildVerticalLayout() {
    final style = const TextStyle(fontSize: 32, fontFamily: 'Courier', fontWeight: FontWeight.bold);
    
    String opSymbol = "";
    if (_operation == Operation.addition) opSymbol = "+";
    if (_operation == Operation.subtraction) opSymbol = "-";
    if (_operation == Operation.multiplication) opSymbol = "×";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_num1.toString(), style: style),
                Row(
                  children: [
                     Text(opSymbol, style: const TextStyle(fontSize: 28, color: Colors.grey)),
                     const SizedBox(width: 10),
                     Text(_num2.toString(), style: style),
                  ],
                ),
                Container(height: 3, width: 120, color: Colors.black),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Answer Input Area
        _buildInputRow(),
      ],
    );
  }

  Widget _buildDivisionLayout() {
    final style = const TextStyle(fontSize: 28, fontFamily: 'Courier', fontWeight: FontWeight.bold);
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Divisor (Left/Outside)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(" ${_displayNum2.toString()} ", style: style),
            ),
            // Bracket & Dividend
            CustomPaint(
              painter: DivisionPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
                child: Column(
                  children: [
                    Text(" ${_displayNum1.toString()} ", style: style),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text("الناتج:", style: TextStyle(fontSize: 18)),
        const SizedBox(height: 5),
        _buildInputRow(),
      ],
    );
  }

  Widget _buildInputRow() {
    // Displays user digits with clickable gaps
    if (_userDigits.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
        child: const Text("?", style: TextStyle(fontSize: 24, color: Colors.grey)),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i <= _userDigits.length; i++) ...[
          GestureDetector(
            onTap: () => _toggleDecimal(i),
            child: Container(
              width: 20,
              height: 40,
              color: Colors.transparent, // Hit box
              alignment: Alignment.bottomCenter,
              child: _decimalIndex == i 
                  ? const Text(".", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, height: 1))
                  : Container(
                      width: 4, 
                      height: 4, 
                      decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)
                    ),
            ),
          ),
          
          if (i < _userDigits.length)
            Text(_userDigits[i], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }

  // --- Keypad ---
  Widget _buildKeypad() {
    bool enabled = !(_operation == Operation.division && !_divisionReadyToSolve) && !_isCorrect;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int row = 0; row < 3; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int col = 1; col <= 3; col++)
                  _buildKey((row * 3 + col).toString(), enabled),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
               _buildKey("0", enabled),
               Padding(
                 padding: const EdgeInsets.all(4),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.red[100],
                     shape: const CircleBorder(),
                     padding: const EdgeInsets.all(16)
                   ),
                   onPressed: enabled ? _backspace : null,
                   child: const Icon(Icons.backspace, color: Colors.red),
                 ),
               ),
               Padding(
                 padding: const EdgeInsets.all(4),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.green,
                     shape: const CircleBorder(),
                     padding: const EdgeInsets.all(16)
                   ),
                   onPressed: enabled ? _checkAnswer : null,
                   child: const Icon(Icons.check, color: Colors.white),
                 ),
               ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildKey(String val, bool enabled) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(20),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 2,
        ),
        onPressed: enabled ? () => _addDigit(val) : null,
        child: Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class DivisionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(8, size.height * 0.6, 0, 0);
    path.lineTo(size.width + 10, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}