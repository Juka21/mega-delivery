import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../services/printer_service.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'Pendente':
        return Colors.orange;
      case 'Em Preparação':
      case 'Em PreparaÃ§Ã£o':
        return Colors.blue;
      case 'Pronto para Recolha':
        return Colors.green;
      case 'A Caminho':
        return Colors.purple;
      case 'Entregue':
      case 'Concluído':
      case 'ConcluÃ­do':
        return Colors.teal;
      case 'Cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(BuildContext context, String id, String status) async {
    await DatabaseService().updateOrderStatus(id, status);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pedido atualizado para $status')),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _printOrder(BuildContext context, Map<String, dynamic> pedido) async {
    final printer = PrinterService();
    if (!printer.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impressora desligada. Liga a impressora no menu Impressora.')),
      );
      return;
    }

    await printer.printOrderTicket({
      'userName': pedido['cliente'] ?? pedido['nomeCliente'] ?? 'Cliente',
      'userPhone': pedido['telefoneCliente'] ?? '',
      'morada': pedido['metodoEntrega'] == 'Take-Away' ? 'Levantamento em Loja' : (pedido['morada'] ?? ''),
      'total': (pedido['total'] as num?)?.toDouble() ?? 0.0,
      'itens': pedido['itens'] ?? [],
    }, pedido['id']?.toString() ?? pedido['_id']?.toString() ?? 'PEDIDO');
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Pedidos em Tempo Real', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.allOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          }

          final pedidos = snapshot.data ?? [];
          if (pedidos.isEmpty) {
            return Center(
              child: Text('Sem pedidos por agora.', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pedidos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _OrderCard(
              pedido: pedidos[index],
              color: _statusColor((pedidos[index]['status'] ?? 'Pendente').toString()),
              onStatus: (status) => _updateStatus(context, pedidos[index]['id'].toString(), status),
              onPrint: () => _printOrder(context, pedidos[index]),
              onCall: (phone) => _makePhoneCall(phone),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final Color color;
  final ValueChanged<String> onStatus;
  final VoidCallback onPrint;
  final ValueChanged<String> onCall;

  const _OrderCard({
    required this.pedido,
    required this.color,
    required this.onStatus,
    required this.onPrint,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final id = pedido['id']?.toString() ?? pedido['_id']?.toString() ?? 'pedido';
    final status = pedido['status']?.toString() ?? 'Pendente';
    final cliente = pedido['cliente']?.toString() ?? pedido['nomeCliente']?.toString() ?? 'Cliente';
    final telefone = pedido['telefoneCliente']?.toString() ?? '';
    final itens = List<dynamic>.from(pedido['itens'] ?? []);
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('#${id.length > 5 ? id.substring(id.length - 5).toUpperCase() : id}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              IconButton(onPressed: onPrint, icon: const Icon(Icons.print_rounded)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
                child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(cliente, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (telefone.isNotEmpty)
            TextButton.icon(
              onPressed: () => onCall(telefone),
              icon: const Icon(Icons.phone, size: 16),
              label: Text(telefone),
            ),
          const Divider(),
          ...itens.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('${map['quantidade'] ?? 1}x ${map['nome'] ?? map['nomePrato'] ?? 'Item'}'),
            );
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Total: ${total.toStringAsFixed(2)} EUR', style: const TextStyle(fontWeight: FontWeight.w900))),
              DropdownButton<String>(
                value: status,
                items: const [
                  'Pendente',
                  'Em Preparação',
                  'Pronto para Recolha',
                  'A Caminho',
                  'Entregue',
                  'Cancelado',
                  'Concluído',
                ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) {
                  if (value != null) onStatus(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
