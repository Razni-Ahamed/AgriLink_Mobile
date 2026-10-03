/// A row of `GET /api/admin/users`.
Map<String, Object?> adminUserJson({
  int id = 2,
  String name = 'Kamal Perera',
  String role = 'Officer',
  bool isActive = true,
  String? district = 'Kandy',
  String? department = 'Agriculture',
  String registrationStatus = 'Approved',
}) => {
  'userId': id,
  'fullName': name,
  'email': 'user$id@example.lk',
  'username': 'user$id',
  'profilePhotoUrl': null,
  'role': role,
  'district': district,
  'department': department,
  'isActive': isActive,
  'registrationStatus': registrationStatus,
  'createdAt': '2026-05-01T09:00:00Z',
};
