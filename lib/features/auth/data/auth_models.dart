import '../../../core/api/json.dart';
import '../../../core/session/role.dart';

/// `{ token, role }` from login and from a password change.
class AuthResult {
  const AuthResult({required this.token, required this.role});

  factory AuthResult.fromJson(Json json) {
    final role = Role.fromApi(json['role'] as String?);
    if (role == null) {
      throw FormatException('Unknown role ${json['role']}');
    }
    return AuthResult(token: field<String>(json, 'token'), role: role);
  }

  final String token;
  final Role role;
}

/// The self-registration form. Only farmers and buyers register themselves; officers and
/// admins are created by an admin.
sealed class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.username,
    required this.password,
    required this.nic,
    required this.district,
  });

  final String fullName;
  final String email;

  /// Already normalised (trimmed, lowercase).
  final String username;
  final String password;

  /// Already normalised (uppercase V/X).
  final String nic;
  final String district;

  Role get role;

  Json toJson() => {
    'fullName': fullName,
    'email': email,
    'username': username,
    'password': password,
    'nic': nic,
    'district': district,
    'role': role.apiName,
  };
}

class FarmerRegisterRequest extends RegisterRequest {
  const FarmerRegisterRequest({
    required super.fullName,
    required super.email,
    required super.username,
    required super.password,
    required super.nic,
    required super.district,
    required this.fieldPlotNumber,
    required this.phoneNumber,
  });

  final String fieldPlotNumber;
  final String phoneNumber;

  @override
  Role get role => Role.farmer;

  @override
  Json toJson() => {
    ...super.toJson(),
    'fieldPlotNumber': fieldPlotNumber,
    'phoneNumber': phoneNumber,
  };
}

class BuyerRegisterRequest extends RegisterRequest {
  const BuyerRegisterRequest({
    required super.fullName,
    required super.email,
    required super.username,
    required super.password,
    required super.nic,
    required super.district,
    required this.legalBusinessName,
    required this.businessRegistrationNumber,
    required this.businessPhone,
  });

  final String legalBusinessName;
  final String businessRegistrationNumber;
  final String businessPhone;

  @override
  Role get role => Role.buyer;

  @override
  Json toJson() => {
    ...super.toJson(),
    'legalBusinessName': legalBusinessName,
    'businessRegistrationNumber': businessRegistrationNumber,
    'businessPhone': businessPhone,
  };
}

enum UsernameUnavailableReason { invalid, reserved, taken }

/// `GET /api/users/username-available`.
class UsernameAvailability {
  const UsernameAvailability({required this.available, this.reason});

  factory UsernameAvailability.fromJson(Json json) => UsernameAvailability(
    available: json['available'] == true,
    reason: switch (json['reason']) {
      'invalid' => UsernameUnavailableReason.invalid,
      'reserved' => UsernameUnavailableReason.reserved,
      'taken' => UsernameUnavailableReason.taken,
      _ => null,
    },
  );

  final bool available;
  final UsernameUnavailableReason? reason;
}

/// The signed-in user's own profile, from `GET /api/users/me` and every `/me` update.
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.username,
    required this.createdAt,
    this.nic,
    this.district,
    this.displayName,
    this.profilePhotoUrl,
    this.phoneNumber,
    this.fieldPlotNumber,
    this.businessName,
    this.businessRegistrationNumber,
    this.departmentName,
    this.usernameChangeAvailableAt,
    this.farmerProfileId,
  });

  factory UserProfile.fromJson(Json json) {
    final role = Role.fromApi(json['role'] as String?);
    if (role == null) {
      throw FormatException('Unknown role ${json['role']}');
    }
    return UserProfile(
      userId: (json['userId'] as num).toInt(),
      fullName: field<String>(json, 'fullName'),
      email: field<String>(json, 'email'),
      role: role,
      username: field<String>(json, 'username'),
      createdAt: parseApiDate(field<String>(json, 'createdAt')),
      nic: json['nic'] as String?,
      district: json['district'] as String?,
      displayName: json['displayName'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      fieldPlotNumber: json['fieldPlotNumber'] as String?,
      businessName: json['businessName'] as String?,
      businessRegistrationNumber: json['businessRegistrationNumber'] as String?,
      departmentName: json['departmentName'] as String?,
      usernameChangeAvailableAt: parseApiDateOrNull(json['usernameChangeAvailableAt']),
      farmerProfileId: (json['farmerProfileId'] as num?)?.toInt(),
    );
  }

  final int userId;
  final String fullName;
  final String email;
  final Role role;
  final String username;
  final DateTime createdAt;
  final String? nic;
  final String? district;

  /// Optional. Show [shownName] rather than this directly.
  final String? displayName;

  /// Null means the role's default avatar. Render it through `UserAvatar`.
  final String? profilePhotoUrl;

  /// Farmer: profile phone. Buyer: business phone. Officer/Admin: account phone, if any.
  final String? phoneNumber;

  /// Farmer only.
  final String? fieldPlotNumber;

  /// Buyer only.
  final String? businessName;

  /// Buyer only.
  final String? businessRegistrationNumber;

  /// Officer only.
  final String? departmentName;

  /// When the username may next change; null means it may change now.
  final DateTime? usernameChangeAvailableAt;

  /// Farmer only: tells the farmer's own marketplace listings apart from others'.
  final int? farmerProfileId;

  /// The display name, or the full name when there is none (like the website's header).
  String get shownName {
    final name = displayName?.trim();
    return name == null || name.isEmpty ? fullName : name;
  }

  bool canChangeUsername([DateTime? now]) {
    final availableAt = usernameChangeAvailableAt;
    return availableAt == null || !availableAt.isAfter(now ?? DateTime.now());
  }
}
