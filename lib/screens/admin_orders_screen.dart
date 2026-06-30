import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../services/printer_service.dart';
import 'chat_screen.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  static const String pending = 'Pendente';
  static const String accepted = 'Aceite';
  static const String preparing = 'Em Preparação';
  static const String readyPickup = 'Pronto para Recolha';
  static const String done = 'Feito';
  static const String onTheWay = 'A Caminho';
  static const String delivered = 'Entregue';
  static const String receivedByClient = 'Recebido pelo Cliente';
  static const String completed = 'Concluído';
  static const String cancelled = 'Cancelado';

  Color _statusColor(String status) {
    if (status.contains('Caminho')) return Colors.purple;
    if (status.contains('Cliente') || status.contains('Conclu')) {
      return Colors.teal;
    }
    if (status.contains('Cancelado')) return Colors.red;
    if (status.contains('Recolha') || status == done) return Colors.green;
    if (status.contains('Prepara')) return Colors.blue;
    if (status == accepted) return Colors.indigo;
    return Colors.orange;
  }

  bool _isCompleted(Map<String, dynamic> pedido) {
    return (pedido['status'] ?? '').toString() == completed;
  }

  Future<void> _updateStatus(
    BuildContext context,
    String id,
    String status, {
    String? tempoEstimado,
  }) async {
    await DatabaseService()
        .updateOrderStatus(id, status, tempoEstimado: tempoEstimado);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pedido atualizado para $status')),
      );
    }
  }

  Future<void> _acceptOrder(BuildContext context, String id) async {
    final tempo = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '30 min');
        return AlertDialog(
          title: const Text('Tempo de demora'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Ex: 25 min',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Aceitar pedido'),
            ),
          ],
        );
      },
    );

    if (tempo == null || tempo.isEmpty || !context.mounted) return;
    await _updateStatus(context, id, accepted, tempoEstimado: tempo);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _printOrder(
      BuildContext context, Map<String, dynamic> pedido) async {
    final printer = PrinterService();
    if (!printer.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Impressora desligada. Liga a impressora no menu Impressora.')),
      );
      return;
    }

    await printer.printOrderTicket({
      'userName': pedido['cliente'] ?? pedido['nomeCliente'] ?? 'Cliente',
      'userPhone': pedido['telefoneCliente'] ?? '',
      'morada': pedido['metodoEntrega'] == 'Take-Away'
          ? 'Levantamento em Loja'
          : (pedido['morada'] ?? ''),
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
        title: const Text(
          'Pedidos em Tempo Real',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            tooltip: 'Pedidos concluídos',
            icon: const Icon(Icons.calculate_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CompletedOrdersScreen(),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.allOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          }

          final pedidos = (snapshot.data ?? [])
              .where((pedido) => !_isCompleted(pedido))
              .toList();
          if (pedidos.isEmpty) {
            return Center(
              child: Text(
                'Sem pedidos ativos por agora.',
                style: TextStyle(
                    color: Colors.grey[600], fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pedidos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              final id = pedido['id']?.toString() ??
                  pedido['_id']?.toString() ??
                  'pedido';
              return _OrderCard(
                pedido: pedido,
                color: _statusColor((pedido['status'] ?? pending).toString()),
                onAccept: () => _acceptOrder(context, id),
                onStatus: (status) => _updateStatus(context, id, status),
                onPrint: () => _printOrder(context, pedido),
                onCall: (phone) => _makePhoneCall(phone),
              );
            },
          );
        },
      ),
    );
  }
}

class CompletedOrdersScreen extends StatelessWidget {
  const CompletedOrdersScreen({super.key});

  Future<void> _closeToday(BuildContext context, DatabaseService db) async {
    final result = await db.closeCashDay(DateTime.now());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Fecho atualizado.'),
        backgroundColor:
            result['success'] == true ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Pedidos Concluídos',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.allOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pedidos = (snapshot.data ?? [])
              .where((pedido) =>
                  (pedido['status'] ?? '').toString() ==
                      AdminOrdersScreen.completed &&
                  _isSameDay(_orderDate(pedido), DateTime.now()))
              .toList();
          final total = pedidos.fold<double>(
            0,
            (sum, pedido) => sum + ((pedido['total'] as num?)?.toDouble() ?? 0),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total concluído hoje',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${total.toStringAsFixed(2)} EUR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${pedidos.length} pedidos',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _closeToday(context, db),
                  icon: const Icon(Icons.lock_clock_rounded),
                  label: const Text(
                    'Fechar dia de hoje',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CashStatsPanel(db: db),
              const SizedBox(height: 16),
              if (pedidos.isEmpty)
                const Center(child: Text('Ainda não há pedidos concluídos.'))
              else
                ...pedidos.map((pedido) {
                  final id = pedido['id']?.toString() ??
                      pedido['_id']?.toString() ??
                      'pedido';
                  final cliente = pedido['cliente']?.toString() ??
                      pedido['nomeCliente']?.toString() ??
                      'Cliente';
                  final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(cliente,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('#${_shortId(id)}'),
                      trailing: Text('${total.toStringAsFixed(2)} EUR',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  String _shortId(String id) {
    return id.length > 5 ? id.substring(id.length - 5).toUpperCase() : id;
  }

  DateTime _orderDate(Map<String, dynamic> pedido) {
    final value =
        pedido['dataHora']?.toString() ?? pedido['createdAt']?.toString() ?? '';
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CashStatsPanel extends StatefulWidget {
  final DatabaseService db;

  const _CashStatsPanel({required this.db});

  @override
  State<_CashStatsPanel> createState() => _CashStatsPanelState();
}

class _CashStatsPanelState extends State<_CashStatsPanel> {
  String _selectedPeriod = 'Dia';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.db.cashClosuresStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _StatsError(message: snapshot.error.toString());
        }

        final closures = snapshot.data ?? [];
        final daySeries = _buildTrendSeries(closures, 'Dia');
        final weekSeries = _buildTrendSeries(closures, 'Semana');
        final monthSeries = _buildTrendSeries(closures, 'Mês');
        final yearSeries = _buildTrendSeries(closures, 'Ano');
        final selectedSeries = _buildTrendSeries(closures, _selectedPeriod);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estatísticas de caixa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                _StatTile(
                  label: 'Dia',
                  total: _seriesMoneyTotal(daySeries),
                  sales: _seriesSalesTotal(daySeries),
                  selected: _selectedPeriod == 'Dia',
                  onTap: () => setState(() => _selectedPeriod = 'Dia'),
                ),
                _StatTile(
                  label: 'Semana',
                  total: _seriesMoneyTotal(weekSeries),
                  sales: _seriesSalesTotal(weekSeries),
                  selected: _selectedPeriod == 'Semana',
                  onTap: () => setState(() => _selectedPeriod = 'Semana'),
                ),
                _StatTile(
                  label: 'Mês',
                  total: _seriesMoneyTotal(monthSeries),
                  sales: _seriesSalesTotal(monthSeries),
                  selected: _selectedPeriod == 'Mês',
                  onTap: () => setState(() => _selectedPeriod = 'Mês'),
                ),
                _StatTile(
                  label: 'Ano',
                  total: _seriesMoneyTotal(yearSeries),
                  sales: _seriesSalesTotal(yearSeries),
                  selected: _selectedPeriod == 'Ano',
                  onTap: () => setState(() => _selectedPeriod = 'Ano'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _TrendChart(period: _selectedPeriod, points: selectedSeries),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Dia',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        Text('Pedidos',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        SizedBox(width: 22),
                        Text('Total',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (closures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Ainda não existem dias fechados.'),
                    )
                  else
                    ...closures.take(30).map((closure) {
                      final date = _closureDate(closure);
                      final total =
                          (closure['total'] as num?)?.toDouble() ?? 0.0;
                      final pedidos =
                          (closure['pedidos'] as num?)?.toInt() ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child:
                                  Text(DateFormat('dd/MM/yyyy').format(date)),
                            ),
                            Text('$pedidos'),
                            const SizedBox(width: 42),
                            Text(
                              '${total.toStringAsFixed(2)} EUR',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<_TrendPoint> _buildTrendSeries(
      List<Map<String, dynamic>> closures, String period) {
    final now = DateTime.now();
    final buckets = <_TrendPoint>[];

    if (period == 'Dia') {
      final today = DateTime(now.year, now.month, now.day);
      for (var i = 13; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        buckets.add(_TrendPoint(
          start: date,
          label: DateFormat('dd/MM').format(date),
        ));
      }
    } else if (period == 'Semana') {
      final currentWeek = _weekStart(now);
      for (var i = 7; i >= 0; i--) {
        final date = currentWeek.subtract(Duration(days: i * 7));
        buckets.add(_TrendPoint(
          start: date,
          label: DateFormat('dd/MM').format(date),
        ));
      }
    } else if (period == 'Mês') {
      final currentMonth = DateTime(now.year, now.month);
      for (var i = 11; i >= 0; i--) {
        final date = DateTime(currentMonth.year, currentMonth.month - i);
        buckets.add(_TrendPoint(
          start: date,
          label: DateFormat('MMM', 'pt_PT').format(date),
        ));
      }
    } else {
      final currentYear = DateTime(now.year);
      for (var i = 4; i >= 0; i--) {
        final date = DateTime(currentYear.year - i);
        buckets.add(_TrendPoint(
          start: date,
          label: date.year.toString(),
        ));
      }
    }

    for (final closure in closures) {
      final date = _closureDate(closure);
      final bucketIndex = buckets.indexWhere(
        (bucket) => _belongsToBucket(date, bucket.start, period),
      );
      if (bucketIndex == -1) continue;
      final current = buckets[bucketIndex];
      buckets[bucketIndex] = current.copyWith(
        money: current.money + _winTotal(closure),
        sales: current.sales + ((closure['pedidos'] as num?)?.toInt() ?? 0),
      );
    }

    return buckets;
  }

  bool _belongsToBucket(DateTime date, DateTime bucketStart, String period) {
    if (period == 'Dia') return _isSameDay(date, bucketStart);
    if (period == 'Semana') return _isSameDay(_weekStart(date), bucketStart);
    if (period == 'Mês') {
      return date.year == bucketStart.year && date.month == bucketStart.month;
    }
    return date.year == bucketStart.year;
  }

  DateTime _weekStart(DateTime date) {
    final currentDay = DateTime(date.year, date.month, date.day);
    return currentDay.subtract(Duration(days: currentDay.weekday - 1));
  }

  double _seriesMoneyTotal(List<_TrendPoint> points) {
    return points.fold<double>(
      0,
      (total, point) => total + point.money,
    );
  }

  int _seriesSalesTotal(List<_TrendPoint> points) {
    return points.fold<int>(
      0,
      (total, point) => total + point.sales,
    );
  }

  double _winTotal(Map<String, dynamic> closure) {
    return (closure['winTotal'] as num?)?.toDouble() ??
        (closure['total'] as num?)?.toDouble() ??
        0.0;
  }

  DateTime _closureDate(Map<String, dynamic> closure) {
    return DateTime.tryParse(closure['data']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _TrendPoint {
  final DateTime start;
  final String label;
  final double money;
  final int sales;

  const _TrendPoint({
    required this.start,
    required this.label,
    this.money = 0,
    this.sales = 0,
  });

  _TrendPoint copyWith({double? money, int? sales}) {
    return _TrendPoint(
      start: start,
      label: label,
      money: money ?? this.money,
      sales: sales ?? this.sales,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final double total;
  final int sales;
  final bool selected;
  final VoidCallback onTap;

  const _StatTile({
    required this.label,
    required this.total,
    required this.sales,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${total.toStringAsFixed(2)} EUR',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$sales vendas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white70 : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final String period;
  final List<_TrendPoint> points;

  const _TrendChart({required this.period, required this.points});

  @override
  Widget build(BuildContext context) {
    final totalMoney = points.fold<double>(0, (sum, item) => sum + item.money);
    final totalSales = points.fold<int>(0, (sum, item) => sum + item.sales);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparação por $period',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Linha laranja: dinheiro gerado. Linha azul: número de vendas.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _LegendDot(color: Colors.deepOrange, label: 'Dinheiro'),
              SizedBox(width: 14),
              _LegendDot(color: Colors.blue, label: 'Vendas'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendChartPainter(points: points),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ${totalMoney.toStringAsFixed(2)} EUR',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$totalSales vendas',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<_TrendPoint> points;

  _TrendChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(0, 8, size.width, size.height - 44);
    final axisPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + (chartRect.height / 3) * i;
      canvas.drawLine(
          Offset(chartRect.left, y), Offset(chartRect.right, y), axisPaint);
    }

    final moneyMax = _maxMoney();
    final salesMax = _maxSales();
    final moneyOffsets = _offsetsForMoney(chartRect, moneyMax);
    final salesOffsets = _offsetsForSales(chartRect, salesMax);

    _drawLine(canvas, salesOffsets, Colors.blue, verticalShift: 4);
    _drawLine(canvas, moneyOffsets, Colors.deepOrange, verticalShift: -4);
    _drawLabels(canvas, chartRect);
  }

  double _maxMoney() {
    final maxValue = points.fold<double>(
      0,
      (max, point) => point.money > max ? point.money : max,
    );
    return maxValue <= 0 ? 1 : maxValue;
  }

  int _maxSales() {
    final maxValue = points.fold<int>(
      0,
      (max, point) => point.sales > max ? point.sales : max,
    );
    return maxValue <= 0 ? 1 : maxValue;
  }

  List<Offset> _offsetsForMoney(Rect rect, double maxValue) {
    return List.generate(points.length, (index) {
      final point = points[index];
      final x = _xForIndex(rect, index);
      final y = rect.bottom - (point.money / maxValue) * rect.height;
      return Offset(x, y);
    });
  }

  List<Offset> _offsetsForSales(Rect rect, int maxValue) {
    return List.generate(points.length, (index) {
      final point = points[index];
      final x = _xForIndex(rect, index);
      final y = rect.bottom - (point.sales / maxValue) * rect.height;
      return Offset(x, y);
    });
  }

  double _xForIndex(Rect rect, int index) {
    if (points.length <= 1) return rect.left;
    return rect.left + (rect.width / (points.length - 1)) * index;
  }

  void _drawLine(
    Canvas canvas,
    List<Offset> offsets,
    Color color, {
    double verticalShift = 0,
  }) {
    if (offsets.isEmpty) return;
    final shiftedOffsets = offsets
        .map((offset) => Offset(offset.dx, offset.dy + verticalShift))
        .toList();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = color;
    final path = Path()
      ..moveTo(shiftedOffsets.first.dx, shiftedOffsets.first.dy);
    for (final offset in shiftedOffsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, paint);
    for (final offset in shiftedOffsets) {
      canvas.drawCircle(offset, 3.5, dotPaint);
    }
  }

  void _drawLabels(Canvas canvas, Rect rect) {
    if (points.isEmpty) return;
    final indexes = <int>{0, points.length ~/ 2, points.length - 1};
    for (final index in indexes) {
      final point = points[index];
      final textPainter = TextPainter(
        text: TextSpan(
          text: point.label,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: 70);
      final x = (_xForIndex(rect, index) - textPainter.width / 2)
          .clamp(0.0, rect.width - textPainter.width);
      textPainter.paint(canvas, Offset(x, rect.bottom + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _StatsError extends StatelessWidget {
  final String message;

  const _StatsError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Não foi possível carregar estatísticas: $message',
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final Color color;
  final VoidCallback onAccept;
  final ValueChanged<String> onStatus;
  final VoidCallback onPrint;
  final ValueChanged<String> onCall;

  const _OrderCard({
    required this.pedido,
    required this.color,
    required this.onAccept,
    required this.onStatus,
    required this.onPrint,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final id =
        pedido['id']?.toString() ?? pedido['_id']?.toString() ?? 'pedido';
    final status = pedido['status']?.toString() ?? AdminOrdersScreen.pending;
    final cliente = pedido['cliente']?.toString() ??
        pedido['nomeCliente']?.toString() ??
        'Cliente';
    final telefone = pedido['telefoneCliente']?.toString() ?? '';
    final itens = List<dynamic>.from(pedido['itens'] ?? []);
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;
    final metodoEntrega = pedido['metodoEntrega']?.toString() ?? 'Entrega';
    final tempoEstimado = pedido['tempoEstimado']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${_shortId(id)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded),
              ),
              _StatusPill(status: status, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(cliente,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            metodoEntrega,
            style:
                TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w700),
          ),
          if (tempoEstimado.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tempo estimado: $tempoEstimado',
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (telefone.isNotEmpty)
            TextButton.icon(
              onPressed: () => onCall(telefone),
              icon: const Icon(Icons.phone, size: 16),
              label: Text(telefone),
            ),
          if (metodoEntrega != 'Take-Away')
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen.delivery(
                    pedidoId: id,
                    title: 'Chat Entrega',
                    subtitle: cliente,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 16),
              label: const Text('Ver chat cliente/estafeta'),
            ),
          const Divider(),
          ...itens.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${map['quantidade'] ?? 1}x ${map['nome'] ?? map['nomePrato'] ?? 'Item'}',
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Total: ${total.toStringAsFixed(2)} EUR',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _buildWorkflowActions(status, metodoEntrega),
        ],
      ),
    );
  }

  Widget _buildWorkflowActions(String status, String metodoEntrega) {
    final isTakeAway = metodoEntrega == 'Take-Away';

    if (status == AdminOrdersScreen.pending) {
      return _ActionButton(
        label: 'Aceitar e definir tempo',
        icon: Icons.timer_rounded,
        color: Colors.orange,
        onPressed: onAccept,
      );
    }

    if (status == AdminOrdersScreen.accepted) {
      return _ActionButton(
        label: 'Em preparação',
        icon: Icons.restaurant_rounded,
        color: Colors.blue,
        onPressed: () => onStatus(AdminOrdersScreen.preparing),
      );
    }

    if (status == AdminOrdersScreen.preparing) {
      return _ActionButton(
        label: isTakeAway ? 'Feito' : 'Pronto para recolha',
        icon: isTakeAway ? Icons.done_all_rounded : Icons.delivery_dining,
        color: Colors.green,
        onPressed: () => onStatus(
          isTakeAway ? AdminOrdersScreen.done : AdminOrdersScreen.readyPickup,
        ),
      );
    }

    if (status == AdminOrdersScreen.done) {
      return _ActionButton(
        label: 'Entregue ao cliente',
        icon: Icons.handshake_rounded,
        color: Colors.teal,
        onPressed: () => onStatus(AdminOrdersScreen.delivered),
      );
    }

    if (status == AdminOrdersScreen.receivedByClient) {
      return _ActionButton(
        label: 'Concluir pedido',
        icon: Icons.check_circle_rounded,
        color: Colors.black,
        onPressed: () => onStatus(AdminOrdersScreen.completed),
      );
    }

    if (status == AdminOrdersScreen.readyPickup) {
      return const _WaitingLabel(
        icon: Icons.two_wheeler_rounded,
        text: 'A aguardar recolha do estafeta',
      );
    }

    if (status == AdminOrdersScreen.onTheWay) {
      return const _WaitingLabel(
        icon: Icons.route_rounded,
        text: 'Estafeta a caminho',
      );
    }

    if (status == AdminOrdersScreen.delivered) {
      return const _WaitingLabel(
        icon: Icons.verified_user_rounded,
        text: 'A aguardar confirmação do cliente',
      );
    }

    return _ActionButton(
      label: 'Cancelar pedido',
      icon: Icons.cancel_rounded,
      color: Colors.red,
      onPressed: () => onStatus(AdminOrdersScreen.cancelled),
    );
  }

  String _shortId(String id) {
    return id.length > 5 ? id.substring(id.length - 5).toUpperCase() : id;
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _WaitingLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WaitingLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
