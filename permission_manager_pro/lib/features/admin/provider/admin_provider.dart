import 'package:permission_manager_pro/features/admin/repository/admin_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_provider.g.dart';

@riverpod
class AdminController extends _$AdminController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    return ref.read(adminRepositoryProvider).getAllUsers();
  }
}
