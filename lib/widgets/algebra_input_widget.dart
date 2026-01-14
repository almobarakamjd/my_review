import 'package:flutter/material.dart';

enum AlgebraOperation { addition, subtraction, multiplication, division }

class AlgebraInputWidget extends StatefulWidget {
  final double num1;
  final double num2;
  final AlgebraOperation operation;
  final Function(bool isCorrect, String correctAnswer) onAnswer;

  const AlgebraInputWidget({
    super.key,
    required this.num1,
    required this.num2,
    required this.operation,
    required this.onAnswer,
  });

  @override
  State<AlgebraInputWidget> createState() => _AlgebraInputWidgetState();
}

class _AlgebraInputWidgetState extends State<AlgebraInputWidget> {
  late double _displayNum1;
  late double _displayNum2;
  bool _divisionReadyToSolve = true;
  
  List<String> _userDigits = [];
  int _decimalIndex = -1; 
  
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _displayNum1 = widget.num1;
    _displayNum2 = widget.num2;
    _checkDivisionStatus();
  }

  @override
  void didUpdateWidget(AlgebraInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.num1 != oldWidget.num1 || widget.num2 != oldWidget.num2 || widget.operation != oldWidget.operation) {
      _displayNum1 = widget.num1;
      _displayNum2 = widget.num2;
      _userDigits = [];
      _decimalIndex = -1;
      _isSubmitted = false;
      _checkDivisionStatus();
    }
  }

  void _checkDivisionStatus() {
    if (widget.operation == AlgebraOperation.division) {
      if ((_displayNum2 % 1).abs() > 0.0001) {
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

  void _addDigit(String digit) {
    if (_isSubmitted || (! _divisionReadyToSolve && widget.operation == AlgebraOperation.division)) return;
    setState(() {
      _userDigits.add(digit);
    });
  }

  void _backspace() {
    if (_isSubmitted || (! _divisionReadyToSolve && widget.operation == AlgebraOperation.division)) return;
    setState(() {
      if (_userDigits.isNotEmpty) {
        if (_decimalIndex == _userDigits.length) _decimalIndex = -1;
        if (_decimalIndex > _userDigits.length - 1) _decimalIndex = -1;
        _userDigits.removeLast();
      }
    });
  }

  void _toggleDecimal(int index) {
    if (_isSubmitted || (! _divisionReadyToSolve && widget.operation == AlgebraOperation.division)) return;
    setState(() {
      if (_decimalIndex == index) {
        _decimalIndex = -1;
      } else {
        _decimalIndex = index;
      }
    });
  }

  void _submit() {
    if (_userDigits.isEmpty) return;
    
    String resultStr = "";
    for (int i = 0; i < _userDigits.length; i++) {
      if (i == _decimalIndex) resultStr += ".";
      resultStr += _userDigits[i];
    }
    if (_decimalIndex == _userDigits.length) resultStr += ".";

    double? userVal = double.tryParse(resultStr);
    if (userVal == null) return;

    double correctVal;
    switch (widget.operation) {
      case AlgebraOperation.addition: correctVal = widget.num1 + widget.num2; break;
      case AlgebraOperation.subtraction: correctVal = widget.num1 - widget.num2; break;
      case AlgebraOperation.multiplication: correctVal = widget.num1 * widget.num2; break;
      case AlgebraOperation.division: correctVal = widget.num1 / widget.num2; break;
    }

    // Floating point comparison
    bool correct = (userVal - correctVal).abs() < 0.001;
    
    String correctStr = correctVal.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");

    setState(() {
      _isSubmitted = true;
    });

    widget.onAnswer(correct, correctStr);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Problem Display
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]
          ),
          child: widget.operation == AlgebraOperation.division 
            ? _buildDivisionLayout()
            : _buildVerticalLayout(),
        ),

        const SizedBox(height: 20),
        
        // Division Helper Button
        if (widget.operation == AlgebraOperation.division && !_divisionReadyToSolve)
           Directionality(
             textDirection: TextDirection.rtl,
             child: ElevatedButton.icon(
               onPressed: _shiftDecimals,
               icon: const Icon(Icons.transform),
               label: const Text("تخلص من الفاصلة (×10)"),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.orange,
                 foregroundColor: Colors.white,
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
               ),
             ),
           ),

        const SizedBox(height: 20),

        // Keypad
        _buildKeypad(),
      ],
    );
  }

  Widget _buildVerticalLayout() {
    final style = const TextStyle(fontSize: 32, fontFamily: 'Courier', fontWeight: FontWeight.bold);
    
    String opSymbol = "";
    if (widget.operation == AlgebraOperation.addition) opSymbol = "+";
    if (widget.operation == AlgebraOperation.subtraction) opSymbol = "-";
    if (widget.operation == AlgebraOperation.multiplication) opSymbol = "×";

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
                Text(widget.num1.toString(), style: style),
                Row(
                  children: [
                     Text(opSymbol, style: const TextStyle(fontSize: 28, color: Colors.grey)),
                     const SizedBox(width: 10),
                     Text(widget.num2.toString(), style: style),
                  ],
                ),
                Container(height: 3, width: 140, color: Colors.black),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
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
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(" ${_displayNum2.toString()} ", style: style),
            ),
            CustomPaint(
              painter: DivisionPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
                child: Text(" ${_displayNum1.toString()} ", style: style),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text("الناتج:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildInputRow(),
      ],
    );
  }

  Widget _buildInputRow() {
    if (_userDigits.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 2), 
            borderRadius: BorderRadius.circular(10)
          ),
          child: const Text("?", style: TextStyle(fontSize: 24, color: Colors.grey)),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        // Always show leading toggle zone (Hidden Space)
        _buildHiddenSpace(0),
        
        for (int i = 0; i < _userDigits.length; i++) ...[
          Text(_userDigits[i], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          _buildHiddenSpace(i + 1),
        ]
      ],
    );
  }

  Widget _buildHiddenSpace(int index) {
    return GestureDetector(
      onTap: () => _toggleDecimal(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30, // Clickable area width
        height: 50,
        alignment: Alignment.bottomCenter,
        color: Colors.transparent, // Completely hidden
        child: _decimalIndex == index
            ? const Text(".", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, height: 0.5, color: Colors.blue))
            : const SizedBox(width: 30, height: 50), // Empty space
      ),
    );
  }

  Widget _buildKeypad() {
    bool enabled = !(_isSubmitted) && !(_divisionReadyToSolve == false && widget.operation == AlgebraOperation.division);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!)
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
                 child: SizedBox(
                   width: 65, height: 65,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.red[100],
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                       elevation: 0,
                       padding: EdgeInsets.zero
                     ),
                     onPressed: enabled ? _backspace : null,
                     child: const Icon(Icons.backspace_outlined, color: Colors.red, size: 28),
                   ),
                 ),
               ),
               Padding(
                 padding: const EdgeInsets.all(4),
                 child: SizedBox(
                   width: 65, height: 65,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.green,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                       elevation: 2,
                       padding: EdgeInsets.zero
                     ),
                     onPressed: enabled ? _submit : null,
                     child: const Icon(Icons.check, color: Colors.white, size: 36),
                   ),
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
      padding: const EdgeInsets.all(6.0),
      child: SizedBox(
        width: 65, height: 65,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 2,
            shadowColor: Colors.grey.withOpacity(0.3),
          ),
          onPressed: enabled ? () => _addDigit(val) : null,
          child: Text(val, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class DivisionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Adjusted for better alignment with text
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.5, 0, 5); // Curved left side
    path.lineTo(size.width + 10, 5); // Top line

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}