import 'package:flutter/foundation.dart';

class Pedido {
  final String id;
  final String userId;
  final String? nomeCliente;
  final String? telefoneCliente;
  final String? fotoCliente;
  final String? moradaEntrega;
  final double total;
  final String estado;
  final DateTime dataPedido; 
  final List<ItemPedido> itens;
  final String? driverId;
  
  final String metodoEntrega;
  final double taxaEntrega;
  final String? tempoEstimado;
  final String metodoPagamento;
  final String? trocoPara;
  final String nif; 

  final double? driverLat;
  final double? driverLng;
  final double? clienteLat;
  final double? clienteLng;

  Pedido({
    required this.id,
    required this.userId,
    this.nomeCliente,
    this.telefoneCliente,
    this.fotoCliente,
    this.moradaEntrega,
    required this.total,
    required this.estado,
    required this.dataPedido,
    required this.itens,
    this.metodoEntrega = 'Entrega',
    this.taxaEntrega = 0.0,
    this.tempoEstimado,
    this.metodoPagamento = 'N/A', 
    this.trocoPara,
    this.nif = "Consumidor Final",
    this.driverLat,
    this.driverLng,
    this.clienteLat,
    this.clienteLng,
    this.driverId,
  });

  String get status => estado; 
  DateTime get data => dataPedido;
  String get clienteId => userId;

  factory Pedido.fromMap(Map<String, dynamic> data) {
    
    // 🛡️ Lógica de data "À Prova de Bala"
    DateTime dataCorrigida = DateTime.now();
    try {
      if (data['dataHora'] != null && data['dataHora'].toString().isNotEmpty) {
        dataCorrigida = DateTime.parse(data['dataHora'].toString());
      } else if (data['dataPedido'] != null && data['dataPedido'].toString().isNotEmpty) {
        dataCorrigida = DateTime.parse(data['dataPedido'].toString());
      } else if (data['criadoEm'] != null && data['criadoEm'].toString().isNotEmpty) {
        dataCorrigida = DateTime.parse(data['criadoEm'].toString());
      }
    } catch (e) {
      debugPrint("⚠️ Aviso: Formato de data inválido no pedido ${data['_id']}. Usando data atual.");
      // Falha silenciosamente mas mete a data de hoje para a App não crashar!
    }

    // 🛡️ Lógica de itens "À Prova de Bala"
    List<ItemPedido> itensLidos = [];
    try {
      if (data['itens'] != null && data['itens'] is List) {
        itensLidos = (data['itens'] as List).map((item) {
          // Garante que se um item falhar, não deita abaixo o pedido todo
          return ItemPedido.fromMap(Map<String, dynamic>.from(item as Map));
        }).toList();
      }
    } catch (e) {
      debugPrint("⚠️ Aviso: Erro ao ler itens do pedido ${data['_id']}. Lista vazia.");
    }

    return Pedido(
      id: data['_id']?.toString() ?? data['id']?.toString() ?? 'ID_DESCONHECIDO',
      userId: data['userId']?.toString() ?? 'USER_DESCONHECIDO',
      nomeCliente: data['cliente']?.toString() ?? data['nomeCliente']?.toString() ?? 'Cliente',
      telefoneCliente: data['telefoneCliente']?.toString(),
      fotoCliente: data['fotoCliente']?.toString(),
      moradaEntrega: data['morada']?.toString() ?? data['moradaEntrega']?.toString(),
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      taxaEntrega: (data['taxaEntrega'] as num?)?.toDouble() ?? 0.0,
      estado: data['status']?.toString() ?? data['estado']?.toString() ?? 'Pendente',
      dataPedido: dataCorrigida,
      metodoEntrega: data['metodoEntrega']?.toString() ?? 'Entrega',
      tempoEstimado: data['tempoEstimado']?.toString(),
      metodoPagamento: data['metodoPagamento']?.toString() ?? 'N/A',
      nif: data['nif']?.toString() ?? "Consumidor Final",
      itens: itensLidos,
      driverId: data['driverId']?.toString(),
    );
  }
}

class ItemPedido {
  final String id;
  final String nomePrato; 
  final double precoUnitario;
  final int quantidade;
  final List<dynamic> extras;
  final String? nota; 

  ItemPedido({
    required this.id,
    required this.nomePrato,
    required this.precoUnitario,
    required this.quantidade,
    required this.extras,
    this.nota,
  });

  factory ItemPedido.fromMap(Map<String, dynamic> map) {
    return ItemPedido(
      id: map['id']?.toString() ?? map['_id']?.toString() ?? map['pratoId']?.toString() ?? 'ID_ITEM',
      nomePrato: map['nome']?.toString() ?? map['nomePrato']?.toString() ?? "Item Sem Nome", 
      precoUnitario: (map['preco'] as num?)?.toDouble() ?? 0.0,
      quantidade: (map['quantidade'] as num?)?.toInt() ?? 1,
      extras: map['extras'] is List ? map['extras'] : [],
      nota: map['nota']?.toString(),
    );
  }
}