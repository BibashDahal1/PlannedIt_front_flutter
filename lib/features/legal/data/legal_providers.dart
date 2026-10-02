import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../domain/legal_document.dart';
import 'legal_api.dart';

/// Deliberately a plain Dio, not the app's DioClient -- legal document
/// text is public (Auth: None) and should be readable even before
/// login, so it must never depend on a JWT being present.
final legalApiProvider = Provider(
  (ref) => LegalApi(Dio(BaseOptions(baseUrl: Env.apiBaseUrl))),
);

final legalDocumentProvider = FutureProvider.family<LegalDocument, String>((
  ref,
  documentType,
) {
  return ref.watch(legalApiProvider).fetchByType(documentType);
});
