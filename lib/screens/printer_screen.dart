import 'package:flutter/material.dart';
import '../services/printer_service.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final PrinterService _printerService = PrinterService();
  List<Map<String, dynamic>> _devices = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _buscarDispositivos();
  }

  void _buscarDispositivos() async {
    var devices = await _printerService.getUSBDevices();
    setState(() {
      _devices = devices;
    });
  }

  void _conectar(Map<String, dynamic> device) async {
    // vendorId e productId são números que identificam o USB
    int vendorId = int.parse(device['vendorId']);
    int productId = int.parse(device['productId']);
    
    bool sucesso = await _printerService.connect(vendorId, productId);
    
    setState(() {
      _isConnected = sucesso;
    });

    if (sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("USB Conectado! 🖨️")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao conectar USB.")));
    }
  }

  void _testeImpressao() async {
    Map<String, dynamic> pedidoTeste = {
      'userName': 'Teste Admin',
      'userPhone': '910000000',
      'morada': 'Balcão',
      'total': 12.50,
      'itens': [
        {
          'nome': 'Hambúrguer Teste',
          'quantidade': 1,
          'removidos': [],
          'molhos': ['Maionese'],
          'extras': [],
          'nota': 'Teste de Impressão USB'
        }
      ]
    };
    await _printerService.printOrderTicket(pedidoTeste, "TEST");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configurar Impressora USB 🔌")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(10)
              ),
              child: Row(
                children: [
                  Icon(_isConnected ? Icons.check_circle : Icons.usb_off, color: _isConnected ? Colors.green : Colors.deepOrange),
                  const SizedBox(width: 10),
                  Text(_isConnected ? "Impressora Ligada (USB)" : "Desconectada", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _buscarDispositivos,
              icon: const Icon(Icons.refresh),
              label: const Text("Procurar Dispositivos USB"),
            ),

            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text("Dispositivos Encontrados:", style: TextStyle(fontWeight: FontWeight.bold))),
            
            Expanded(
              child: _devices.isEmpty 
              ? const Center(child: Text("Liga a impressora com o cabo OTG ao telemóvel.")) 
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    var device = _devices[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.print),
                        title: Text(device['productName'] ?? "Impressora USB"),
                        subtitle: Text("ID: ${device['vendorId']}:${device['productId']}"),
                        trailing: ElevatedButton(
                          onPressed: () => _conectar(device),
                          child: const Text("Conectar"),
                        ),
                      ),
                    );
                  },
                ),
            ),

            if (_isConnected)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _testeImpressao,
                  icon: const Icon(Icons.print, color: Colors.white),
                  label: const Text("TESTE DE IMPRESSÃO", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.all(15)),
                ),
              )
          ],
        ),
      ),
    );
  }
}