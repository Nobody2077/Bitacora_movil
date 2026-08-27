import '../../../../core/result/result.dart';
import '../models/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<Result<UserProfile>> load();

  Future<Result<void>> save(UserProfile profile);
}
