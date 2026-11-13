import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/account_repository.dart';
import 'account_repository_impl.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  if (AppConfig.useMock) return MockAccountRepository();
  return ApiAccountRepository(ref.read(dioProvider));
});
