import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'map_screen.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final DatabaseService _db = DatabaseService();
  final currentUser = AuthService().currentUser;

  Future<void> _openMapAndFill(TextEditingController ruaCtrl, TextEditingController cidadeCtrl, TextEditingController cpCtrl) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );

    if (result == null || result is! String) return;

    final fullAddress = result;
    if (!fullAddress.contains(',')) {
      ruaCtrl.text = fullAddress;
      return;
    }

    final partes = fullAddress.split(',');
    ruaCtrl.text = partes.first.trim();
    final resto = partes.sublist(1).join(',').trim();
    final cpMatch = RegExp(r'\d{4}-\d{3}|\d{4}').firstMatch(resto);
    final cp = cpMatch?.group(0) ?? '';
    cpCtrl.text = cp;
    cidadeCtrl.text = cp.isEmpty ? resto : resto.replaceAll(cp, '').replaceAll(RegExp(r'^[\s\-,]+'), '').trim();
  }

  Future<void> _saveAddress(String nome, String rua, String andar, String cp, String cidade) async {
    if (currentUser == null) return;
    await _db.saveUserAddress(
      userId: currentUser!.uid,
      nome: nome,
      rua: rua,
      andar: andar,
      cp: cp,
      cidade: cidade,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Inicia sessão para gerir moradas.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Minhas Moradas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressSheet(context),
        backgroundColor: const Color(0xFFD32F2F),
        icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
        label: const Text('NOVA MORADA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: _db.getUserAddresses(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }

          final moradas = snapshot.data ?? [];
          if (moradas.isEmpty) {
            return Center(child: Text('Sem moradas guardadas', style: TextStyle(color: Colors.grey[600])));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: moradas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildAddressCard(Map<String, dynamic>.from(moradas[index] as Map)),
          );
        },
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.deepOrange),
        title: Text(data['nome'] ?? 'Morada', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${data['rua'] ?? ''}\n${data['cp'] ?? ''} ${data['cidade'] ?? ''}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _db.deleteAddress(data['id'].toString()),
        ),
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController();
    final ruaCtrl = TextEditingController();
    final andarCtrl = TextEditingController();
    final cpCtrl = TextEditingController();
    final cidadeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(25),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nova Morada', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _openMapAndFill(ruaCtrl, cidadeCtrl, cpCtrl),
                    icon: const Icon(Icons.map),
                    label: const Text('Selecionar no mapa'),
                  ),
                  const SizedBox(height: 15),
                  _field(nomeCtrl, 'Nome do Local', Icons.label),
                  const SizedBox(height: 12),
                  _field(ruaCtrl, 'Rua e Número', Icons.home),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(andarCtrl, 'Andar/Porta', Icons.apartment, required: false)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          cpCtrl,
                          'Cód. Postal',
                          Icons.markunread_mailbox,
                          required: false,
                          keyboardType: TextInputType.number,
                          formatters: [LengthLimitingTextInputFormatter(8), _CpInputFormatter()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(cidadeCtrl, 'Cidade', Icons.location_city, required: false),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: const Color(0xFFD32F2F),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await _saveAddress(nomeCtrl.text, ruaCtrl.text, andarCtrl.text, cpCtrl.text, cidadeCtrl.text);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('GUARDAR MORADA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: (value) => required && (value == null || value.isEmpty) ? 'Obrigatório' : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
    );
  }
}

class _CpInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 7) text = text.substring(0, 7);
    final formatted = text.length > 4 ? '${text.substring(0, 4)}-${text.substring(4)}' : text;
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
