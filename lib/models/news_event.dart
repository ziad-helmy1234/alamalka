class NewsItem {
  final String id;
  final String titleAr;
  final String summaryAr;
  final String categoryAr; // 'عاجل', 'نتائج أعمال', 'استحواذ', 'اقتصاد كلي'
  final DateTime timestamp;
  final String? relatedSymbol;
  final String source;
  final bool isUrgent;

  NewsItem({
    required this.id,
    required this.titleAr,
    required this.summaryAr,
    required this.categoryAr,
    required this.timestamp,
    this.relatedSymbol,
    required this.source,
    this.isUrgent = false,
  });
}

class MarketEvent {
  final String id;
  final String titleAr;
  final DateTime date;
  final String eventType; // 'dividend', 'earnings', 'agm', 'macro'
  final String eventTypeAr;
  final String? relatedSymbol;
  final String detailsAr;

  MarketEvent({
    required this.id,
    required this.titleAr,
    required this.date,
    required this.eventType,
    required this.eventTypeAr,
    this.relatedSymbol,
    required this.detailsAr,
  });
}
