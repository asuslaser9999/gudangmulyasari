class AppRole {
  const AppRole({
    required this.id,
    required this.code,
    required this.name,
    this.isSystem = false,
  });

  final String id;
  final String code;
  final String name;
  final bool isSystem;

  factory AppRole.fromJson(Map<String, dynamic> json) {
    return AppRole(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isSystem: json['is_system'] as bool? ?? false,
    );
  }
}

class AppPermission {
  const AppPermission({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
  });

  final String id;
  final String code;
  final String name;
  final String description;

  factory AppPermission.fromJson(Map<String, dynamic> json) {
    return AppPermission(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    this.displayName = '',
    this.username,
    this.email,
    this.role,
    this.locationIds = const [],
    this.itemIds = const [],
    this.hasLocationScope = false,
    this.hasItemScope = false,
    this.isActive = true,
  });

  final String id;
  final String displayName;
  final String? username;
  final String? email;
  final AppRole? role;
  final List<String> locationIds;
  final List<String> itemIds;
  final bool hasLocationScope;
  final bool hasItemScope;
  final bool isActive;

  String get roleLabel => role?.name ?? '-';

  String get statusLabel => isActive ? 'Aktif' : 'Nonaktif';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    AppRole? role;
    final roleJson = json['gm_roles'] ?? json['role'];
    if (roleJson is Map<String, dynamic>) {
      role = AppRole.fromJson(roleJson);
    }

    final access = json['gm_user_location_access'];
    final locationIds = <String>[];
    if (access is List) {
      for (final row in access) {
        if (row is Map && row['location_id'] != null) {
          locationIds.add(row['location_id'] as String);
        }
      }
    }

    final itemAccess = json['gm_user_item_access'];
    final itemIds = <String>[];
    if (itemAccess is List) {
      for (final row in itemAccess) {
        if (row is Map && row['item_id'] != null) {
          itemIds.add(row['item_id'] as String);
        }
      }
    }

    return AppUser(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      username: json['username'] as String?,
      email: json['email'] as String?,
      role: role,
      locationIds: locationIds,
      itemIds: itemIds,
      hasLocationScope: json.containsKey('gm_user_location_access'),
      hasItemScope: json.containsKey('gm_user_item_access'),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
