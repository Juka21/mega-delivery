import 'package:flutter/material.dart';
import 'admin_orders_screen.dart';
import 'admin_menu_screen.dart';
import 'admin_news_screen.dart';
import 'admin_drivers_screen.dart';
import 'printer_screen.dart';
import 'support_tickets_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Painel do Chefe 👑",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _buildDashboardCard(context,
              icon: Icons.receipt_long_rounded,
              color: Colors.blue,
              title: "Pedidos Live",
              subtitle: "Cozinha & Impressora",
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminOrdersScreen()))),
          _buildDashboardCard(context,
              icon: Icons.fastfood_rounded,
              color: Colors.orange,
              title: "Gestão Menu",
              subtitle: "Criar & Editar Pratos",
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminMenuScreen()))),
          _buildDashboardCard(context,
              icon: Icons.campaign_rounded,
              color: Colors.green,
              title: "Notícias",
              subtitle: "Avisar Clientes",
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminNewsScreen()))),
          _buildDashboardCard(context,
              icon: Icons.motorcycle_rounded,
              color: Colors.purple,
              title: "Estafetas",
              subtitle: "Gerir Equipa",
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminDriversScreen()))),
          _buildDashboardCard(context,
              icon: Icons.support_agent_rounded,
              color: Colors.deepOrange,
              title: "Suporte",
              subtitle: "Tickets dos Clientes",
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const SupportTicketsScreen(isAdmin: true)))),
          _buildDashboardCard(context,
              icon: Icons.print_rounded,
              color: Colors.teal,
              title: "Impressora",
              subtitle:
                  "Configurar USB", // Até mudei para USB para ficar certinho!
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrinterScreen()))),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 15),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 5),
            Text(subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
