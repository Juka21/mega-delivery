import 'dart:typed_data';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

class PrinterService {
  // 👇 INÍCIO DO CÓDIGO MÁGICO (SINGLETON) 👇
  // Isto garante que usamos sempre a MESMA conexão em toda a App
  static final PrinterService _instance = PrinterService._internal();

  factory PrinterService() {
    return _instance;
  }

  PrinterService._internal();
  // 👆 FIM DO CÓDIGO MÁGICO 👆

  final FlutterUsbPrinter _printer = FlutterUsbPrinter();
  bool _isConnected = false;

  // Obter lista de dispositivos USB ligados
  Future<List<Map<String, dynamic>>> getUSBDevices() async {
    try {
      return await FlutterUsbPrinter.getUSBDeviceList();
    } catch (e) {
      print("Erro ao listar USB: $e");
      return [];
    }
  }

  // Conectar à impressora
  Future<bool> connect(int vendorId, int productId) async {
    try {
      // Tenta conectar
      bool? connected = await _printer.connect(vendorId, productId);
      
      // Atualiza o estado da memória
      _isConnected = connected ?? false;
      
      return _isConnected;
    } catch (e) {
      print("Erro ao conectar USB: $e");
      _isConnected = false;
      return false;
    }
  }

  // Verificar conexão
  bool get isConnected => _isConnected;

  // Desconectar (Só chama isto se quiseres mesmo desligar)
  Future<void> disconnect() async {
    try {
      await _printer.close();
      _isConnected = false;
    } catch (e) {
      print("Erro ao desconectar: $e");
    }
  }

  // 📝 GERAR E IMPRIMIR O TALÃO
  Future<void> printOrderTicket(Map<String, dynamic> pedido, String orderId) async {
    if (!_isConnected) {
      print("⚠️ TENTATIVA FALHADA: Impressora não conectada!");
      return;
    }

    try {
      // 1. Configurar o perfil da impressora
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // 2. CONSTRUIR O TALÃO
      // Cabeçalho
      bytes += generator.text('MEGA DELIVERY', 
          styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
      bytes += generator.text('Cozinha / Estafeta', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr(); 

      // Dados do Pedido
      String dataHora = DateFormat('dd/MM HH:mm').format(DateTime.now());
      bytes += generator.row([
        PosColumn(text: '#${orderId.substring(0, 4).toUpperCase()}', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(text: dataHora, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr();

      // Dados do Cliente
      String nomeCliente = pedido['userName'] ?? "Cliente";
      String telefone = pedido['userPhone'] ?? "N/A";
      String morada = pedido['morada'] ?? "Levantamento";

      bytes += generator.text('CLIENTE:', styles: const PosStyles(bold: true));
      bytes += generator.text(nomeCliente);
      bytes += generator.text(telefone);
      bytes += generator.text(morada);
      bytes += generator.hr();

      // Itens do Pedido
      List<dynamic> itens = pedido['itens'] ?? [];
      
      for (var item in itens) {
        String nomePrato = item['nome'];
        int qtd = item['quantidade'];
        
        // Nome do Prato Grande
        bytes += generator.text('${qtd}x $nomePrato', 
            styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size1));

        // Detalhes
        List<dynamic> removidos = item['removidos'] ?? [];
        List<dynamic> molhos = item['molhos'] ?? [];
        List<dynamic> extras = item['extras'] ?? [];
        String nota = item['nota'] ?? "";

        if (removidos.isNotEmpty) {
           bytes += generator.text('   [SEM]: ${removidos.join(', ')}', styles: const PosStyles(codeTable: 'CP860'));
        }
        if (molhos.isNotEmpty) {
           bytes += generator.text('   [MOLHOS]: ${molhos.join(', ')}');
        }
        if (extras.isNotEmpty) {
           String nomesExtras = extras.map((e) => e['nome']).join(', ');
           bytes += generator.text('   [EXTRAS]: $nomesExtras');
        }
        if (nota.isNotEmpty) {
           bytes += generator.text('   [NOTA]: $nota', styles: const PosStyles(bold: true, reverse: true));
        }
        bytes += generator.feed(1);
      }

      // Rodapé
      bytes += generator.hr();
      double total = (pedido['total'] ?? 0).toDouble();
      bytes += generator.text('TOTAL: ${total.toStringAsFixed(2)} EUR', 
          styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
      
      bytes += generator.feed(2);
      bytes += generator.text('Obrigado pela preferencia!', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(3);
      bytes += generator.cut(); 

      // 3. ENVIAR PARA A IMPRESSORA
      await _printer.write(Uint8List.fromList(bytes));
      print("✅ Talão enviado com sucesso!");

    } catch (e) {
      print("❌ Erro ao imprimir: $e");
    }
  }
}