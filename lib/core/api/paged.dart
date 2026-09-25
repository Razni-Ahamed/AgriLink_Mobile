import 'json.dart';

/// One page of a list endpoint. Every paged endpoint in the API returns this envelope:
/// `{ items, page, pageSize, totalCount, totalPages }`. Pages start at 1.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  /// An empty first page, e.g. before anything has loaded.
  const Paged.empty({this.pageSize = 20})
    : items = const [],
      page = 1,
      totalCount = 0,
      totalPages = 0;

  factory Paged.fromJson(Json json, T Function(Json item) fromItem) {
    return Paged(
      items: [
        for (final item in asJsonList(json['items'], 'items')) fromItem(item),
      ],
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  /// Whether a later page exists.
  bool get hasMore => page < totalPages;

  bool get isEmpty => totalCount == 0 && items.isEmpty;

  Paged<R> map<R>(R Function(T item) convert) => Paged(
    items: items.map(convert).toList(),
    page: page,
    pageSize: pageSize,
    totalCount: totalCount,
    totalPages: totalPages,
  );
}
