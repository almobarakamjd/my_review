// نموذج لتتبع حالة الاستلاف في الطرح
class BorrowState {
  final bool isBorrowedFrom; // هل تم الاستلاف من هذا الرقم (يتم شطبه)
  final int newValue; // قيمته الجديدة بعد الشطب
  final bool isReceived; // هل هذا الرقم هو المستفيد (يصبح 14 مثلاً)
  final int receivedValue; // قيمته الجديدة بعد الزيادة

  BorrowState({
    this.isBorrowedFrom = false,
    this.newValue = 0,
    this.isReceived = false,
    this.receivedValue = 0,
  });
}
