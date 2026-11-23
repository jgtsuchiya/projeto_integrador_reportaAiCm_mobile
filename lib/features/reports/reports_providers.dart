import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:reportaai_cm/core/network/dio_provider.dart';
import 'package:reportaai_cm/features/reports/data/repositories/api_report_repository.dart';
import 'package:reportaai_cm/features/reports/domain/models/report.dart';
import 'package:reportaai_cm/features/reports/domain/models/report_draft.dart';
import 'package:reportaai_cm/features/reports/domain/repositories/report_repository.dart';

/// Liga o contrato à implementação, como o `reports.module.ts` do backend. Os testes trocam a
/// implementação pelo `FakeReportRepository` com `reportRepositoryProvider.overrideWithValue(...)`.
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ApiReportRepository(ref.watch(dioProvider)),
);

/// Qual imagem buscar: a do reporte `reportId`, com o id da foto `photoId`, no `size`.
typedef ReportPhotoKey = ({String reportId, String photoId, ReportPhotoSize size});

/// A chave do cache da [photo] do reporte [reportId] no [size].
ReportPhotoKey reportPhotoKey(String reportId, ReportPhotoInfo photo, ReportPhotoSize size) =>
    (reportId: reportId, photoId: photo.id, size: size);

/// Quanto tempo a imagem fica em memória depois de sair da tela: voltar para a lista ou para o
/// detalhe logo depois não busca a imagem de novo.
const reportPhotoCacheDuration = Duration(minutes: 5);

/// O cache das imagens dos reportes, em memória, pela [ReportPhotoKey]. O id da foto faz parte da
/// chave e muda quando ela é trocada: o cache nunca mostra a foto antiga.
///
/// A imagem que chegou fica guardada enquanto aparece em alguma tela e por mais
/// [reportPhotoCacheDuration] depois (`ref.keepAlive` com um timer). A que falhou não fica: a
/// próxima tela que a pedir busca de novo.
final FutureProviderFamily<Uint8List, ReportPhotoKey> reportPhotoProvider = FutureProvider
    .autoDispose
    .family<Uint8List, ReportPhotoKey>((ref, key) async {
      final photo = await ref.watch(reportRepositoryProvider).getPhoto(key.reportId, key.size);

      // A tela pode ter saído enquanto a imagem chegava: sem ninguém ouvindo, nada a guardar.
      if (ref.mounted) {
        final link = ref.keepAlive();
        Timer? timer;
        // Sem ouvintes, o timer começa. Com um ouvinte de volta antes do fim, a imagem continua.
        ref
          ..onCancel(() => timer = Timer(reportPhotoCacheDuration, link.close))
          ..onResume(() => timer?.cancel())
          ..onDispose(() => timer?.cancel());
      }

      return photo.bytes;
    });
