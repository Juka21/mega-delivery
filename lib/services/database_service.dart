import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/menu_seed.dart';
import '../models/prato.dart';
import '../models/pedido.dart';
import 'auth_service.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, dynamic> _withId(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return {
      ...data,
      'id': doc.id,
      '_id': doc.id,
    };
  }

  String _dateToIso(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String) return value;
    return DateTime.now().toIso8601String();
  }

  Map<String, dynamic> _normalizePedido(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = _withId(doc);
    data['dataHora'] = _dateToIso(data['dataHora'] ?? data['createdAt']);
    data['status'] = data['status'] ?? data['estado'] ?? 'Pendente';
    return data;
  }

  bool _isCurrentUserOrder(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final userId = data['userId']?.toString() ?? '';
    final itens = data['itens'];

    return id.startsWith('PED-') &&
        userId.isNotEmpty &&
        itens is List &&
        itens.isNotEmpty;
  }

  Map<String, dynamic> _normalizeNoticia(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = _withId(doc);
    data['dataHora'] = _dateToIso(data['dataHora'] ?? data['createdAt']);
    return data;
  }

  Map<String, dynamic> _normalizeMenuItem(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = _withId(doc);
    final nome = data['nome']?.toString().trim().toLowerCase() ?? '';
    final categoria = data['categoria']?.toString() ?? '';

    if (nome.startsWith('mega hamb')) {
      data['categoria'] = 'Mega Hambúrguer';
    } else if (nome.startsWith('mega tosta')) {
      data['categoria'] = 'Mega Tostas';
    } else if (categoria == 'Bitoque') {
      data['categoria'] = 'Bitoques';
    }

    final extras = data['extras'];
    if (extras is List &&
        extras.any((extra) {
          final extraName =
              extra is Map ? extra['nome']?.toString().toLowerCase() : '';
          return extraName == 'ingrediente extra normal' ||
              extraName == 'ingrediente extra mega' ||
              extraName == 'ingrediente extra';
        })) {
      data['extras'] = defaultIngredientExtras;
    }

    return data;
  }

  int _compareByDateDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
    return _dateToIso(b['dataHora'] ?? b['createdAt'])
        .compareTo(_dateToIso(a['dataHora'] ?? a['createdAt']));
  }

  int _menuCategoryIndex(String categoria) {
    final index = menuSeedCategories.indexOf(categoria);
    return index == -1 ? menuSeedCategories.length : index;
  }

  int _comparePratos(Prato a, Prato b) {
    final cat = _menuCategoryIndex(a.categoria)
        .compareTo(_menuCategoryIndex(b.categoria));
    return cat != 0 ? cat : a.nome.compareTo(b.nome);
  }

  Future<List<Prato>> getPratos() async {
    final snapshot = await _db.collection('menu').get();
    final pratos = snapshot.docs
        .map((doc) => Prato.fromMap(_normalizeMenuItem(doc)))
        .toList();
    pratos.sort(_comparePratos);
    return pratos;
  }

  Stream<List<Prato>> get menuStream {
    return _db.collection('menu').snapshots().map((snapshot) {
      final pratos = snapshot.docs
          .map((doc) => Prato.fromMap(_normalizeMenuItem(doc)))
          .toList();
      pratos.sort(_comparePratos);
      return pratos;
    });
  }

  Future<void> addPrato(Map<String, dynamic> dados) async {
    await _db.collection('menu').add({
      ...dados,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePrato(String id, Map<String, dynamic> dados) async {
    await _db.collection('menu').doc(id).set({
      ...dados,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deletePrato(String id) async {
    await _db.collection('menu').doc(id).delete();
  }

  Future<int> importarCardapioPadrao() async {
    final batch = _db.batch();

    for (final item in menuSeedItems) {
      final id = item['id'].toString();
      final ref = _db.collection('menu').doc(id);
      final existing = await ref.get();
      final existingImageUrl = existing.data()?['imageUrl']?.toString() ?? '';

      batch.set(
          ref,
          {
            ...item,
            'descricao': '',
            'imageUrl': existingImageUrl.isNotEmpty
                ? existingImageUrl
                : item['imageUrl'],
            'extras': menuExtrasForItem(item),
            'updatedAt': FieldValue.serverTimestamp(),
            if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }

    await batch.commit();
    return menuSeedItems.length;
  }

  Stream<List<dynamic>> getCartItems() async* {
    while (true) {
      final prefs = await SharedPreferences.getInstance();
      String? cartString = prefs.getString('cart');
      yield cartString != null ? json.decode(cartString) : [];
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> addToCart({
    required Prato prato,
    required int quantidade,
    double? precoUnitario,
    List<String> ingredientesRemovidos = const [],
    String? notaCliente,
    List<Map<String, dynamic>> extras = const [],
    List<String> molhosSelecionados = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> cart = [];
    String? cartString = prefs.getString('cart');

    if (cartString != null) {
      cart = json.decode(cartString);
    }

    bool listasIguais(List a, List b) {
      if (a.length != b.length) return false;
      for (var item in a) {
        if (!b.contains(item)) return false;
      }
      return true;
    }

    bool extrasIguais(List a, List b) {
      if (a.length != b.length) return false;
      var nomesA = a.map((e) => e['nome']).toList();
      var nomesB = b.map((e) => e['nome']).toList();
      return listasIguais(nomesA, nomesB);
    }

    int indexEncontrado = cart.indexWhere((itemCart) {
      if (itemCart['pratoId'] != prato.id) return false;
      if ((itemCart['nota'] ?? '') != (notaCliente ?? '')) return false;
      if (!listasIguais(
          itemCart['ingredientesRemovidos'] ?? [], ingredientesRemovidos))
        return false;
      if (!listasIguais(itemCart['molhos'] ?? [], molhosSelecionados))
        return false;
      if (!extrasIguais(itemCart['extras'] ?? [], extras)) return false;
      return true;
    });

    if (indexEncontrado != -1) {
      cart[indexEncontrado]['quantidade'] += quantidade;
    } else {
      cart.add({
        '_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'pratoId': prato.id,
        'nome': prato.nome,
        'preco': precoUnitario ?? prato.preco,
        'imageUrl': prato.imageUrl,
        'quantidade': quantidade,
        'ingredientesRemovidos': ingredientesRemovidos,
        'nota': notaCliente,
        'extras': extras,
        'molhos': molhosSelecionados,
      });
    }

    await prefs.setString('cart', json.encode(cart));
  }

  Future<void> removeFromCart(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    String? cartString = prefs.getString('cart');

    if (cartString != null) {
      List<dynamic> cart = json.decode(cartString);
      cart.removeWhere((item) => item['_id'] == itemId || item['id'] == itemId);
      await prefs.setString('cart', json.encode(cart));
    }
  }

  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cart');
  }

  Future<bool> criarPedido(Map<String, dynamic> pedidoData) async {
    try {
      await _db.collection('pedidos').doc(pedidoData['id']?.toString()).set({
        ...pedidoData,
        'status': pedidoData['status'] ?? 'Pendente',
        'estado': pedidoData['estado'] ?? pedidoData['status'] ?? 'Pendente',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Pedido>> get userOrders {
    final user = AuthService().currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('pedidos')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final pedidos = snapshot.docs
          .map(_normalizePedido)
          .where(_isCurrentUserOrder)
          .toList()
        ..sort(_compareByDateDesc);
      return pedidos.map(Pedido.fromMap).toList();
    });
  }

  Stream<List<Pedido>> getOrdersByStatusStream(String status) {
    return _db
        .collection('pedidos')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      final pedidos = snapshot.docs.map(_normalizePedido).toList()
        ..sort(_compareByDateDesc);
      return pedidos.map(Pedido.fromMap).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> get allOrdersStream {
    return _db
        .collection('pedidos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_normalizePedido).toList(),
        );
  }

  Stream<Map<String, dynamic>?> getOrderStream(String orderId) {
    return _db.collection('pedidos').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _normalizePedido(doc);
    });
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final snapshot = await _db
        .collection('pedidos')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(_normalizePedido).toList();
  }

  Future<List<Map<String, dynamic>>> getOrdersForUser(String userId) async {
    final snapshot = await _db
        .collection('pedidos')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map(_normalizePedido).toList()
      ..sort(_compareByDateDesc);
  }

  Stream<List<dynamic>> get getNoticias {
    return _db
        .collection('noticias')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_normalizeNoticia).toList(),
        );
  }

  Future<Map<String, dynamic>?> getDriverByPin(String pin) async {
    final snapshot = await _db
        .collection('drivers')
        .where('pin', isEqualTo: pin)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _withId(snapshot.docs.first);
  }

  Future<void> saveDriverToken(String driverId) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _db.collection('drivers').doc(driverId).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<dynamic>> getUserAddresses(String userId) {
    return _db
        .collection('moradas')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_withId).toList(),
        );
  }

  Future<List<dynamic>> getUserAddressesOnce(String userId) async {
    final snapshot = await _db
        .collection('moradas')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map(_withId).toList();
  }

  Future<void> saveUserAddress({
    required String userId,
    required String nome,
    required String rua,
    String? andar,
    required String cp,
    required String cidade,
  }) async {
    await _db.collection('moradas').add({
      'userId': userId,
      'nome': nome,
      'rua': rua,
      'andar': andar,
      'cp': cp,
      'cidade': cidade,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAddress(String addressId) async {
    await _db.collection('moradas').doc(addressId).delete();
  }

  Stream<List<dynamic>> get getDrivers {
    return _db.collection('drivers').orderBy('nome').snapshots().map(
          (snapshot) => snapshot.docs.map(_withId).toList(),
        );
  }

  Future<List<dynamic>> getDriversOnce() async {
    final snapshot = await _db.collection('drivers').orderBy('nome').get();
    return snapshot.docs.map(_withId).toList();
  }

  Future<void> addDriver(Map<String, dynamic> data) async {
    await _db.collection('drivers').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDriver(String id) async {
    await _db.collection('drivers').doc(id).delete();
  }

  Future<void> addNoticia(Map<String, dynamic> data) async {
    await _db.collection('noticias').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'dataHora': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateNoticia(String id, Map<String, dynamic> data) async {
    await _db.collection('noticias').doc(id).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteNoticia(String id) async {
    await _db.collection('noticias').doc(id).delete();
  }

  Future<void> updateDriverLocation(
      String orderId, double lat, double lng) async {
    await _db.collection('pedidos').doc(orderId).set({
      'driverLat': lat,
      'driverLng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> assignDriverToOrder(String orderId, String driverId) async {
    await _db.collection('pedidos').doc(orderId).set({
      'driverId': driverId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> incrementDriverDeliveries(String driverId) async {
    await _db.collection('drivers').doc(driverId).set({
      'deliveries': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getActiveOrderForDriver(String driverId) async {
    final snapshot = await _db
        .collection('pedidos')
        .where('driverId', isEqualTo: driverId)
        .get();
    final pedidos = snapshot.docs
        .map(_normalizePedido)
        .where((p) => p['status'] == 'A Caminho')
        .toList();
    if (pedidos.isEmpty) return null;
    return pedidos.first;
  }

  Stream<dynamic> getDriverStatusStream(String driverId) {
    return _db
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .map((doc) => doc.exists ? _withId(doc) : null);
  }

  Future<void> updateOrderStatus(
    String pedidoId,
    String novoEstado, {
    String? tempoEstimado,
  }) async {
    final data = <String, dynamic>{
      'status': novoEstado,
      'estado': novoEstado,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (tempoEstimado != null) {
      data['tempoEstimado'] = tempoEstimado;
    }

    await _db.collection('pedidos').doc(pedidoId).set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<void> updateDriver(String driverId, Map<String, dynamic> dados) async {
    await _db.collection('drivers').doc(driverId).set({
      ...dados,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<dynamic>> getChatHistory(String pedidoId) async {
    final snapshot = await _db
        .collection('pedidos')
        .doc(pedidoId)
        .collection('messages')
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map((doc) {
      final data = _withId(doc);
      data['timestamp'] = _dateToIso(data['timestamp'] ?? data['createdAt']);
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getChatStream(String pedidoId) {
    return _db
        .collection('pedidos')
        .doc(pedidoId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = _withId(doc);
              data['timestamp'] =
                  _dateToIso(data['timestamp'] ?? data['createdAt']);
              return data;
            }).toList());
  }

  Future<void> sendChatMessage(
      String pedidoId, Map<String, dynamic> message) async {
    await _db.collection('pedidos').doc(pedidoId).collection('messages').add({
      ...message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> uploadImage(File file) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final ref = _storage.ref().child('uploads/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateUserProfile(
      {required String uid, required Map<String, dynamic> dados}) async {
    try {
      await _db.collection('users').doc(uid).set({
        ...dados,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }
}
