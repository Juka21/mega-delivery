import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';

class DriverScreen extends StatefulWidget {
  final String? driverId;
  const DriverScreen({super.key, this.driverId});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final DatabaseService _db = DatabaseService();
  final String googleApiKey = AppConfig.googleGeocodingApiKey;

  late final String? _driverId;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  StreamSubscription<Position>? _positionStream;
  GoogleMapController? _mapController;
  LatLng? _destinoCliente;
  String? _pedidoAtivoId;
  final Set<Polyline> _polylines = {};

  int _abaAtual = 0;
  bool _isOnline = true;
  bool _isLoading = true;
  List<dynamic> _pedidosDisponiveis = [];
  List<dynamic> _pedidosEmCurso = [];

  @override
  void initState() {
    super.initState();
    _driverId = widget.driverId ?? AuthService().currentUser?.uid;
    _setDriverStatus('disponivel');
    _ouvirPedidos();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _setDriverStatus(String status) async {
    if (_driverId == null) return;
    await _db.updateDriver(_driverId!, {'status': status});
  }

  void _ouvirPedidos() {
    if (_driverId == null) return;

    _ordersSubscription = _db.allOrdersStream.listen(
      (pedidos) => _aplicarPedidos(pedidos),
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  bool _pedidoPertenceAoEstafeta(Map<String, dynamic> pedido) {
    final driverId = pedido['driverId']?.toString() ?? '';
    return driverId.isEmpty || driverId == _driverId;
  }

  void _aplicarPedidos(List<Map<String, dynamic>> pedidos) {
    final pedidosDisponiveis = pedidos
        .where((p) =>
            p['status'] == 'Pronto para Recolha' &&
            _pedidoPertenceAoEstafeta(p))
        .toList();
    final pedidosEmCurso = pedidos
        .where((p) => p['status'] == 'A Caminho' && p['driverId'] == _driverId)
        .toList();
    final pedidoAtivoAindaExiste =
        pedidosEmCurso.any((p) => (p['id'] ?? p['_id']) == _pedidoAtivoId);
    final deveFocar = _pedidoAtivoId == null && pedidosEmCurso.isNotEmpty;

    if (!mounted) return;
    setState(() {
      _pedidosDisponiveis = pedidosDisponiveis;
      _pedidosEmCurso = pedidosEmCurso;
      _isLoading = false;
      if (!pedidoAtivoAindaExiste && !deveFocar) {
        _pedidoAtivoId = null;
        _destinoCliente = null;
        _polylines.clear();
      }
    });

    if (deveFocar) {
      unawaited(
        _focarNoMapa(Map<String, dynamic>.from(pedidosEmCurso.first)),
      );
    }
  }

  Future<void> _carregarPedidos() async {
    setState(() => _isLoading = true);
    try {
      final pedidos = await _db.getAllOrders();
      _aplicarPedidos(pedidos);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _aceitarEntrega(Map<String, dynamic> pedido) async {
    if (_driverId == null) return;
    final pedidoId = (pedido['id'] ?? pedido['_id']).toString();
    await _db.assignDriverToOrder(pedidoId, _driverId!);
    await _db.updateOrderStatus(pedidoId, 'A Caminho');
    _focarNoMapa(pedido);
    await _carregarPedidos();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Pedido aceite. A calcular rota...'),
            backgroundColor: Colors.green[700]),
      );
    }
  }

  Future<void> _focarNoMapa(Map<String, dynamic> pedido) async {
    setState(() {
      _pedidoAtivoId = (pedido['id'] ?? pedido['_id']).toString();
      _abaAtual = 1;
      _destinoCliente = null;
      _polylines.clear();
    });

    final morada = pedido['morada']?.toString() ?? '';
    if (morada.isNotEmpty && morada != 'Take-Away' && googleApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeQueryComponent(morada)}&key=$googleApiKey',
        );
        final response = await http.get(url);
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final loc = data['results'][0]['geometry']['location'];
          setState(() => _destinoCliente = LatLng(
              (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()));
        }
      } catch (_) {}
    }

    if (_pedidoAtivoId != null) {
      await _iniciarStreamGPS(_pedidoAtivoId!);
    }
  }

  Future<void> _finalizarEntrega() async {
    if (_pedidoAtivoId == null) return;
    await _positionStream?.cancel();
    await _db.updateOrderStatus(_pedidoAtivoId!, 'Entregue');
    await _setDriverStatus('disponivel');
    setState(() {
      _pedidoAtivoId = null;
      _destinoCliente = null;
      _polylines.clear();
      _abaAtual = 0;
    });
    await _carregarPedidos();
  }

  Future<void> _iniciarStreamGPS(String pedidoId) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    await _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen((pos) {
      _db.updateDriverLocation(pedidoId, pos.latitude, pos.longitude);
      final current = LatLng(pos.latitude, pos.longitude);
      if (_destinoCliente != null && _polylines.isEmpty) {
        _getDirections(current, _destinoCliente!);
      }
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
              target: current, zoom: 17, bearing: pos.heading, tilt: 45)));
    });
  }

  Future<void> _getDirections(LatLng start, LatLng end) async {
    if (googleApiKey.isEmpty) return;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&key=$googleApiKey',
    );
    final response = await http.get(url);
    final data = jsonDecode(response.body);
    if (data['status'] != 'OK') return;

    final encoded = data['routes'][0]['overview_polyline']['points'].toString();
    if (!mounted) return;
    setState(() {
      _polylines.add(Polyline(
        polylineId: const PolylineId('rota_entrega'),
        points: _decodePolyline(encoded),
        color: Colors.blueAccent,
        width: 5,
      ));
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _abrirMapaExterno() async {
    if (_destinoCliente == null) return;
    final url = Uri.parse(
        'google.navigation:q=${_destinoCliente!.latitude},${_destinoCliente!.longitude}&mode=d');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _abrirChatEntrega(String pedidoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen.delivery(
          pedidoId: pedidoId,
          title: 'Chat com o Cliente',
          subtitle:
              'Pedido #${pedidoId.length > 5 ? pedidoId.substring(pedidoId.length - 5) : pedidoId}',
        ),
      ),
    );
  }

  Future<void> _desligarTurno() async {
    await _setDriverStatus('offline');
    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    if (_driverId == null) {
      return const Scaffold(
          body: Center(child: Text('Erro: sem ID de estafeta.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text('Zona de Estafeta',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: const Icon(Icons.two_wheeler_rounded, color: Colors.orange),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _carregarPedidos),
          IconButton(
              icon: const Icon(Icons.power_settings_new_rounded,
                  color: Colors.red),
              onPressed: _desligarTurno),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTopTabs(),
                Expanded(
                  child: IndexedStack(
                    index: _abaAtual,
                    children: [
                      _buildPainelTarefas(),
                      _pedidoAtivoId != null
                          ? _buildMapaNavegacao()
                          : const Center(
                              child: Text(
                                  'Aceita um pedido primeiro para ver o GPS.')),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _tab('Tarefas', Icons.list_alt, 0, Colors.blue)),
          const SizedBox(width: 10),
          Expanded(child: _tab('Mapa', Icons.map_rounded, 1, Colors.orange)),
        ],
      ),
    );
  }

  Widget _tab(String label, IconData icon, int index, Color color) {
    final selected = _abaAtual == index;
    return GestureDetector(
      onTap: () => setState(() => _abaAtual = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? color : Colors.grey),
          const SizedBox(width: 8),
          Text(label)
        ]),
      ),
    );
  }

  Widget _buildPainelTarefas() {
    return RefreshIndicator(
      onRefresh: _carregarPedidos,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusHeader(),
          const SizedBox(height: 20),
          _section('A Entregar', _pedidosEmCurso, true),
          const SizedBox(height: 20),
          _section('Disponíveis', _pedidosDisponiveis, false),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: _isOnline ? Colors.green : Colors.grey,
          borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Expanded(
              child: Text(_isOnline ? 'Online e disponível' : 'Offline',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
          Switch(
            value: _isOnline,
            activeThumbColor: Colors.white,
            onChanged: (value) async {
              setState(() => _isOnline = value);
              await _setDriverStatus(value ? 'disponivel' : 'offline');
            },
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<dynamic> pedidos, bool emCurso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (pedidos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: const Text('Sem pedidos nesta categoria.',
                textAlign: TextAlign.center),
          )
        else
          ...pedidos.map(
              (p) => _orderCard(Map<String, dynamic>.from(p as Map), emCurso)),
      ],
    );
  }

  Widget _orderCard(Map<String, dynamic> pedido, bool emCurso) {
    final pedidoId = (pedido['id'] ?? pedido['_id']).toString();
    final shortId = pedidoId.length > 5
        ? pedidoId.substring(pedidoId.length - 5)
        : pedidoId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Icon(emCurso ? Icons.sports_motorsports : Icons.fastfood,
              color: emCurso ? Colors.blue : Colors.orange),
          title: Text('Pedido #$shortId',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle:
              Text(pedido['morada']?.toString() ?? 'Morada não especificada'),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (emCurso)
                IconButton(
                  tooltip: 'Chat',
                  onPressed: () => _abrirChatEntrega(pedidoId),
                  icon: const Icon(Icons.chat_bubble_rounded),
                  color: Colors.orange,
                ),
              ElevatedButton(
                onPressed: () =>
                    emCurso ? _focarNoMapa(pedido) : _aceitarEntrega(pedido),
                child: Text(emCurso ? 'Mapa' : 'Aceitar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapaNavegacao() {
    return Stack(
      children: [
        GoogleMap(
          padding: const EdgeInsets.only(bottom: 150),
          initialCameraPosition:
              const CameraPosition(target: LatLng(39.744, -8.935), zoom: 15),
          onMapCreated: (controller) => _mapController = controller,
          myLocationEnabled: true,
          zoomControlsEnabled: false,
          polylines: _polylines,
          markers: _destinoCliente != null
              ? {
                  Marker(
                      markerId: const MarkerId('dest'),
                      position: _destinoCliente!)
                }
              : {},
        ),
        Positioned(
            bottom: 100, left: 20, right: 20, child: _buildControlPanel()),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pedidoAtivoId == null
                  ? null
                  : () => _abrirChatEntrega(_pedidoAtivoId!),
              icon: const Icon(Icons.chat_bubble_rounded),
              label: const Text('Falar com Cliente'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _abrirMapaExterno,
                      icon: const Icon(Icons.map),
                      label: const Text('Abrir GPS'))),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton.icon(
                      onPressed: _finalizarEntrega,
                      icon: const Icon(Icons.check),
                      label: const Text('Entregue'))),
            ],
          ),
        ],
      ),
    );
  }
}
