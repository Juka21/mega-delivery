import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pedido.dart';
import '../services/database_service.dart';

class RefundRequestsScreen extends StatelessWidget {
  final bool isAdmin;

  const RefundRequestsScreen({super.key, this.isAdmin = false});

  static const Color _brand = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);

  Future<void> showRefundSheet(BuildContext context, Pedido pedido) async {
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pedir reembolso',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '#${pedido.id} - ${pedido.total.toStringAsFixed(2)} EUR',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Explica o motivo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (controller.text.trim().length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Escreve um motivo mais detalhado.'),
                        ),
                      );
                      return;
                    }
                    await DatabaseService().requestRefund(
                      pedido: pedido,
                      reason: controller.text,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pedido de reembolso enviado.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Enviar pedido'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Reembolsos' : 'Os meus reembolsos',
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.getRefundRequestsStream(isAdmin: isAdmin),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _brand));
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Text(
                isAdmin
                    ? 'Sem pedidos de reembolso.'
                    : 'Ainda nao tens pedidos de reembolso.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _RefundCard(
              data: requests[index],
              isAdmin: isAdmin,
              onStatus: (status) => db.updateRefundRequestStatus(
                requests[index]['id'].toString(),
                status,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RefundCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isAdmin;
  final ValueChanged<String> onStatus;

  const _RefundCard({
    required this.data,
    required this.isAdmin,
    required this.onStatus,
  });

  Color _statusColor(String status) {
    if (status == 'Aprovado') return Colors.green;
    if (status == 'Recusado') return Colors.red;
    return const Color(0xFFFF8A00);
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'Pendente';
    final date = DateTime.tryParse(data['createdAtText']?.toString() ?? '');
    final dateText = date == null
        ? ''
        : DateFormat('dd/MM/yyyy HH:mm', 'pt_PT').format(date.toLocal());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${data['orderId'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isAdmin)
            Text(
              '${data['userName'] ?? 'Cliente'} - ${data['userEmail'] ?? ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          const SizedBox(height: 8),
          Text(
            data['reason']?.toString() ?? '',
            style: const TextStyle(height: 1.35, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                dateText,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${((data['orderTotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} EUR',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (isAdmin && status == 'Pendente') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onStatus('Recusado'),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => onStatus('Aprovado'),
                    child: const Text('Aprovar'),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}
