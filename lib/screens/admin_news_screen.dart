import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  final DatabaseService db = DatabaseService();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isSending = false;

  // Publica ou atualiza noticias no Firestore.
  Future<void> _submeterNoticia({String? docId}) async {
    if (_tituloController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preenche o título e a descrição!")));
      return;
    }

    setState(() => _isSending = true);

    try {
      final dados = {
        'titulo': _tituloController.text.trim(),
        'desc': _descController.text.trim(),
      };

      if (docId == null) {
        await db.addNoticia(dados); // Criar na API
      } else {
        await db.updateNoticia(docId, dados); // Editar na API
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(docId == null ? "Notícia enviada! 🚀" : "Notícia corrigida! ✏️"),
          backgroundColor: Colors.green,
        ));
        _limparFormulario();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _limparFormulario() {
    _tituloController.clear();
    _descController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Gestão de Notícias 📢", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _limparFormulario();
          _mostrarFormulario(context);
        },
        label: const Text("Nova Notícia", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
        backgroundColor: const Color(0xFFD32F2F),
      ),
      // ✅ StreamBuilder agora usa o getNoticias que criámos no DatabaseService
      body: StreamBuilder<dynamic>(
        stream: db.getNoticias,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
          
          final List<dynamic> noticias = snapshot.data ?? [];

          if (noticias.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("Sem notícias publicadas.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: noticias.length,
            separatorBuilder: (_,__) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              final n = noticias[index];
              final String id = n['_id'] ?? '';
              
              // Formatacao de data simples para ISO String.
              String dataStr = "Recentemente";
              if (n['dataHora'] != null) {
                try {
                  DateTime dt = DateTime.parse(n['dataHora']);
                  dataStr = DateFormat('dd MMM • HH:mm', 'pt_PT').format(dt);
                } catch (_) {}
              }

              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNewsIcon(),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(n['desc'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          const SizedBox(height: 10),
                          Text(dataStr, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 20),
                          onPressed: () {
                            _tituloController.text = n['titulo'] ?? '';
                            _descController.text = n['desc'] ?? '';
                            _mostrarFormulario(context, docId: id);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmarApagar(context, id),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNewsIcon() {
    return Container(
      height: 50, width: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFFF5252)]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
    );
  }

  void _confirmarApagar(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Apagar Notícia?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await db.deleteNoticia(id);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Apagar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarFormulario(BuildContext context, {String? docId}) {
    bool isEditing = docId != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(25, 25, 25, MediaQuery.of(ctx).viewInsets.bottom + 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEditing ? "Corrigir Notícia" : "Enviar Notificação", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 25),
            TextField(controller: _tituloController, decoration: const InputDecoration(labelText: "Título", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: "Mensagem", border: OutlineInputBorder())),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isEditing ? Colors.blue : const Color(0xFFD32F2F)),
                onPressed: _isSending ? null : () => _submeterNoticia(docId: docId),
                child: Text(isEditing ? "SALVAR ALTERAÇÕES" : "PUBLICAR AGORA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
