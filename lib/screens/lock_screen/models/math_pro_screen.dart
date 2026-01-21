import 'package:flutter/material.dart';
import 'borrow_state.dart';
import 'input_focus.dart';

class MathProScreen extends StatefulWidget {
  final String questionText;
  final String correctAnswer;
  final Function(String) onSubmit;

  const MathProScreen({
    super.key,
    required this.questionText,
    required this.correctAnswer,
    required this.onSubmit,
  });

  @override
  State<MathProScreen> createState() => _MathProScreenState();
}

class _MathProScreenState extends State<MathProScreen> {
  List<int> _topDigits = [];
  List<int> _bottomDigits = [];
  String _operator = "+";

  final Map<int, BorrowState> _borrowStates = {};

  List<String> _carryInputs = [];
  List<String> _resultInputs = [];
  List<List<String>> _multiplicationRows = [];

  InputFocus _currentFocus = InputFocus(section: 2, rowIndex: 0, colIndex: 0);
  int _totalCols = 4;
  final double _cellSize = 55.0;

  @override
  void initState() {
    super.initState();
    _parseQuestion();
  }

  @override
  void didUpdateWidget(covariant MathProScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionText != widget.questionText) {
      _borrowStates.clear();
      _parseQuestion();
    }
  }

  void _parseQuestion() {
    final regex = RegExp(r'([\d\.]+)\s*([+\-×÷xX*\/])\s*([\d\.]+)');
    final match = regex.firstMatch(widget.questionText.replaceAll('،', '.'));

    if (match != null) {
      String rawOp1 = match.group(1)!.split('.')[0];
      String rawOp2 = match.group(3)!.split('.')[0];
      String opSymbol = match.group(2)!;

      if (opSymbol == '*' || opSymbol.toUpperCase() == 'X') {
        _operator = '×';
      } else if (opSymbol == '/') {
        _operator = '÷';
      } else {
        _operator = opSymbol;
      }

      _topDigits = rawOp1.split('').map(int.parse).toList().reversed.toList();
      _bottomDigits = rawOp2
          .split('')
          .map(int.parse)
          .toList()
          .reversed
          .toList();

      int maxDigits = _topDigits.length > _bottomDigits.length
          ? _topDigits.length
          : _bottomDigits.length;

      if (_operator == '×') {
        _totalCols = _topDigits.length + _bottomDigits.length;
      } else {
        _totalCols = maxDigits + 1;
      }

      _carryInputs = List.filled(_totalCols, "");

      if (_operator == '×') {
        _multiplicationRows = List.generate(
          _bottomDigits.length,
          (index) => List.filled(_totalCols, ""),
        );
        _resultInputs = List.filled(_totalCols, "");
        _currentFocus = InputFocus(section: 1, rowIndex: 0, colIndex: 0);
      } else {
        _multiplicationRows = [];
        _resultInputs = List.filled(_totalCols, "");
        _currentFocus = InputFocus(section: 2, rowIndex: 0, colIndex: 0);
      }
    }
    setState(() {});
  }

  void _handleBorrowTap(int colIndex) {
    if (_operator != '-') return;
    if (colIndex >= _topDigits.length - 1) return;

    int neighborIndex = colIndex + 1;
    int neighborVal =
        _borrowStates[neighborIndex]?.newValue ?? _topDigits[neighborIndex];

    if (neighborVal > 0) {
      setState(() {
        BorrowState oldNeighborState =
            _borrowStates[neighborIndex] ?? BorrowState();
        _borrowStates[neighborIndex] = BorrowState(
          isBorrowedFrom: true,
          newValue: neighborVal - 1,
          isReceived: oldNeighborState.isReceived,
          receivedValue: oldNeighborState.receivedValue,
        );

        int currentVal = _topDigits[colIndex];
        BorrowState oldSelfState = _borrowStates[colIndex] ?? BorrowState();

        _borrowStates[colIndex] = BorrowState(
          isBorrowedFrom: oldSelfState.isBorrowedFrom,
          newValue: oldSelfState.newValue != 0
              ? oldSelfState.newValue
              : currentVal,
          isReceived: true,
          receivedValue: currentVal + 10,
        );
      });
    }
  }

  void _handleInput(String val) {
    setState(() {
      List<String> targetList;
      if (_currentFocus.section == 0) {
        targetList = _carryInputs;
      } else if (_currentFocus.section == 1) {
        targetList = _multiplicationRows[_currentFocus.rowIndex];
      } else {
        targetList = _resultInputs;
      }

      if (_currentFocus.colIndex < targetList.length) {
        targetList[_currentFocus.colIndex] = val;
      }
    });
  }

  void _backspace() {
    setState(() {
      List<String> targetList = _currentFocus.section == 0
          ? _carryInputs
          : (_currentFocus.section == 1
                ? _multiplicationRows[_currentFocus.rowIndex]
                : _resultInputs);
      if (_currentFocus.colIndex < targetList.length) {
        targetList[_currentFocus.colIndex] = "";
      }
    });
  }

  void _checkAnswer() {
    String ans = _resultInputs.reversed.join('').replaceAll(RegExp(r'^0+'), '');
    if (ans.isEmpty) ans = "0";
    widget.onSubmit(ans);
  }

  @override
  Widget build(BuildContext context) {
    List<int> columnIndices = List.generate(
      _totalCols,
      (i) => (_totalCols - 1) - i,
    );

    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_operator != '-') ...[
                      _buildGridRow(
                        columnIndices,
                        (colIdx) => _buildCarryCell(colIdx),
                      ),
                      const SizedBox(height: 5),
                    ],

                    _buildGridRow(
                      columnIndices,
                      (colIdx) => _buildTopDigitCell(colIdx),
                    ),

                    _buildGridRow(
                      columnIndices,
                      (colIdx) => _buildBottomDigitCell(colIdx),
                      showOp: true,
                    ),

                    Container(
                      height: 4,
                      width: _totalCols * _cellSize,
                      color: Colors.black,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                    ),

                    if (_multiplicationRows.isNotEmpty) ...[
                      for (int i = 0; i < _multiplicationRows.length; i++) ...[
                        _buildGridRow(columnIndices, (colIdx) {
                          int shiftedIndex = colIdx - i;
                          if (shiftedIndex < 0) return const SizedBox();
                          return _buildInputCell(
                            _multiplicationRows[i],
                            1,
                            i,
                            shiftedIndex,
                            Colors.orange.shade50,
                          );
                        }),
                      ],
                      Container(
                        height: 2,
                        width: _totalCols * _cellSize,
                        color: Colors.black54,
                      ),
                    ],

                    _buildGridRow(
                      columnIndices,
                      (colIdx) => _buildInputCell(
                        _resultInputs,
                        2,
                        0,
                        colIdx,
                        Colors.blue.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(flex: 4, child: _buildNumpad()),
      ],
    );
  }

  Widget _buildGridRow(
    List<int> cols,
    Widget Function(int) cellBuilder, {
    bool showOp = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showOp)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              _operator,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ),
        ...cols.map(
          (colIdx) => Container(
            width: _cellSize,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            child: cellBuilder(colIdx),
          ),
        ),
      ],
    );
  }

  Widget _buildCarryCell(int colIdx) {
    if (colIdx == 0) return const SizedBox();
    return GestureDetector(
      onTap: () => setState(
        () => _currentFocus = InputFocus(
          section: 0,
          rowIndex: 0,
          colIndex: colIdx,
        ),
      ),
      child: Container(
        width: 35,
        height: 35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _currentFocus.matches(0, 0, colIdx)
              ? Colors.red.shade50
              : Colors.white,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _carryInputs[colIdx],
          style: const TextStyle(
            fontSize: 20,
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 👇👇 الدالة المصححة 👇👇
  Widget _buildTopDigitCell(int colIdx) {
    if (colIdx >= _topDigits.length) return const SizedBox();

    int originalDigit = _topDigits[colIdx];
    BorrowState? state = _borrowStates[colIdx];

    bool crossed = state?.isBorrowedFrom ?? false;
    int newDigit = state?.newValue ?? originalDigit;
    bool received = state?.isReceived ?? false;
    int? receivedVal = state?.receivedValue;

    return GestureDetector(
      onTap: () => _handleBorrowTap(colIdx),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Text(
            originalDigit.toString(),
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.black,
              decoration: crossed ? TextDecoration.lineThrough : null,
              decorationColor: Colors.red,
              decorationThickness: 3,
            ),
          ),
          if (crossed)
            Positioned(
              top: -25,
              child: Text(
                newDigit.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (received && receivedVal != null)
            Positioned(
              top: -25,
              right: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  receivedVal.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomDigitCell(int colIdx) {
    if (colIdx >= _bottomDigits.length) return const SizedBox();
    return Text(
      _bottomDigits[colIdx].toString(),
      style: const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
  }

  Widget _buildInputCell(
    List<String> dataList,
    int section,
    int rowIdx,
    int colIdx,
    Color bg,
  ) {
    if (colIdx >= dataList.length) return const SizedBox();

    bool isActive = _currentFocus.matches(section, rowIdx, colIdx);
    return GestureDetector(
      onTap: () => setState(
        () => _currentFocus = InputFocus(
          section: section,
          rowIndex: rowIdx,
          colIndex: colIdx,
        ),
      ),
      child: Container(
        height: 60,
        width: _cellSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : bg,
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.shade400,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          dataList[colIdx],
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(child: Row(children: ['1', '2', '3'].map(_btn).toList())),
          Expanded(child: Row(children: ['4', '5', '6'].map(_btn).toList())),
          Expanded(child: Row(children: ['7', '8', '9'].map(_btn).toList())),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _iconBtn(
                    Icons.backspace_outlined,
                    Colors.red.shade100,
                    Colors.red,
                    _backspace,
                  ),
                ),
                _btn('0'),
                Expanded(
                  child: _iconBtn(
                    Icons.check,
                    Colors.green,
                    Colors.white,
                    _checkAnswer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String val) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: () => _handleInput(val),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            val,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color bg, Color fg, VoidCallback fn) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: fn,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Icon(icon, size: 28),
      ),
    );
  }
}
