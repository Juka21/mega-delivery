import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pedido.dart';
import '../services/database_service.dart';
import 'tracking_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Pedido pedido;
  const OrderDetailsScreen({super.key, required this.pedido});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  // Cores do Tema Moderno
  final Color _primaryColor = const Color(0xFFD32F2F);
  final Color _accentColor = const Color(0xFF1E272E);
  final Color _bgColor = const Color(0xFFF4F7FA);
  final Color _cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    String dataFormatada;
    try {
      dataFormatada =
          DateFormat('dd MMM, HH:mm', 'pt_PT').format(widget.pedido.data);
    } catch (e) {
      dataFormatada = "Data desconhecida";
    }

    // Determinar estado para UI
    bool isCompleted = widget.pedido.status == 'Entregue' ||
        widget.pedido.status == 'Concluído';
    bool isCancelled = widget.pedido.status == 'Cancelado';
    bool isDelivery = widget.pedido.metodoEntrega == "Entrega";
    bool isTrackingAvailable =
        widget.pedido.status == 'A Caminho' && isDelivery;

    // ✅ CÁLCULO MATEMÁTICO BLINDADO
    // 1. Calculamos o subtotal somando os itens reais
    double subtotalCalculado = 0;
    for (var item in widget.pedido.itens) {
      subtotalCalculado += item.precoUnitario * item.quantidade;
    }

    // 2. A taxa é a diferença (Total - Subtotal)
    // Usamos max(0) para garantir que nunca dá negativo por erros de arredondamento
    double taxaCalculada = (widget.pedido.total - subtotalCalculado);
    if (taxaCalculada < 0) taxaCalculada = 0;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            const Text("DETALHES DO PEDIDO",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text("#${widget.pedido.id.substring(0, 4).toUpperCase()}",
                style: TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
          ],
        ),
        centerTitle: true,
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.black),
          ),
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : Navigator.pushReplacementNamed(context, '/home'),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // 1. HEADER STATUS
            _buildStatusHeader(dataFormatada, isCancelled, isCompleted),

            const SizedBox(height: 25),

            // 2. BOTÃO DE RASTREIO
            if (isTrackingAvailable) ...[
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              TrackingScreen(pedido: widget.pedido)),
                    );
                  },
                  icon: const Icon(Icons.location_on_rounded,
                      color: Colors.white),
                  label: const Text("ACOMPANHAR EM TEMPO REAL",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 30),
            ],

            if (widget.pedido.status == 'Entregue') ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _confirmarRecebido,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    "CONFIRMAR QUE RECEBI",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],

            const Padding(
              padding: EdgeInsets.only(left: 5, bottom: 15),
              child: Text("Itens do Pedido",
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF2D3436))),
            ),

            // 3. LISTA DE PRODUTOS
            Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.pedido.itens.length,
                separatorBuilder: (ctx, i) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE))),
                itemBuilder: (context, index) =>
                    _buildItemCard(widget.pedido.itens[index]),
              ),
            ),

            const SizedBox(height: 30),

            // 4. INFORMAÇÕES DE ENTREGA
            const Padding(
              padding: EdgeInsets.only(left: 5, bottom: 15),
              child: Text("Informações de Entrega",
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF2D3436))),
            ),
            _buildInfoCard(),

            const SizedBox(height: 30),

            // 5. RESUMO DE VALORES (Agora recebe os valores calculados)
            _buildTotalCard(subtotalCalculado, taxaCalculada),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarRecebido() async {
    await DatabaseService()
        .updateOrderStatus(widget.pedido.id, 'Recebido pelo Cliente');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Obrigado! Pedido confirmado.')),
    );
    Navigator.pop(context);
  }

  Widget _buildStatusHeader(String data, bool isCancelled, bool isCompleted) {
    Color color = Colors.orange;
    IconData icon = Icons.access_time_filled_rounded;
    String text = widget.pedido.status;

    if (isCompleted) {
      color = const Color(0xFF00C853);
      icon = Icons.check_circle_rounded;
    } else if (isCancelled) {
      color = const Color(0xFFFF3D00);
      icon = Icons.cancel_rounded;
    } else if (widget.pedido.status == 'A Caminho') {
      color = Colors.deepPurpleAccent;
      icon = Icons.delivery_dining_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(25),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)
                ]),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 15),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 5),
          Text(data,
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildItemCard(dynamic itemParam) {
    // 🛡️ Dizemos ao Flutter que isto é garantidamente um ItemPedido
    final item = itemParam;

    List<String> listaExtras = [];

    // Lemos apenas os Extras (que existem na tua classe ItemPedido)
    if (item.extras.isNotEmpty) {
      for (var e in item.extras) {
        if (e is Map && e.containsKey('nome')) {
          listaExtras.add(e['nome'].toString());
        } else if (e is String) {
          listaExtras.add(e);
        }
      }
    }
    String textoExtras = listaExtras.toSet().map((e) => "+ $e").join('\n');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8)),
          child: Text("${item.quantidade}x",
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _accentColor,
                  fontSize: 14)),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.nomePrato,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2D3436))),
              if (textoExtras.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(textoExtras,
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w500))),
              if (item.nota != null && item.nota!.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text("Nota: ${item.nota}",
                        style: const TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 12,
                            fontStyle: FontStyle.italic))),
            ],
          ),
        ),
        Text("${(item.precoUnitario * item.quantidade).toStringAsFixed(2)}€",
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF2D3436))),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.credit_card_rounded, "Pagamento",
              widget.pedido.metodoPagamento, Colors.blue),
          if (widget.pedido.moradaEntrega != null &&
              widget.pedido.moradaEntrega!.isNotEmpty) ...[
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Divider(height: 1, color: Color(0xFFF5F5F5))),
            _buildInfoRow(Icons.location_on_rounded, "Morada",
                widget.pedido.moradaEntrega!, Colors.redAccent),
          ],
          if (widget.pedido.nif.isNotEmpty) ...[
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Divider(height: 1, color: Color(0xFFF5F5F5))),
            _buildInfoRow(Icons.receipt_long_rounded, "NIF", widget.pedido.nif,
                Colors.orange),
          ]
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
        )
      ],
    );
  }

  // ✅ RECEBE AGORA OS VALORES CALCULADOS
  Widget _buildTotalCard(double subtotal, double taxa) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF2D3436),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          _buildTotalRow(
              "Subtotal", "${subtotal.toStringAsFixed(2)}€", Colors.white60),
          const SizedBox(height: 12),
          _buildTotalRow(
              "Taxa de Entrega", "${taxa.toStringAsFixed(2)}€", Colors.white60),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Colors.white12)),
          _buildTotalRow("TOTAL", "${widget.pedido.total.toStringAsFixed(2)}€",
              Colors.white,
              isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, Color color,
      {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: isTotal ? 26 : 14,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
                letterSpacing: isTotal ? -0.5 : 0)),
      ],
    );
  }
}
