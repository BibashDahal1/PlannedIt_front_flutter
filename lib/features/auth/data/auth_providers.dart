import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import 'auth_api.dart';
import 'auth_repository.dart';

final tokenStorageProvider = Provider((ref) => SecureTokenStorage());
final dioClientProvider = Provider(
  (ref) => DioClient(ref.watch(tokenStorageProvider)),
);
final authApiProvider = Provider(
  (ref) => AuthApi(ref.watch(dioClientProvider).dio),
);
final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.watch(authApiProvider),
    ref.watch(tokenStorageProvider),
  ),
);
