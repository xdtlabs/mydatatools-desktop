import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/app_user.dart';
import 'package:mydatatools/repositories/user_repository.dart';
import 'package:mydatatools/services/rx_service.dart';

class GetUserExistsService
    extends RxService<GetUserExistsServiceCommand, AppUser?> {
  @override
  Future<AppUser?> invoke(GetUserExistsServiceCommand command) async {
    isLoading.add(true);
    UserRepository repo = UserRepository(DatabaseManager.instance.database);
    AppUser? user = await repo.userExists();
    sink.add(user);
    isLoading.add(false);

    return Future(() => user);
  }
}

class GetUserExistsServiceCommand implements RxCommand {}
