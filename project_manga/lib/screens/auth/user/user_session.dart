class UserSession {
  static int? id;
  static String? nama;
  static String? email;

  static bool get isLoggedIn => id != null;

  static void set(Map<String, dynamic> user) {
    id = user['id'] as int?;
    nama = user['name'] as String? ?? user['nama'] as String?;
    email = user['email'] as String?;
  }

  static void clear() {
    id = null;
    nama = null;
    email = null;
  }
}
