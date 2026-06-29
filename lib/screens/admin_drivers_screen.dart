import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Gerir Estafetas', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDriverForm(context),
        backgroundColor: const Color(0xFFD32F2F),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text('Novo Estafeta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: _db.getDrivers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          }

          final drivers = snapshot.data ?? [];
          if (drivers.isEmpty) {
            return Center(child: Text('Sem estafetas registados', style: TextStyle(color: Colors.grey[600])));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: drivers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final driver = Map<String, dynamic>.from(drivers[index] as Map);
              return _DriverCard(
                driver: driver,
                onDelete: () => _confirmDelete(context, driver),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover estafeta?'),
        content: Text('O estafeta "${driver['nome'] ?? 'Sem nome'}" será removido.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.deleteDriver(driver['id'].toString());
            },
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDriverForm(BuildContext context) {
    final nomeController = TextEditingController();
    final telController = TextEditingController();
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Estafeta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(controller: telController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telemóvel')),
            TextField(controller: pinController, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'PIN')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nomeController.text.trim().isEmpty || pinController.text.trim().length != 4) return;
              await _db.addDriver({
                'nome': nomeController.text.trim(),
                'telefone': telController.text.trim(),
                'pin': pinController.text.trim(),
                'status': 'offline',
                'rating': 5.0,
                'totalVotes': 0,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onDelete;

  const _DriverCard({required this.driver, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = driver['status']?.toString() ?? 'offline';
    final statusColor = status == 'disponivel' ? Colors.green : (status == 'ocupado' ? Colors.orange : Colors.grey);
    final nome = driver['nome']?.toString() ?? 'Sem nome';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('PIN: ${driver['pin'] ?? '---'}', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red)),
        ],
      ),
    );
  }
}
