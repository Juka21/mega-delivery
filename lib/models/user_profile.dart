class UserProfile {
  final String uid;
  final String nome;
  final String email; // ✅ Adicionado para consistência
  final String morada;
  final String telefone;
  final String role;  // ✅ Adicionado para sabermos se é admin

  UserProfile({
    required this.uid,
    required this.nome,
    required this.email,
    required this.morada,
    required this.telefone,
    this.role = 'cliente',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nome': nome,
      'email': email,
      'morada': morada,
      'telefone': telefone,
      'role': role,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      // Mantem compatibilidade com dados antigos e documentos Firestore.
      uid: data['id']?.toString() ?? data['_id']?.toString() ?? data['uid'] ?? '',
      nome: data['nome'] ?? 'Cliente',
      email: data['email'] ?? '',
      morada: data['morada'] ?? '',
      telefone: data['telefone'] ?? '',
      role: data['role'] ?? 'cliente',
    );
  }
}
