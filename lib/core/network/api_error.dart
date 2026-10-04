import 'package:dio/dio.dart';

String extractApiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      if (data['detail'] != null) return data['detail'].toString();
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your network and try again.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Is the backend running?';
    }
    switch (error.response?.statusCode) {
      case 400:
        return 'The expense details or split are invalid, or cost sharing is disabled.';
      case 401:
        return 'Your session has expired. Sign in again and retry.';
      case 403:
        return 'You do not have permission to change this expense.';
    }
  }
  return 'Something went wrong. Please try again.';
}
