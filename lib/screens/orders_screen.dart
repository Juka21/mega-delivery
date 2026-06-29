import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pedido.dart';
import '../services/database_service.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  Color _statusColor(String status) {
    if (status.contains('Caminho')) return Colors.purple;
    if (status.contains('Entregue') || status.contains('Conclu')) return Colors.green;
    if (status.contains('Cancelado')) return Colors.red;
    if (status.contains('Recolha') || status.contains('Pronto')) return Colors.green;
    if (status.contains('Prepara')) return Colors.blue;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Os Meus Pedidos', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22)),
        backgroundColor: const Color(0xFFF8F9FD),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Pedido>>(
        stream: db.userOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          }

          final pedidos = snapshot.data ?? [];
          if (pedidos.isEmpty) {
            return Center(child: Text('Ainda não tens pedidos.', style: TextStyle(color: Colors.grey[600])));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: pedidos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 15),
            itemBuilder: (context, index) => _OrderCard(pedido: pedidos[index], color: _statusColor(pedidos[index].estado)),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Pedido pedido;
  final Color color;

  const _OrderCard({required this.pedido, required this.color});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM - HH:mm', 'pt_PT').format(pedido.dataPedido);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(pedido: pedido))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${pedido.id.length > 4 ? pedido.id.substring(pedido.id.length - 4).toUpperCase() : pedido.id}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(pedido.estado.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pedido.itens.map((i) => '${i.quantidade}x ${i.nomePrato}').join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                Text('${pedido.total.toStringAsFixed(2)} EUR', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
