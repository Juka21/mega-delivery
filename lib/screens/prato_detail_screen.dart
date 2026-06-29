import 'package:flutter/material.dart';
import 'dart:ui'; // Para o efeito de vidro (Blur)
import '../models/prato.dart';
import '../services/database_service.dart';
import '../widgets/bouncy_button.dart';

class PratoDetailScreen extends StatefulWidget {
  final Prato prato;
  const PratoDetailScreen({super.key, required this.prato});

  @override
  State<PratoDetailScreen> createState() => _PratoDetailScreenState();
}

class _PratoDetailScreenState extends State<PratoDetailScreen> {
  final DatabaseService _db = DatabaseService();

  late List<String> _ingredientesRemovidos;
  late List<Map<String, dynamic>> _extrasSelecionados;
  late List<String> _molhosSelecionados;

  int _quantidade = 1;
  final _notaController = TextEditingController();

  // Cores Premium
  final Color _primaryColor =
      const Color(0xFFE63946); // Um vermelho mais vibrante (Gourmet)
  final Color _accentColor = const Color(0xFF1D3557); // Azul escuro premium
  final Color _bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _ingredientesRemovidos = [];
    _extrasSelecionados = [];
    _molhosSelecionados = [];
  }

  double _calcularTotal(Prato p) {
    double valorExtras = _extrasSelecionados.fold(
        0, (sum, item) => sum + (item['preco'] as num).toDouble());
    return (p.preco + valorExtras) * _quantidade;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final p = widget.prato;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(p, screenWidth),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(p),

                      // INGREDIENTES (Remoção)
                      if (p.ingredientes.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _buildRemocaoSection(p),
                      ],

                      // MOLHOS
                      if (p.molhos.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _buildMolhosSection(p),
                      ],

                      // EXTRAS
                      if (p.extras.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _buildExtrasSection(p),
                      ],

                      const SizedBox(height: 30),
                      _buildNotasSection(),

                      const SizedBox(
                          height: 120), // Espaço para a barra de baixo
                    ],
                  ),
                ),
              ),
            ],
          ),

          // BARRA DE ADICIONAR AO CARRINHO FIXA NO FUNDO
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(p),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES VISUAIS ---

  Widget _buildSliverAppBar(Prato p, double screenWidth) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Efeito de Vidro
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: p.id,
              child: Image.network(
                p.imageUrl,
                fit: BoxFit.cover,
                cacheWidth: (screenWidth * 2).toInt(),
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                        child: Icon(Icons.fastfood,
                            size: 50, color: Colors.grey))),
              ),
            ),
            // Sombra suave no fundo da imagem para o texto não desaparecer
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white
                    ],
                    stops: [
                      0.0,
                      0.7,
                      1.0
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Prato p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(
            (p.categoria).toUpperCase(),
            style: TextStyle(
                color: _primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(p.nome,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: Color(0xFF1E272E))),
            ),
            const SizedBox(width: 15),
            Text("${p.preco.toStringAsFixed(2)}€",
                style: TextStyle(
                    fontSize: 26,
                    color: _primaryColor,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildRemocaoSection(Prato p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("INGREDIENTES",
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF1E272E))),
        const SizedBox(height: 5),
        Text("Toca num ingrediente para o removeres",
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 15),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: p.ingredientes.map((ing) {
            bool isRemovido = _ingredientesRemovidos.contains(ing);
            return GestureDetector(
              onTap: () => setState(() => isRemovido
                  ? _ingredientesRemovidos.remove(ing)
                  : _ingredientesRemovidos.add(ing)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isRemovido
                      ? Colors.red.withOpacity(0.05)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isRemovido
                          ? Colors.red.withOpacity(0.3)
                          : Colors.green.withOpacity(0.3),
                      width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isRemovido ? Icons.remove_circle : Icons.check_circle,
                        size: 18,
                        color: isRemovido ? Colors.red : Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      ing,
                      style: TextStyle(
                          color: isRemovido ? Colors.red : Colors.green[800],
                          decoration:
                              isRemovido ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMolhosSection(Prato p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("MOLHOS",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1E272E))),
            Text("(Opcional)",
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: p.molhos.map((molho) {
            bool isSelected = _molhosSelecionados.contains(molho);
            return GestureDetector(
              onTap: () {
                setState(() {
                  isSelected
                      ? _molhosSelecionados.remove(molho)
                      : _molhosSelecionados.add(molho);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: isSelected ? _accentColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSelected ? _accentColor : Colors.grey[300]!),
                    boxShadow: [
                      if (!isSelected)
                        BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                    ]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isSelected ? Icons.check : Icons.add,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      molho,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExtrasSection(Prato p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("EXTRAS",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1E272E))),
            Text("(Opcional)",
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 15),
        Column(
          children: p.extras.map((extra) {
            String nomeExtra = extra['nome'] ?? 'Extra';
            double precoExtra = (extra['preco'] as num?)?.toDouble() ?? 0.0;
            bool isSelected =
                _extrasSelecionados.any((e) => e['nome'] == nomeExtra);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _extrasSelecionados
                        .removeWhere((e) => e['nome'] == nomeExtra);
                  } else {
                    _extrasSelecionados.add(extra);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.orange.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isSelected ? Colors.orange : Colors.grey[200]!,
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 5,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.grey[400]!,
                                width: 2),
                          ),
                          child: Icon(Icons.circle,
                              size: 14,
                              color: isSelected
                                  ? Colors.orange
                                  : Colors.transparent),
                        ),
                        const SizedBox(width: 15),
                        Text(nomeExtra,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: Colors.black87)),
                      ],
                    ),
                    Text("+ ${precoExtra.toStringAsFixed(2)}€",
                        style: TextStyle(
                            color: isSelected
                                ? Colors.orange[800]
                                : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("NOTAS PARA A COZINHA",
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF1E272E))),
        const SizedBox(height: 10),
        TextField(
          controller: _notaController,
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Ex: Carne bem passada, pouco sal...",
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _primaryColor.withOpacity(0.5))),
            contentPadding: const EdgeInsets.all(15),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(Prato p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          20, 15, 20, 25), // Mais espaço em baixo para o iPhone
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildQuantitySelector(),
            const SizedBox(width: 20),
            Expanded(
              child: BouncyButton(
                onPressed: () {
                  // ✅ NENHUM BLOQUEIO! O cliente pede como quiser.
                  _db.addToCart(
                    prato: p,
                    quantidade: _quantidade,
                    ingredientesRemovidos: _ingredientesRemovidos,
                    notaCliente: _notaController.text,
                    extras: _extrasSelecionados,
                    molhosSelecionados: _molhosSelecionados,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.shopping_bag_rounded,
                            color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text("${_quantidade}x ${p.nome} adicionado!",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                    backgroundColor: Colors.green[600],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(20),
                  ));
                },
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("ADICIONAR",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(width: 12),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                              "${_calcularTotal(p).toStringAsFixed(2)}€",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          _quantityBtn(Icons.remove,
              () => setState(() => _quantidade > 1 ? _quantidade-- : null)),
          SizedBox(
            width: 35,
            child: Text("$_quantidade",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ),
          _quantityBtn(Icons.add, () => setState(() => _quantidade++)),
        ],
      ),
    );
  }

  Widget _quantityBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}
