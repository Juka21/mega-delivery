import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_delivery_app/config/app_config.dart';
import 'package:restaurant_delivery_app/data/menu_seed.dart';
import 'package:restaurant_delivery_app/models/pedido.dart';
import 'package:restaurant_delivery_app/models/prato.dart';

void main() {
  test('AppConfig recognizes configured admin email', () {
    final configuredAdminEmail = AppConfig.adminEmails.first;

    expect(AppConfig.isAdminEmail(configuredAdminEmail), isTrue);
    expect(AppConfig.isAdminEmail(' ${configuredAdminEmail.toUpperCase()} '),
        isTrue);
    expect(AppConfig.isAdminEmail('cliente@example.com'), isFalse);
  });

  test('Menu seed excludes drinks and keeps menu categories', () {
    final categories = menuSeedItems.map((item) => item['categoria']).toSet();

    expect(
      menuSeedCategories,
      [
        'Mega Hambúrguer',
        'Hambúrgueres',
        'Cachorros',
        'Mega Tostas',
        'Tostas',
        'Kebab',
        'Francesinhas',
        'Bitoques',
        'Vegetariano',
        'Kids',
        'Bebidas',
        'Sobremesas',
        'Extras',
      ],
    );
    expect(categories, isNot(contains('Bebidas')));
    expect(
        categories,
        containsAll(
            menuSeedCategories.where((category) => category != 'Bebidas')));
    expect(menuSeedItems.length, 55);
  });

  test('Menu seed extra rules are category-aware', () {
    final megaItem = menuSeedItems.firstWhere(
      (item) => item['nome'].toString().startsWith('Mega Hambúrguer'),
    );
    final normalItem = menuSeedItems.firstWhere(
      (item) => item['nome'] == 'Hambúrguer Simples',
    );
    final francesinha = menuSeedItems.firstWhere(
      (item) => item['categoria'] == 'Francesinhas',
    );

    expect(megaItem['categoria'], 'Mega Hambúrguer');
    expect(normalItem['categoria'], 'Hambúrgueres');
    expect(francesinha['categoria'], 'Francesinhas');
    expect(menuExtrasForItem(megaItem).map((extra) => extra['nome']),
        ['Ingrediente Extra Mega']);
    expect(menuExtrasForItem(normalItem).map((extra) => extra['nome']),
        ['Ingrediente Extra Normal']);
    expect(menuExtrasForItem(francesinha).map((extra) => extra['nome']),
        ['Molho Francesinha']);
  });

  test('Prato.fromMap accepts persisted documents', () {
    final prato = Prato.fromMap({
      '_id': 'abc123',
      'nome': 'Mega Burger',
      'descricao': 'Burger artesanal',
      'preco': 8.5,
      'categoria': 'Hamburgueres',
      'imageUrl': 'https://example.com/burger.png',
      'ingredientes': ['pao', 'carne'],
      'extras': [
        {'nome': 'queijo', 'preco': 1.0}
      ],
      'molhos': ['alho'],
    });

    expect(prato.id, 'abc123');
    expect(prato.nome, 'Mega Burger');
    expect(prato.preco, 8.5);
    expect(prato.extras.single['nome'], 'queijo');
  });

  test('Pedido.fromMap maps order items and fallback fields', () {
    final pedido = Pedido.fromMap({
      '_id': 'pedido1',
      'userId': 'user1',
      'cliente': 'Cliente Teste',
      'status': 'Pendente',
      'dataHora': '2026-06-24T12:00:00.000Z',
      'total': 12.0,
      'itens': [
        {
          'pratoId': 'p1',
          'nome': 'Cachorro',
          'preco': 6.0,
          'quantidade': 2,
        }
      ],
    });

    expect(pedido.id, 'pedido1');
    expect(pedido.estado, 'Pendente');
    expect(pedido.itens.single.nomePrato, 'Cachorro');
    expect(pedido.itens.single.quantidade, 2);
  });
}
