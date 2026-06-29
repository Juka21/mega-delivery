class Prato {
  final String id;
  final String nome;
  final String descricao;
  final double preco;
  final String categoria;
  final String imageUrl;
  final List<String> ingredientes;
  final List<Map<String, dynamic>> extras;
  final List<String> molhos; 

  Prato({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.categoria,
    required this.imageUrl,
    required this.ingredientes,
    this.extras = const [],
    this.molhos = const [],
  });

  // Recebe um mapa vindo do Firestore ou de dados locais.
  factory Prato.fromMap(Map<String, dynamic> data) {
    return Prato(
      // Mantem compatibilidade com documentos antigos que usavam '_id'.
      id: data['_id']?.toString() ?? data['id']?.toString() ?? '',
      
      nome: data['nome'] ?? data['nomePrato'] ?? '', 
      descricao: data['descricao'] ?? '',
      
      // Converte para double com segurança
      preco: (data['preco'] ?? data['precoUnitario'] ?? 0.0).toDouble(),
      
      categoria: data['categoria'] ?? 'Outros',
      imageUrl: data['imageUrl'] ?? '',
      
      ingredientes: List<String>.from(data['ingredientes'] ?? []),
      extras: (data['extras'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      molhos: List<String>.from(data['molhos'] ?? []), 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'preco': preco,
      'categoria': categoria,
      'imageUrl': imageUrl,
      'ingredientes': ingredientes,
      'extras': extras,
      'molhos': molhos,
    };
  }
}
