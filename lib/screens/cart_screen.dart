import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'order_success_screen.dart';
import 'address_screen.dart';
import '../widgets/bouncy_button.dart';
import '../services/opening_hours_service.dart';
import '../services/stripe_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final DatabaseService db = DatabaseService();
  final currentUser = AuthService().currentUser;
  bool _isLoading = false;

  final String googleApiKey = AppConfig.googleGeocodingApiKey;

  final double restauranteLat = 39.74476840811788;
  final double restauranteLng = -8.93533315869812;
  static const double _raioEntregaClienteKm = 10.0;
  static const double _distanciaBaseEntregaKm = 5.0;
  static const double _taxaBaseEntrega = 3.50;
  static const double _taxaPorKmExtra = 1.0;

  String _tipoEntrega = "Entrega";
  double _taxaEntrega = 3.50;
  String _erroGeocoding = "";
  double _distanciaKm = 0.0;
  bool _calculandoLocalizacao = false;
  bool _foraDoRaio = false;
  double? _clienteLat;
  double? _clienteLng;

  String? _selectedDriverId;
  List<dynamic> _motoristasAtivos = [];

  List<dynamic> _minhasMoradas = [];
  dynamic _moradaSelecionada;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarMotoristasAtivos();
      _carregarMoradasDoCliente();
    });
  }

  Future<void> _carregarMoradasDoCliente() async {
    if (currentUser == null) return;
    try {
      final moradas = await db.getUserAddressesOnce(currentUser!.uid);
      setState(() {
        _minhasMoradas = moradas;
        if (_minhasMoradas.isNotEmpty) {
          _moradaSelecionada = _minhasMoradas.first;
        }
      });
      await _calcularTaxaEntrega();
    } catch (e) {
      print("Erro moradas: $e");
    }
  }

  Future<void> _carregarMotoristasAtivos() async {
    try {
      final todos = await db.getDriversOnce();
      setState(() {
        _motoristasAtivos =
            todos.where((m) => m['status'] == 'disponivel').toList();
      });
    } catch (e) {
      print("Erro motoristas: $e");
    }
  }

  Future<void> _calcularTaxaEntrega() async {
    if (!mounted) return;
    if (_tipoEntrega == "Take-Away" || _moradaSelecionada == null) {
      setState(() {
        _taxaEntrega = 0.0;
        _distanciaKm = 0.0;
        _erroGeocoding = "";
        _foraDoRaio = false;
        _clienteLat = null;
        _clienteLng = null;
      });
      return;
    }

    setState(() {
      _calculandoLocalizacao = true;
      _erroGeocoding = "";
    });

    try {
      if (googleApiKey.isEmpty) {
        setState(
            () => _erroGeocoding = "Chave Google Geocoding nao configurada.");
        return;
      }

      String rua = (_moradaSelecionada['rua'] ?? '').toString().trim();
      String cp = (_moradaSelecionada['cp'] ?? '').toString().trim();
      String cidade = (_moradaSelecionada['cidade'] ?? '').toString().trim();

      List<String> partesMorada = [];
      if (rua.isNotEmpty) partesMorada.add(rua);
      if (cp.isNotEmpty || cidade.isNotEmpty)
        partesMorada.add("$cp $cidade".trim());
      partesMorada.add("Portugal");

      String enderecoCompleto = partesMorada.join(", ");

      if (rua.isEmpty && cidade.isEmpty) {
        setState(() => _erroGeocoding = "Morada incompleta (Falta Rua/Cidade)");
        return;
      }

      String url =
          "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeQueryComponent(enderecoCompleto)}&key=$googleApiKey";

      var response = await http.get(Uri.parse(url));
      var data = jsonDecode(response.body);

      if (data['status'] == 'OK') {
        double destLat = data['results'][0]['geometry']['location']['lat'];
        double destLng = data['results'][0]['geometry']['location']['lng'];

        double distanciaKm = Geolocator.distanceBetween(
                restauranteLat, restauranteLng, destLat, destLng) /
            1000;

        if (mounted) {
          setState(() {
            _clienteLat = destLat;
            _clienteLng = destLng;
            _distanciaKm = distanciaKm;
            _foraDoRaio =
                !_isAdminUser() && distanciaKm > _raioEntregaClienteKm;
            _taxaEntrega =
                _foraDoRaio ? 0.0 : _calcularTaxaPorDistancia(distanciaKm);
          });
        }
      } else {
        setState(() {
          _clienteLat = null;
          _clienteLng = null;
          _distanciaKm = 0.0;
          _taxaEntrega = 0.0;
          _foraDoRaio = false;
        });
        setState(() => _erroGeocoding = "Erro Google: ${data['status']}");
      }
    } catch (e) {
      if (mounted) setState(() => _erroGeocoding = "Falha na internet ou API.");
    } finally {
      if (mounted) setState(() => _calculandoLocalizacao = false);
    }
  }

  Future<void> _iniciarPagamento(double total, List<Map<String, dynamic>> itens,
      List<String> cartDocIds) async {
    final storeSettings = await db.getStoreSettingsOnce();
    final storeOpen = storeSettings['isOpen'] != false;
    if (!storeOpen && !_isAdminUser()) {
      final message = storeSettings['closedMessage']?.toString() ??
          DatabaseService.defaultStoreSettings['closedMessage'].toString();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange));
      return;
    }

    if (!_podeFazerPedidoAgora()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Estamos fechados para pedidos. Horario: ${OpeningHoursService.scheduleLabel}."),
          backgroundColor: Colors.orange));
      return;
    }

    if (_tipoEntrega == "Entrega") {
      if (_moradaSelecionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Adiciona uma morada para a entrega!"),
            backgroundColor: Colors.orange));
        return;
      }
      if (_clienteLat == null ||
          _clienteLng == null ||
          _erroGeocoding.isNotEmpty) {
        await _calcularTaxaEntrega();
      }
      if (_clienteLat == null ||
          _clienteLng == null ||
          _erroGeocoding.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_erroGeocoding.isNotEmpty
                  ? _erroGeocoding
                  : "Nao foi possivel validar a morada de entrega."),
              backgroundColor: Colors.orange));
        }
        return;
      }
      if (_foraDoRaio) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("Esta morada está fora do limite de entrega de 10 km."),
            backgroundColor: Colors.red));
        return;
      }
      if (_selectedDriverId == null && _motoristasAtivos.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Por favor, seleciona um estafeta!"),
            backgroundColor: Colors.orange));
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (total < 0.50) throw Exception("O valor mínimo é 0.50€");
      bool pagou = await StripeService.makePayment(total, "eur");
      if (pagou) {
        await _processarPedido(itens, total, "Cartão (Stripe)", cartDocIds);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Aviso: $e"), backgroundColor: Colors.orange));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _podeFazerPedidoAgora() {
    return _isAdminUser() || OpeningHoursService.canPlaceOrder(DateTime.now());
  }

  bool _isAdminUser() {
    final user = AuthService().currentUser ?? currentUser;
    return user?.role == 'admin' || AppConfig.isAdminEmail(user?.email);
  }

  double _calcularTaxaPorDistancia(double distanciaKm) {
    if (distanciaKm <= _distanciaBaseEntregaKm) return _taxaBaseEntrega;
    final kmExtra = (distanciaKm - _distanciaBaseEntregaKm).ceilToDouble();
    return _taxaBaseEntrega + (kmExtra * _taxaPorKmExtra);
  }

  Future<void> _processarPedido(List<Map<String, dynamic>> itens, double total,
      String metodoPagamento, List<String> cartDocIds) async {
    setState(() => _isLoading = true);
    try {
      String moradaFinal = _tipoEntrega == "Entrega"
          ? "${_moradaSelecionada['rua']}, ${_moradaSelecionada['andar'] != null ? 'Andar: ' + _moradaSelecionada['andar'] + ', ' : ''}${_moradaSelecionada['cp']} ${_moradaSelecionada['cidade']}"
          : "Take-Away";

      Map<String, dynamic> pedidoReal = {
        'id': 'PED-${DateTime.now().millisecondsSinceEpoch}',
        'userId': currentUser?.uid ?? 'anonimo',
        'cliente': currentUser?.nome ?? 'Cliente',
        'email': currentUser?.email,
        'itens': itens,
        'total': total,
        'metodoEntrega': _tipoEntrega,
        'morada': moradaFinal,
        'taxaEntrega': _tipoEntrega == "Entrega" ? _taxaEntrega : 0.0,
        'distanciaKm': _tipoEntrega == "Entrega" ? _distanciaKm : 0.0,
        'clienteLat': _tipoEntrega == "Entrega" ? _clienteLat : null,
        'clienteLng': _tipoEntrega == "Entrega" ? _clienteLng : null,
        'driverId': _tipoEntrega == "Entrega" ? _selectedDriverId : null,
        'metodoPagamento': metodoPagamento,
        'status': 'Pendente',
        'dataHora': DateTime.now().toIso8601String()
      };

      final sucesso = await db.criarPedido(pedidoReal);

      if (sucesso) {
        await db.clearCart();
        if (mounted)
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const OrderSuccessScreen()),
              (r) => false);
      } else {
        throw Exception("Nao foi possivel gravar o pedido.");
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
          title: const Text("O Teu Pedido 🛒",
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true),
      body: StreamBuilder<List<dynamic>>(
        stream: db.getCartItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
                child: CircularProgressIndicator(color: Colors.deepOrange));
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return _buildEmptyCart();

          final cartItems = snapshot.data!;
          double subtotal = 0;
          List<Map<String, dynamic>> itensParaPedido = [];
          List<String> cartDocIds = [];

          for (var item in cartItems) {
            cartDocIds.add(item['_id'] ?? item['id']);
            double precoItem = (item['preco'] as num).toDouble();
            subtotal += precoItem * (item['quantidade'] as int);

            // ✅ AGORA OS EXTRAS E NOTAS VIAJAM PARA O SERVIDOR
            itensParaPedido.add({
              'nome': item['nome'],
              'quantidade': item['quantidade'],
              'preco': precoItem,
              'nota': item['notaCliente'] ?? item['nota'] ?? '',
              'ingredientesRemovidos': item['ingredientesRemovidos'] ?? [],
              'molhosSelecionados': item['molhosSelecionados'] ?? [],
              'extras': item['extras'] ?? [],
            });
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 18, right: 18, top: 18, bottom: 130),
                  itemCount: cartItems.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildCartHeader(cartItems.length, subtotal);
                    }
                    final item = cartItems[index - 1];
                    return _buildModernCartItem(
                      item['_id'] ?? item['id'],
                      item,
                    );
                  },
                ),
              ),
              _buildModernProsseguirBar(subtotal, itensParaPedido, cartDocIds),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGETS DE UI PREMIUM ---
  Widget _buildEmptyCart() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 20),
      const Text("O teu carrinho está vazio",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
    ]));
  }

  // ignore: unused_element
  Widget _buildCartItem(String docId, Map<String, dynamic> data) {
    // Lemos as listas que guardaste na base de dados (Hambúrguer)
    List<dynamic> ingRemovidos = data['ingredientesRemovidos'] is String
        ? jsonDecode(data['ingredientesRemovidos'])
        : data['ingredientesRemovidos'] ?? [];
    List<dynamic> molhos = data['molhosSelecionados'] is String
        ? jsonDecode(data['molhosSelecionados'])
        : data['molhosSelecionados'] ?? [];
    List<dynamic> extras = data['extras'] is String
        ? jsonDecode(data['extras'])
        : data['extras'] ?? [];
    String nota = data['notaCliente'] ?? data['nota'] ?? '';

    return Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(data['imageUrl'] ?? '',
                    width: 75,
                    height: 75,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                        width: 75,
                        height: 75,
                        color: Colors.grey[200],
                        child:
                            const Icon(Icons.fastfood, color: Colors.grey)))),
            const SizedBox(width: 15),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text("${data['quantidade']}x ${data['nome']}",
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16))),
                    IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 22),
                        onPressed: () => db.removeFromCart(docId))
                  ],
                ),
                Text("${(data['preco'] as num).toStringAsFixed(2)}€",
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),

                const SizedBox(height: 8),

                // Cores dinâmicas para o Chef ler tudo perfeitamente
                if (ingRemovidos.isNotEmpty)
                  Text("Sem: ${ingRemovidos.join(', ')}",
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),

                if (molhos.isNotEmpty)
                  Text("Molhos: ${molhos.join(', ')}",
                      style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),

                if (extras.isNotEmpty)
                  ...extras.map((e) {
                    String nomeExtra = e['nome'] ?? 'Extra';
                    double precoExtra = (e['preco'] as num?)?.toDouble() ?? 0.0;
                    return Text(
                        "+ $nomeExtra (+${precoExtra.toStringAsFixed(2)}€)",
                        style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w600));
                  }),

                if (nota.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(5)),
                    child: Text('📝 "$nota"',
                        style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold)),
                  )
                ]
              ],
            )),
          ],
        ));
  }

  Widget _buildCartHeader(int itemCount, double subtotal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Revê o teu pedido",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$itemCount item(ns) no carrinho",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${subtotal.toStringAsFixed(2)}€",
            style: const TextStyle(
              color: Color(0xFFFF8A00),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCartItem(String docId, Map<String, dynamic> data) {
    final ingRemovidos = _readList(data['ingredientesRemovidos']);
    final molhos =
        _readList(data['molhosSelecionados'] ?? data['molhos'] ?? []);
    final extras = _readList(data['extras']);
    final nota = data['notaCliente'] ?? data['nota'] ?? '';
    final quantidade = (data['quantidade'] as num?)?.toInt() ?? 1;
    final precoUnitario = (data['preco'] as num?)?.toDouble() ?? 0.0;
    final totalLinha = precoUnitario * quantidade;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8ECF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  data['imageUrl'] ?? '',
                  width: 86,
                  height: 86,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: 86,
                    height: 86,
                    color: const Color(0xFFF0F2F5),
                    child:
                        const Icon(Icons.fastfood_rounded, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            data['nome']?.toString() ?? 'Item',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFF151A20),
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent),
                          onPressed: () => db.removeFromCart(docId),
                        )
                      ],
                    ),
                    Text(
                      "${precoUnitario.toStringAsFixed(2)}€ cada",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildQuantityControl(docId, quantidade),
                        const Spacer(),
                        Text(
                          "${totalLinha.toStringAsFixed(2)}€",
                          style: const TextStyle(
                            color: Color(0xFFFF8A00),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ingRemovidos.isNotEmpty ||
              molhos.isNotEmpty ||
              extras.isNotEmpty ||
              nota.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Detalhes escolhidos",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF151A20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (ingRemovidos.isNotEmpty)
                    _buildDetailLine(
                      icon: Icons.remove_circle_outline_rounded,
                      color: Colors.red,
                      label: "Sem",
                      value: ingRemovidos.join(', '),
                    ),
                  if (molhos.isNotEmpty)
                    _buildDetailLine(
                      icon: Icons.water_drop_outlined,
                      color: Colors.blue,
                      label: "Molhos",
                      value: molhos.join(', '),
                    ),
                  if (extras.isNotEmpty) _buildExtrasLines(extras),
                  if (nota.toString().trim().isNotEmpty)
                    _buildDetailLine(
                      icon: Icons.sticky_note_2_outlined,
                      color: Colors.orange,
                      label: "Nota",
                      value: nota.toString(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<dynamic> _readList(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        return decoded is List ? decoded : [];
      } catch (_) {
        return [];
      }
    }
    return value is List ? value : [];
  }

  Widget _buildQuantityControl(String docId, int quantidade) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
            onPressed: () => db.updateCartItemQuantity(docId, quantidade - 1),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantidade',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => db.updateCartItemQuantity(docId, quantidade + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLine({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF3A414A),
                  fontSize: 13,
                  height: 1.25,
                ),
                children: [
                  TextSpan(
                    text: "$label: ",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasLines(List<dynamic> extras) {
    return Column(
      children: extras.map((extra) {
        final map = extra is Map ? extra : {};
        final nome = map['nome']?.toString() ?? 'Extra';
        final preco = (map['preco'] as num?)?.toDouble() ?? 0.0;
        return _buildDetailLine(
          icon: Icons.add_circle_outline_rounded,
          color: Colors.green,
          label: "Extra",
          value: "$nome (+${preco.toStringAsFixed(2)}€)",
        );
      }).toList(),
    );
  }

  Widget _buildModernProsseguirBar(double subtotal,
      List<Map<String, dynamic>> itens, List<String> cartDocIds) {
    final canOrderNow = _podeFazerPedidoAgora();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shopping_bag_rounded,
                      color: Color(0xFFFF8A00)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Subtotal do pedido",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "${subtotal.toStringAsFixed(2)}€",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF151A20),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!canOrderNow)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "Fora de horário",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            BouncyButton(
              onPressed: () async {
                await _carregarMoradasDoCliente();
                await _carregarMotoristasAtivos();
                _showDeliveryOptions(subtotal, itens, cartDocIds);
              },
              child: Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8A00).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    "REVER ENTREGA E PAGAR • ${subtotal.toStringAsFixed(2)}€",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildProsseguirBar(double subtotal, List<Map<String, dynamic>> itens,
      List<String> cartDocIds) {
    return Container(
      // ✅ MAGIA AQUI: O padding bottom: 90 sobe o painel para fugir da barra preta do ecrã inicial!
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 25),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5))
          ]),
      child: SafeArea(
          top: false,
          child: BouncyButton(
              onPressed: () async {
                await _carregarMoradasDoCliente();
                await _carregarMotoristasAtivos();
                _showDeliveryOptions(subtotal, itens, cartDocIds);
              },
              child: Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFD32F2F).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ]),
                  child: Center(
                      child: Text("CHECKOUT • ${subtotal.toStringAsFixed(2)}€",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1)))))),
    );
  }

  void _showDeliveryOptions(double subtotal, List<Map<String, dynamic>> itens,
      List<String> cartDocIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        double totalFinal =
            subtotal + (_tipoEntrega == "Take-Away" ? 0 : _taxaEntrega);

        return Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Configura a tua Entrega 🛵",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: _buildModalToggle(
                        "🛵 Entrega", "Entrega", setModalState)),
                Expanded(
                    child: _buildModalToggle(
                        "🛍️ Take-Away", "Take-Away", setModalState)),
              ]),
              if (_tipoEntrega == 'Entrega') ...[
                const SizedBox(height: 20),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("A TUA MORADA DE ENTREGA",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 12))),
                const SizedBox(height: 10),
                if (_minhasMoradas.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3))),
                    child: Column(
                      children: [
                        const Text("Ainda não tens moradas guardadas.",
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const AddressScreen()))
                                .then((_) => _carregarMoradasDoCliente());
                          },
                          icon: const Icon(Icons.add_location,
                              color: Colors.white),
                          label: const Text("Adicionar Morada",
                              style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.blue.withOpacity(0.2))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<dynamic>(
                        isExpanded: true,
                        value: _moradaSelecionada,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.blue),
                        items: _minhasMoradas.map((m) {
                          return DropdownMenuItem<dynamic>(
                            value: m,
                            child: Text("${m['nome']} - ${m['rua']}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          setModalState(() => _moradaSelecionada = val);
                          setState(() => _moradaSelecionada = val);
                          await _calcularTaxaEntrega();
                          setModalState(() {});
                        },
                      ),
                    ),
                  ),
                if (_moradaSelecionada != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.straighten,
                          color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Text("Distância: ${_distanciaKm.toStringAsFixed(1)} km",
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_erroGeocoding.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text("⚠️ $_erroGeocoding",
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold))),
                  if (_calculandoLocalizacao)
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("A calcular rota...",
                            style:
                                TextStyle(color: Colors.blue, fontSize: 12))),
                  if (_foraDoRaio && _erroGeocoding.isEmpty)
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            "Lamentamos, estás fora do limite de entrega de 10 km!",
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Estafetas",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 12)),
                    InkWell(
                      onTap: () async {
                        await _carregarMotoristasAtivos();
                        setModalState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh, color: Colors.blue, size: 16),
                            SizedBox(width: 4),
                            Text("Atualizar",
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_motoristasAtivos.isEmpty)
                  const Text("Nenhum estafeta disponível no momento.",
                      style: TextStyle(color: Colors.red))
                else
                  Column(
                    children: _motoristasAtivos.map((m) {
                      String id = m['_id'] ?? m['id'];
                      bool isSelected = _selectedDriverId == id;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedDriverId = id);
                          setState(() => _selectedDriverId = id);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.05),
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.transparent),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.motorcycle, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(m['nome'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            const Text(" Online",
                                style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
              ],
              const Divider(height: 30),
              if (_tipoEntrega == 'Entrega')
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Taxa de Entrega",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold)),
                        Text("+ ${_taxaEntrega.toStringAsFixed(2)}€",
                            style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold))
                      ]),
                ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("TOTAL A PAGAR",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${totalFinal.toStringAsFixed(2)}€",
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.deepOrange))
              ]),
              const SizedBox(height: 20),
              BouncyButton(
                onPressed: _isLoading
                    ? () {}
                    : () {
                        Navigator.pop(context);
                        _iniciarPagamento(totalFinal, itens, cartDocIds);
                      },
                child: Container(
                    height: 55,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(15)),
                    child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("PAGAR COM CARTÃO",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)))),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildModalToggle(
      String label, String val, StateSetter setModalState) {
    bool isSel = _tipoEntrega == val;
    return GestureDetector(
      onTap: () async {
        setModalState(() => _tipoEntrega = val);
        setState(() => _tipoEntrega = val);
        if (val == "Entrega") await _calcularTaxaEntrega();
        setModalState(() {});
      },
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: isSel
                  ? Colors.deepOrange.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12)),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isSel ? Colors.deepOrange : Colors.grey,
                  fontWeight: FontWeight.bold))),
    );
  }
}
