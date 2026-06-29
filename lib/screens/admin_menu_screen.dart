import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/menu_seed.dart';
import '../services/database_service.dart';
import '../models/prato.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  final Color _bgColor = const Color(0xFFF5F7FA);
  final Color _primaryColor = const Color(0xFFD32F2F);
  final Color _textColor = const Color(0xFF2D3436);
  final Color _cardColor = Colors.white;

  final DatabaseService db = DatabaseService();
  late Future<List<Prato>> _futurePratos;
  bool _isImportingMenu = false;

  @override
  void initState() {
    super.initState();
    _atualizarLista();
  }

  void _atualizarLista() {
    setState(() {
      _futurePratos = db.getPratos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text("Gestão de Menu",
            style: TextStyle(
                color: _textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Importar cardápio',
            icon: _isImportingMenu
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.download_rounded, color: _textColor),
            onPressed: _isImportingMenu ? null : _confirmarImportacaoCardapio,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(context, null, null),
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Novo Prato",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Prato>>(
        future: _futurePratos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
                child: CircularProgressIndicator(color: Colors.deepOrange));
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.restaurant_menu,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("Sem pratos no menu",
                      style: TextStyle(color: Colors.grey[500], fontSize: 16))
                ]));
          }
          final pratos = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: pratos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 15),
            itemBuilder: (context, index) =>
                _buildProfessionalCard(pratos[index].id, pratos[index].toMap()),
          );
        },
      ),
    );
  }

  Widget _buildProfessionalCard(String docId, Map<String, dynamic> dados) {
    return Container(
      decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarFormulario(context, docId, dados),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    dados['imageUrl'] ?? '',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Icon(Icons.fastfood, color: Colors.grey[400])),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((dados['categoria'] ?? 'Geral').toUpperCase(),
                          style: TextStyle(
                              color: _primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          maxLines: 1),
                      const SizedBox(height: 4),
                      Text(dados['nome'] ?? 'Sem Nome',
                          style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                          maxLines: 1),
                      const SizedBox(height: 4),
                      Text("${(dados['preco'] ?? 0).toStringAsFixed(2)}€",
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                        icon: Icon(Icons.edit_outlined,
                            color: Colors.blue[700], size: 20),
                        onPressed: () =>
                            _mostrarFormulario(context, docId, dados)),
                    IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red[700], size: 20),
                        onPressed: () =>
                            _confirmarExclusao(docId, dados['nome'])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarExclusao(String docId, String? nomePrato) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Prato?"),
        content: Text("Deseja remover '$nomePrato' do menu?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await db.deletePrato(docId);
              _atualizarLista();
            },
            child:
                const Text("Eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarImportacaoCardapio() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Importar cardápio?"),
        content: const Text(
          "Vou adicionar/atualizar os itens do cardápio, sem bebidas. As fotos existentes não serão apagadas.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await _importarCardapio();
            },
            child:
                const Text("Importar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _importarCardapio() async {
    setState(() => _isImportingMenu = true);

    try {
      final total = await db.importarCardapioPadrao();
      _atualizarLista();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$total itens importados para o menu."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erro ao importar cardápio: $e"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingMenu = false);
    }
  }

  void _mostrarFormulario(
      BuildContext context, String? docId, Map<String, dynamic>? dadosAtuais) {
    final nomeController =
        TextEditingController(text: dadosAtuais?['nome'] ?? '');
    final precoController =
        TextEditingController(text: dadosAtuais?['preco']?.toString() ?? '');
    String currentImageUrl = dadosAtuais?['imageUrl'] ?? '';

    List<String> ingredientesSelecionados =
        List<String>.from(dadosAtuais?['ingredientes'] ?? []);
    List<String> molhosSelecionados =
        List<String>.from(dadosAtuais?['molhos'] ?? []);
    List<Map<String, dynamic>> extrasSelecionados =
        (dadosAtuais?['extras'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    // ✅ A TUA LISTA REAL
    final List<String> categorias = menuSeedCategories;
    final List<String> todosIngredientes = defaultMenuIngredients;
    final List<String> todosMolhos = defaultMenuSauces;

    final List<Map<String, dynamic>> todosExtras = defaultMenuExtras;

    String? categoriaSelecionada = dadosAtuais?['categoria'];
    if (!categorias.contains(categoriaSelecionada))
      categoriaSelecionada = categorias.first;

    File? novaImagemFisica;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // 📸 Função para escolher a foto da galeria
            Future<void> escolherImagem() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                  source: ImageSource.gallery, imageQuality: 70);
              if (pickedFile != null) {
                setModalState(() {
                  novaImagemFisica = File(pickedFile.path);
                });
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              padding: EdgeInsets.fromLTRB(
                  25, 20, 25, MediaQuery.of(context).viewInsets.bottom + 20),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  Text(docId == null ? "Novo Prato" : "Editar Prato",
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // 📸 ÁREA DA FOTO
                  GestureDetector(
                    onTap: escolherImagem,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                            width: 2),
                      ),
                      child: novaImagemFisica != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(novaImagemFisica!,
                                  fit: BoxFit.cover))
                          : (currentImageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.network(currentImageUrl,
                                      fit: BoxFit.cover))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      Icon(Icons.add_a_photo_rounded,
                                          size: 50, color: Colors.grey[400]),
                                      const SizedBox(height: 10),
                                      Text("Tocar para abrir a galeria",
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold))
                                    ])),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _customTextField(
                      nomeController, "Nome do Prato", Icons.restaurant),
                  const SizedBox(height: 15),
                  _customTextField(precoController, "Preço (€)", Icons.euro,
                      isNumber: true),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: categoriaSelecionada,
                    items: categorias
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => categoriaSelecionada = val),
                    decoration: InputDecoration(
                        labelText: "Categoria",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),

                  const SizedBox(height: 25),
                  _sectionTitle(
                      "1. INGREDIENTES (O que o cliente pode remover)"),
                  Wrap(
                    spacing: 8,
                    children: todosIngredientes.map((ing) {
                      bool isSelected = ingredientesSelecionados.contains(ing);
                      return FilterChip(
                        label: Text(ing),
                        selected: isSelected,
                        selectedColor: Colors.green[200],
                        onSelected: (val) => setModalState(() => val
                            ? ingredientesSelecionados.add(ing)
                            : ingredientesSelecionados.remove(ing)),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 25),
                  _sectionTitle("2. MOLHOS PERMITIDOS"),
                  Wrap(
                    spacing: 8,
                    children: todosMolhos.map((molho) {
                      bool isSelected = molhosSelecionados.contains(molho);
                      return FilterChip(
                        label: Text(molho),
                        selected: isSelected,
                        selectedColor: Colors.blue[200],
                        onSelected: (val) => setModalState(() => val
                            ? molhosSelecionados.add(molho)
                            : molhosSelecionados.remove(molho)),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 25),
                  _sectionTitle("3. EXTRAS (A pagar mais)"),
                  Wrap(
                    spacing: 8,
                    children: todosExtras.map((extra) {
                      String nomeEx = extra['nome'];
                      bool isSelected =
                          extrasSelecionados.any((e) => e['nome'] == nomeEx);
                      return FilterChip(
                        label: Text(
                            "$nomeEx (+${extra['preco'].toStringAsFixed(2)}€)"),
                        selected: isSelected,
                        selectedColor: Colors.orange[200],
                        onSelected: (val) => setModalState(() => val
                            ? extrasSelecionados.add(extra)
                            : extrasSelecionados
                                .removeWhere((e) => e['nome'] == nomeEx)),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 35),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: isUploading
                        ? null
                        : () async {
                            setModalState(() => isUploading = true);

                            // 1. Fazer upload da imagem (se escolheu uma nova da galeria)
                            String finalImageUrl = currentImageUrl;
                            if (novaImagemFisica != null) {
                              String? uploadedUrl =
                                  await db.uploadImage(novaImagemFisica!);
                              if (uploadedUrl != null)
                                finalImageUrl = uploadedUrl;
                            }

                            // 2. Prepara os dados limpos
                            final novosDados = {
                              'nome': nomeController.text,
                              'descricao': '',
                              'preco': double.tryParse(precoController.text
                                      .replaceAll(',', '.')) ??
                                  0.0,
                              'categoria': categoriaSelecionada,
                              'imageUrl': finalImageUrl,
                              'ingredientes': ingredientesSelecionados,
                              'molhos': molhosSelecionados,
                              'extras': extrasSelecionados,
                            };

                            // 3. Grava ou Atualiza
                            if (docId == null) {
                              await db.addPrato(novosDados);
                            } else {
                              await db.updatePrato(docId, novosDados);
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              _atualizarLista();
                            }
                          },
                    child: isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text("SALVAR PRATO",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87)));

  Widget _customTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isNumber = false}) {
    return TextField(
      controller: controller,
      maxLines: 1,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          filled: true,
          fillColor: Colors.white),
    );
  }
}
