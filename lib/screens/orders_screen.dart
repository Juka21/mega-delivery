import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pedido.dart';
import '../services/database_service.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  Future<void> _confirmarRecebido(BuildContext context, String pedidoId) async {
    await DatabaseService().updateOrderStatus(
      pedidoId,
      'Recebido pelo Cliente',
      actor: 'cliente',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obrigado! Pedido confirmado.')),
      );
    }
  }

  Color _statusColor(String status) {
    if (status.contains('Caminho')) return Colors.purple;
    if (status.contains('Entregue') || status.contains('Conclu'))
      return Colors.green;
    if (status.contains('Cancelado')) return Colors.red;
    if (status.contains('Recolha') || status.contains('Pronto'))
      return Colors.green;
    if (status.contains('Prepara')) return Colors.blue;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Os Meus Pedidos',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 22)),
        backgroundColor: const Color(0xFFF8F9FD),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Pedido>>(
        stream: db.userOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          }

          final pedidos = snapshot.data ?? [];
          if (pedidos.isEmpty) {
            return Center(
                child: Text('Ainda não tens pedidos.',
                    style: TextStyle(color: Colors.grey[600])));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: pedidos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 15),
            itemBuilder: (context, index) => _OrderCard(
              pedido: pedidos[index],
              color: _statusColor(pedidos[index].estado),
              onConfirmReceived: () =>
                  _confirmarRecebido(context, pedidos[index].id),
              onRate: () => _showRatingSheet(context, pedidos[index]),
            ),
          );
        },
      ),
    );
  }

  void _showRatingSheet(BuildContext context, Pedido pedido) {
    int selectedRating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avaliar pedido',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return IconButton(
                        onPressed: () =>
                            setModalState(() => selectedRating = value),
                        icon: Icon(
                          value <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber[700],
                          size: 34,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentário opcional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await DatabaseService().rateOrder(
                          pedidoId: pedido.id,
                          rating: selectedRating,
                          comment: commentController.text,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Obrigado pela avaliação.')),
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Guardar avaliação'),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Pedido pedido;
  final Color color;
  final VoidCallback onConfirmReceived;
  final VoidCallback onRate;

  const _OrderCard({
    required this.pedido,
    required this.color,
    required this.onConfirmReceived,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM - HH:mm', 'pt_PT').format(pedido.dataPedido);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(pedido: pedido))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${pedido.id.length > 4 ? pedido.id.substring(pedido.id.length - 4).toUpperCase() : pedido.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(pedido.estado.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pedido.itens
                  .map((i) => '${i.quantidade}x ${i.nomePrato}')
                  .join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                Text('${pedido.total.toStringAsFixed(2)} EUR',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
            if (pedido.estado == 'Entregue') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onConfirmReceived,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Confirmar que recebi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if ((pedido.estado == 'Recebido pelo Cliente' ||
                    pedido.estado == 'Concluído') &&
                pedido.rating == null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber[800],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onRate,
                  icon: const Icon(Icons.star_rounded),
                  label: const Text(
                    'Avaliar pedido',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (pedido.rating != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber[700], size: 18),
                  const SizedBox(width: 5),
                  Text(
                    '${pedido.rating}/5',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if ((pedido.ratingComment ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pedido.ratingComment!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
