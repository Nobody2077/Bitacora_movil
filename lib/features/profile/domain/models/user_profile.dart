final class UserProfile {
  const UserProfile({required this.displayName, this.avatarPath});

  const UserProfile.localDefault()
    : displayName = 'Usuario local',
      avatarPath = null;

  final String displayName;
  final String? avatarPath;

  UserProfile copyWith({String? displayName, String? avatarPath}) =>
      UserProfile(
        displayName: displayName ?? this.displayName,
        avatarPath: avatarPath ?? this.avatarPath,
      );

  UserProfile withoutAvatar() => UserProfile(displayName: displayName);
}
