class TransferRecord {
  final String id;
  final double amount;
  final String currency;
  final String typeAr; // 'إيداع نقدي', 'سحب نقدي', 'تحويل بنكي'
  final String methodAr; // 'InstaPay', 'بطاقة مصرفية', 'تحويل بنكي', 'فودافون كاش'
  final DateTime timestamp;
  final String statusAr; // 'مكتمل بنجاح', 'قيد المعالجة'

  TransferRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.typeAr,
    required this.methodAr,
    required this.timestamp,
    required this.statusAr,
  });
}

class InboxMessage {
  final String id;
  final String titleAr;
  final String bodyAr;
  final DateTime timestamp;
  bool isRead;

  InboxMessage({
    required this.id,
    required this.titleAr,
    required this.bodyAr,
    required this.timestamp,
    this.isRead = false,
  });
}

class StatementDoc {
  final String id;
  final String titleAr;
  final String periodAr;
  final DateTime date;
  final String fileSize;

  StatementDoc({
    required this.id,
    required this.titleAr,
    required this.periodAr,
    required this.date,
    required this.fileSize,
  });
}

class FormDoc {
  final String id;
  final String titleAr;
  final String descriptionAr;
  final String statusAr; // 'مكتمل', 'مطلوب توقيع', 'معتمد'

  FormDoc({
    required this.id,
    required this.titleAr,
    required this.descriptionAr,
    required this.statusAr,
  });
}
