import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  static const Color _brand = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Logs internos',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.auditLogsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _brand));
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Text(
                'Ainda nao existem logs.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _LogCard(data: logs[index]),
          );
        },
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _LogCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(data['createdAtText']?.toString() ?? '');
    final dateText = date == null
        ? ''
        : DateFormat('dd/MM HH:mm', 'pt_PT').format(date.toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDF3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A00).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: Color(0xFFFF8A00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['action']?.toString() ?? 'Acao',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17212B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    data['actorName']?.toString() ?? 'Sistema',
                    dateText,
                  ].where((part) => part.isNotEmpty).join(' - '),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if ((data['details'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    data['details'].toString(),
                    style: const TextStyle(height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
