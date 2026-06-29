class ItemCarrinho {
  final String documentId; 
  final String pratoId;
  final String nomePrato;
  final double precoUnitario;
  final String? imageUrl;
  final int quantidade;
  final List<String> ingredientesRemovidos;
  final String? notaCliente;
  final List<Map<String, dynamic>> extras;

  ItemCarrinho({
    required this.documentId,
    required this.pratoId,
    required this.nomePrato,
    required this.precoUnitario,
    this.imageUrl,
    required this.quantidade,
    required this.ingredientesRemovidos,
    this.notaCliente,
    this.extras = const [],
  });

  // Getters de compatibilidade mantidos
  String get id => documentId;
  double get preco => precoUnitario;
  String get nome => nomePrato;
  String? get nota => notaCliente;

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'pratoId': pratoId,
      'nomePrato': nomePrato,
      'precoUnitario': precoUnitario,
      'imageUrl': imageUrl,
      'quantidade': quantidade,
      'ingredientesRemovidos': ingredientesRemovidos,
      'notaCliente': notaCliente,
      'extras': extras,
    };
  }

  // Metodo principal para ler itens guardados no carrinho local.
  factory ItemCarrinho.fromMap(Map<String, dynamic> data) {
    return ItemCarrinho(
      // Mantem compatibilidade com dados antigos e carrinho local.
      documentId: data['_id']?.toString() ?? data['id']?.toString() ?? '',
      pratoId: data['pratoId']?.toString() ?? '',
      nomePrato: data['nomePrato'] ?? data['nome'] ?? 'Sem nome',
      precoUnitario: (data['precoUnitario'] ?? data['preco'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'],
      quantidade: (data['quantidade'] as num?)?.toInt() ?? 1,
      ingredientesRemovidos: List<String>.from(data['ingredientesRemovidos'] ?? []),
      notaCliente: data['notaCliente'] ?? data['nota'],
      extras: (data['extras'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}
