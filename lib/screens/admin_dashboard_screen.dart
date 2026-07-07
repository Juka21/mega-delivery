import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'admin_drivers_screen.dart';
import 'admin_logs_screen.dart';
import 'admin_menu_screen.dart';
import 'admin_news_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_store_settings_screen.dart';
import 'printer_screen.dart';
import 'refund_requests_screen.dart';
import 'support_tickets_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const Color _brand = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);
  static const Color _surface = Color(0xFFF6F7FB);

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Painel de Admin',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: db.getAdminDashboardSummary(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          return RefreshIndicator(
            color: _brand,
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              children: [
                _HeroSummary(data: data),
                const SizedBox(height: 16),
                StreamBuilder<Map<String, dynamic>>(
                  stream: db.storeSettingsStream,
                  builder: (context, storeSnapshot) {
                    final store = storeSnapshot.data ??
                        DatabaseService.defaultStoreSettings;
                    final isOpen = store['isOpen'] != false;
                    return _StoreStatusCard(
                      isOpen: isOpen,
                      message: store['closedMessage']?.toString() ?? '',
                      onTap: () => _open(
                        context,
                        const AdminStoreSettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Operacao'),
                _ActionGrid(actions: [
                  _AdminAction(
                    icon: Icons.receipt_long_rounded,
                    color: Colors.blue,
                    title: 'Pedidos live',
                    subtitle: 'Cozinha e estados',
                    onTap: () => _open(context, const AdminOrdersScreen()),
                  ),
                  _AdminAction(
                    icon: Icons.fastfood_rounded,
                    color: _brand,
                    title: 'Menu',
                    subtitle: 'Produtos e precos',
                    onTap: () => _open(context, const AdminMenuScreen()),
                  ),
                  _AdminAction(
                    icon: Icons.motorcycle_rounded,
                    color: Colors.purple,
                    title: 'Estafetas',
                    subtitle: 'Equipa e PINs',
                    onTap: () => _open(context, const AdminDriversScreen()),
                  ),
                  _AdminAction(
                    icon: Icons.print_rounded,
                    color: Colors.teal,
                    title: 'Impressora',
                    subtitle: 'USB e testes',
                    onTap: () => _open(context, const PrinterScreen()),
                  ),
                ]),
                const SizedBox(height: 18),
                const _SectionTitle('Clientes e controlo'),
                _ActionGrid(actions: [
                  _AdminAction(
                    icon: Icons.support_agent_rounded,
                    color: Colors.deepOrange,
                    title: 'Suporte',
                    subtitle: '${data['openTickets'] ?? 0} abertos',
                    onTap: () => _open(
                      context,
                      const SupportTicketsScreen(isAdmin: true),
                    ),
                  ),
                  _AdminAction(
                    icon: Icons.undo_rounded,
                    color: Colors.redAccent,
                    title: 'Reembolsos',
                    subtitle: '${data['pendingRefunds'] ?? 0} pendentes',
                    onTap: () => _open(
                      context,
                      const RefundRequestsScreen(isAdmin: true),
                    ),
                  ),
                  _AdminAction(
                    icon: Icons.campaign_rounded,
                    color: Colors.green,
                    title: 'Noticias',
                    subtitle: 'Enviar avisos',
                    onTap: () => _open(context, const AdminNewsScreen()),
                  ),
                  _AdminAction(
                    icon: Icons.history_rounded,
                    color: Colors.blueGrey,
                    title: 'Logs',
                    subtitle: 'Auditoria interna',
                    onTap: () => _open(context, const AdminLogsScreen()),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _HeroSummary extends StatelessWidget {
  final Map<String, dynamic> data;

  const _HeroSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final todayTotal = ((data['todayTotal'] as num?)?.toDouble() ?? 0);
    final rating = ((data['averageRating'] as num?)?.toDouble() ?? 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17212B),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Color(0xFFFF8A00)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Hoje no Mega Delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: 'Caixa',
                  value: '${todayTotal.toStringAsFixed(2)} EUR',
                  icon: Icons.euro_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  label: 'Pedidos',
                  value: '${data['todayOrders'] ?? 0}',
                  icon: Icons.shopping_bag_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: 'Ativos',
                  value: '${data['activeOrders'] ?? 0}',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  label: 'Rating',
                  value: rating <= 0 ? '-' : rating.toStringAsFixed(1),
                  icon: Icons.star_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 19),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _StoreStatusCard extends StatelessWidget {
  final bool isOpen;
  final String message;
  final VoidCallback onTap;

  const _StoreStatusCard({
    required this.isOpen,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isOpen ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isOpen ? Icons.storefront_rounded : Icons.lock_clock_rounded,
                  color: isOpen ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOpen ? 'Loja aberta' : 'Loja fechada',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOpen ? 'Clientes podem finalizar pedidos.' : message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final List<_AdminAction> actions;

  const _ActionGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.08,
      ),
      itemBuilder: (context, index) => _ActionCard(action: actions[index]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _AdminAction action;

  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(action.icon, color: action.color),
              ),
              const Spacer(),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF17212B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                action.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAction {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
