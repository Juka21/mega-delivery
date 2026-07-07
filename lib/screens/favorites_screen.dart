import 'package:flutter/material.dart';
import '../models/prato.dart';
import '../services/database_service.dart';
import 'prato_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  static const Color _brand = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Favoritos',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.getFavoritePratosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _brand));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _brand.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border_rounded,
                          color: _brand, size: 34),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Ainda nao tens favoritos',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Marca os produtos que pedes mais vezes para os encontrares rapidamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], height: 1.35),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final prato = Prato.fromMap({
                ...item,
                '_id': item['pratoId'] ?? item['_id'] ?? item['id'],
              });
              return _FavoriteCard(
                prato: prato,
                onOpen: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PratoDetailScreen(prato: prato),
                  ),
                ),
                onRemove: () => db.toggleFavoritePrato(prato, false),
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Prato prato;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.prato,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  prato.imageUrl,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 76,
                    height: 76,
                    color: const Color(0xFFEDEFF4),
                    child:
                        const Icon(Icons.fastfood_rounded, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prato.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF17212B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      prato.categoria,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${prato.preco.toStringAsFixed(2)} EUR',
                      style: const TextStyle(
                        color: Color(0xFFFF8A00),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.favorite_rounded,
                    color: Color(0xFFFF8A00)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
