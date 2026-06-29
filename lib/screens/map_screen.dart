import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _defaultCenter = LatLng(39.74362, -8.80705);

  GoogleMapController? _mapController;
  LatLng _center = _defaultCenter;
  String _enderecoAtual = 'A procurar morada...';
  bool _isLoading = false;
  int _geocodingRequestId = 0;

  @override
  void initState() {
    super.initState();
    _localizarUtilizador();
  }

  @override
  void dispose() {
    _geocodingRequestId++;
    _mapController?.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback callback) {
    if (!mounted) return;
    setState(callback);
  }

  Future<void> _localizarUtilizador() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;

      if (!serviceEnabled) {
        _safeSetState(() => _enderecoAtual = 'GPS desativado');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;

        if (permission == LocationPermission.denied) {
          _safeSetState(() => _enderecoAtual = 'Permissao de GPS negada');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _safeSetState(
          () => _enderecoAtual = 'Permissao de GPS negada permanentemente',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      final newCenter = LatLng(position.latitude, position.longitude);
      _safeSetState(() => _center = newCenter);

      await _mapController?.animateCamera(CameraUpdate.newLatLng(newCenter));
      if (!mounted) return;
      await _obterMoradaPorCoordenadas(newCenter);
    } catch (e) {
      debugPrint('Erro GPS: $e');
      _safeSetState(() => _enderecoAtual = 'Erro ao obter localizacao');
    }
  }

  Future<void> _obterMoradaPorCoordenadas(LatLng pos) async {
    if (!mounted) return;

    final requestId = ++_geocodingRequestId;
    _safeSetState(() => _isLoading = true);

    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      ).timeout(const Duration(seconds: 5));

      if (!mounted || requestId != _geocodingRequestId) return;

      if (placemarks.isEmpty) {
        _safeSetState(() => _enderecoAtual = 'Localizacao sem nome');
        return;
      }

      final place = placemarks.first;
      var rua = place.thoroughfare ?? '';
      final numero = place.subThoroughfare ?? '';
      final cp = place.postalCode ?? '';
      final cidade = place.locality ?? '';

      if (rua.isEmpty) rua = place.subLocality ?? place.name ?? '';

      var moradaFinal = '$rua $numero, $cp $cidade'.trim();
      moradaFinal =
          moradaFinal.replaceAll(RegExp(r'^, | ,$'), '').replaceAll(', ,', ',');

      _safeSetState(() {
        _enderecoAtual =
            moradaFinal.isNotEmpty ? moradaFinal : 'Localizacao sem nome';
      });
    } catch (e) {
      if (requestId == _geocodingRequestId) {
        _safeSetState(() => _enderecoAtual = 'Morada desconhecida');
      }
    } finally {
      if (requestId == _geocodingRequestId) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  bool get _canConfirm =>
      !_isLoading &&
      _enderecoAtual != 'Morada desconhecida' &&
      _enderecoAtual != 'A procurar morada...';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_center != _defaultCenter) {
                _mapController?.animateCamera(CameraUpdate.newLatLng(_center));
              }
            },
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onCameraMove: (position) {
              _center = position.target;
            },
            onCameraIdle: () => _obterMoradaPorCoordenadas(_center),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child:
                  Icon(Icons.location_on, size: 50, color: Colors.deepOrange),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.my_location, color: Colors.blue),
                onPressed: _localizarUtilizador,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Localizacao selecionada',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const LinearProgressIndicator(
                      color: Colors.deepOrange,
                      minHeight: 2,
                    )
                  else
                    Text(
                      _enderecoAtual,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _canConfirm
                          ? () => Navigator.pop(context, _enderecoAtual)
                          : null,
                      child: const Text(
                        'CONFIRMAR ESTE LOCAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
