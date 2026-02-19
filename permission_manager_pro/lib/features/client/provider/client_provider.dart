import 'package:permission_manager_pro/features/client/repository/client_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'client_provider.g.dart';

@riverpod
class ClientController extends _$ClientController {
  @override
  FutureOr<Map<String, dynamic>?> build() async {
    return ref.read(clientRepositoryProvider).getProfile();
  }
}
