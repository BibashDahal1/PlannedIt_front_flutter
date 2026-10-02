import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/legal_document.dart';

class LegalApi {
  LegalApi(this._dio);
  final Dio _dio;

  Future<List<LegalDocument>> fetchAll() async {
    final response = await _dio.get(ApiEndpoints.legalDocuments);
    return (response.data as List)
        .map((e) => LegalDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LegalDocument> fetchByType(String documentType) async {
    final response = await _dio.get(ApiEndpoints.legalDocument(documentType));
    return LegalDocument.fromJson(response.data as Map<String, dynamic>);
  }
}
