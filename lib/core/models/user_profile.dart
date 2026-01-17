class UserProfile {
  final String uid;
  final String email;
  final String phone;
  final String role;
  final String firstName;
  final String lastName;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.phone,
    required this.role,
    required this.firstName,
    required this.lastName,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phone': phone,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}