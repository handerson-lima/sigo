class Membro {
  final String uid;
  final bool isAdmin;
  final String email;

  Membro({
    required this.uid,
    required this.isAdmin,
    this.email = '',
  });

  factory Membro.fromFirestore(Map<String, dynamic> data, String uid) {
    return Membro(
      uid: uid,
      isAdmin: data['isAdmin'] == true,
      email: data['email'] ?? '',
    );
  }
}
