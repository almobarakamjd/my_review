// -----------------------------------------------------------------------------
// نموذج التركيز
// -----------------------------------------------------------------------------
class InputFocus {
  int section; // 0: باليد (جمع)، 1: نواتج ضرب، 2: الناتج النهائي
  int rowIndex;
  int colIndex;

  InputFocus({
    required this.section,
    required this.rowIndex,
    required this.colIndex,
  });
  bool matches(int s, int r, int c) =>
      section == s && rowIndex == r && colIndex == c;
}
