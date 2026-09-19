class Membro {
  final String uid;
  final bool isAdmin;
  final bool isOwner;
  final String role;
  final String email;

  Membro({
    required this.uid,
    required this.isAdmin,
    this.isOwner = false,
    this.role = 'operario',
    this.email = '',
  });

  factory Membro.fromFirestore(Map<String, dynamic> data, String uid) {
    final isOwner = data['isOwner'] == true || data['role'] == 'owner';
    final isAdmin = isOwner || data['isAdmin'] == true || data['role'] == 'admin';
    final role = (data['role'] as String?) ??
        (isOwner ? 'owner' : (isAdmin ? 'admin' : 'operario'));
    return Membro(
      uid: uid,
      isAdmin: isAdmin,
      isOwner: isOwner,
      role: role,
      email: data['email'] as String? ?? '',
    );
  }
}
