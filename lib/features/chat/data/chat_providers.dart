import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import 'chat_api.dart';

final chatApiProvider = Provider(
  (ref) => ChatApi(ref.watch(dioClientProvider).dio),
);
