import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../services/database_service.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  // Adaptado para datas guardadas em ISO String.
  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return "Recentemente";
    
    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return "Recentemente";
      }
      return DateFormat('dd MMM • HH:mm', 'pt_PT').format(date);
    } catch (e) {
      return "Recentemente";
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Novidades", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Usa o Stream do DatabaseService ligado ao Firestore.
      body: StreamBuilder<dynamic>(
        stream: db.getNoticias,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar notícias."));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
          }

          // O teu servidor envia uma List<dynamic>
          final List<dynamic> news = snapshot.data ?? [];

          if (news.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_read_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("Tudo lido por agora!", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: news.length,
            itemBuilder: (context, index) {
              final data = news[index] as Map<String, dynamic>;
              
              String titulo = data['titulo'] ?? "Sem Título";
              String desc = data['desc'] ?? "";
              String emoji = data['emoji'] ?? "📢"; 
              
              // Verifica se é recente (lógica de 24h)
              bool isRecent = false;
              if (data['dataHora'] != null) {
                try {
                  final newsDate = DateTime.parse(data['dataHora']);
                  final diff = DateTime.now().difference(newsDate);
                  if (diff.inHours < 24) isRecent = true;
                } catch (_) {}
              }

              return _buildNewsCard(
                titulo: titulo,
                desc: desc,
                date: _formatDate(data['dataHora']),
                emoji: emoji,
                isNew: isRecent,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNewsCard({
    required String titulo,
    required String desc,
    required String date,
    required String emoji,
    required bool isNew,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 50, width: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        titulo, 
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2),
                      ),
                    ),
                    if (isNew)
                      Container(
                        margin: const EdgeInsets.only(left: 8, top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                        child: const Text("NOVO", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4)),
                const SizedBox(height: 10),
                Text(date, style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
