import 'package:meta/meta.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';

/// Uma página de "Meus reportes", no formato das listagens da API.
@immutable
final class ReportPage {
  const new({required this.items, required this.page, required this.pageSize, required this.total});

  final List<Report> items;

  /// A página, a partir de 1.
  final int page;

  final int pageSize;

  /// O total de reportes, em todas as páginas.
  final int total;

  /// Se há uma página depois desta.
  bool get hasMore => page * pageSize < total;

  @override
  bool operator ==(Object other) =>
      other is ReportPage &&
      _sameItems(other.items, items) &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.total == total;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), page, pageSize, total);

  @override
  String toString() =>
      'ReportPage(${items.length} reportes, page: $page, pageSize: $pageSize, total: $total)';
}

bool _sameItems(List<Report> a, List<Report> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
