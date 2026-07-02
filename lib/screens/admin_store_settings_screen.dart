import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AdminStoreSettingsScreen extends StatefulWidget {
  const AdminStoreSettingsScreen({super.key});

  @override
  State<AdminStoreSettingsScreen> createState() =>
      _AdminStoreSettingsScreenState();
}

class _AdminStoreSettingsScreenState extends State<AdminStoreSettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _messageController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool isOpen, required String message}) async {
    setState(() => _saving = true);
    try {
      await _db.updateStoreSettings(
        isOpen: isOpen,
        closedMessage: message.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado da loja atualizado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Estado da Loja'),
        backgroundColor: const Color(0xFFF6F7FB),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _db.storeSettingsStream,
        builder: (context, snapshot) {
          final data = snapshot.data ?? DatabaseService.defaultStoreSettings;
          final isOpen = data['isOpen'] != false;
          final message =
              data['closedMessage']?.toString() ?? 'Estamos fechados.';

          if (_messageController.text.isEmpty) {
            _messageController.text = message;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOpen
                              ? Icons.storefront_rounded
                              : Icons.lock_clock_rounded,
                          color: isOpen ? Colors.green : Colors.red,
                          size: 34,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            isOpen ? 'Loja aberta' : 'Loja fechada',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Switch(
                          value: isOpen,
                          activeThumbColor: Colors.green,
                          onChanged: _saving
                              ? null
                              : (value) => _save(
                                    isOpen: value,
                                    message: _messageController.text,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem quando a loja esta fechada',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _save(
                                  isOpen: isOpen,
                                  message: _messageController.text,
                                ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Guardar mensagem'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Quando a loja estiver fechada manualmente, os clientes conseguem ver o menu mas nao conseguem finalizar pedidos. O admin continua com permissao para testar.',
                style: TextStyle(color: Colors.grey, height: 1.45),
              ),
            ],
          );
        },
      ),
    );
  }
}
