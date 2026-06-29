import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/pedido.dart';
import '../services/database_service.dart';

class TrackingScreen extends StatelessWidget {
  final Pedido pedido;

  const TrackingScreen({super.key, required this.pedido});

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Acompanhar Pedido"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: db.getOrderStream(pedido.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Pedido não encontrado.'));
          }

          final driverLat = _toDouble(data['driverLat']);
          final driverLng = _toDouble(data['driverLng']);
          final clienteLat = _toDouble(data['clienteLat']);
          final clienteLng = _toDouble(data['clienteLng']);
          final status = data['status']?.toString() ?? pedido.status;

          if (driverLat == null || driverLng == null) {
            return _WaitingTracking(status: status);
          }

          final driverPosition = LatLng(driverLat, driverLng);
          final clientePosition = clienteLat != null && clienteLng != null
              ? LatLng(clienteLat, clienteLng)
              : null;

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: driverPosition,
                  zoom: 15,
                ),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: {
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: driverPosition,
                    infoWindow: const InfoWindow(title: 'Estafeta'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    ),
                  ),
                  if (clientePosition != null)
                    Marker(
                      markerId: const MarkerId('cliente'),
                      position: clientePosition,
                      infoWindow: const InfoWindow(title: 'Entrega'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                },
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: _TrackingCard(
                  status: status,
                  hasClientLocation: clientePosition != null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WaitingTracking extends StatelessWidget {
  final String status;

  const _WaitingTracking({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_rounded,
                size: 84, color: Colors.orange[300]),
            const SizedBox(height: 20),
            Text(
              status,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              'A localização aparece assim que o estafeta começar a partilhar o GPS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final String status;
  final bool hasClientLocation;

  const _TrackingCard({
    required this.status,
    required this.hasClientLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.navigation_rounded, color: Colors.orange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasClientLocation
                      ? 'A acompanhar estafeta e ponto de entrega.'
                      : 'A acompanhar localização do estafeta.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
