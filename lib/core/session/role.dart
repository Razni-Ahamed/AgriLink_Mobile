/// The four account roles, as the API names them in `{ token, role }` and `/api/users/me`.
enum Role {
  farmer('Farmer'),
  buyer('Buyer'),
  officer('Officer'),
  admin('Admin');

  const Role(this.apiName);

  /// The exact string the API uses.
  final String apiName;

  /// Null for anything the app doesn't know.
  static Role? fromApi(String? value) {
    for (final role in values) {
      if (role.apiName == value) {
        return role;
      }
    }
    return null;
  }
}
