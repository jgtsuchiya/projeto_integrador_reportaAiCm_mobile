import 'package:reportaai_cm/features/reports/data/dtos/report_dto.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_page.dart';

/// A página do `GET /api/reports/mine`: `{ items, page, pageSize, total }`.
final class ReportPageDto {
  const new(this._page);

  /// Lança uma [FormatException] quando a página ou um reporte está fora do formato.
  factory fromJson(Object? json) {
    if (json case {
      'items': final List<Object?> items,
      'page': final int page,
      'pageSize': final int pageSize,
      'total': final int total,
    }) {
      return ReportPageDto(
        ReportPage(
          items: List.unmodifiable([for (final item in items) ReportDto.fromJson(item).toModel()]),
          page: page,
          pageSize: pageSize,
          total: total,
        ),
      );
    }
    throw const FormatException('A página dos reportes está fora do formato esperado.');
  }

  final ReportPage _page;

  ReportPage toModel() => _page;
}

/// A lista do `GET /api/reports/nearby`: `{ items }`, cada um com o `distanceMeters`.
final class NearbyReportsDto {
  const new(this._items);

  /// Lança uma [FormatException] quando a lista ou um reporte está fora do formato.
  factory fromJson(Object? json) {
    if (json case {'items': final List<Object?> items}) {
      return NearbyReportsDto(
        List.unmodifiable([for (final item in items) ReportDto.fromJson(item).toModel()]),
      );
    }
    throw const FormatException('A lista dos reportes perto está fora do formato esperado.');
  }

  final List<Report> _items;

  List<Report> toModel() => _items;
}
