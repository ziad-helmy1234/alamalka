class TransferRecord {
  final String id;
  final double amount;
  final String currency;
  final String typeAr;
  final String typeEn;
  final String methodAr;
  final String methodEn;
  final DateTime timestamp;
  final String statusAr;
  final String statusEn;

  TransferRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.typeAr,
    required this.typeEn,
    required this.methodAr,
    required this.methodEn,
    required this.timestamp,
    required this.statusAr,
    required this.statusEn,
  });
}

class InboxMessage {
  final String id;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final DateTime timestamp;
  bool isRead;

  InboxMessage({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.timestamp,
    this.isRead = false,
  });
}

class StatementDoc {
  final String id;
  final String titleAr;
  final String titleEn;
  final String periodAr;
  final String periodEn;
  final DateTime date;
  final String fileSize;

  StatementDoc({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.periodAr,
    required this.periodEn,
    required this.date,
    required this.fileSize,
  });
}

class FormDoc {
  final String id;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String statusAr;
  final String statusEn;

  FormDoc({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.statusAr,
    required this.statusEn,
  });
}
