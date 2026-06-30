import 'dart:ui';
import 'package:flutter/material.dart';
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
  static const Color _brand = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);
  static const Color _surface = Color(0xFFF6F7FB);
  static const Color _muted = Color(0xFF6B7280);

  final DatabaseService _db = DatabaseService();
  final _notaController = TextEditingController();

  late final List<String> _ingredientesRemovidos;
  late final List<Map<String, dynamic>> _extrasSelecionados;
  late final List<String> _molhosSelecionados;

  int _quantidade = 1;

  @override
  void initState() {
    super.initState();
    _ingredientesRemovidos = [];
    _extrasSelecionados = [];
    _molhosSelecionados = [];
  }

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  double _calcularTotal(Prato prato) {
    final extras = _extrasSelecionados.fold<double>(
      0,
      (sum, item) => sum + ((item['preco'] as num?)?.toDouble() ?? 0),
    );
    return (prato.preco + extras) * _quantidade;
  }

  bool _hasChoices(Prato prato) {
    return prato.ingredientes.isNotEmpty ||
        prato.molhos.isNotEmpty ||
        prato.extras.isNotEmpty;
  }

  Future<void> _adicionarAoCarrinho(Prato prato) async {
    await _db.addToCart(
      prato: prato,
      quantidade: _quantidade,
      ingredientesRemovidos: _ingredientesRemovidos,
      notaCliente: _notaController.text.trim(),
      extras: _extrasSelecionados,
      molhosSelecionados: _molhosSelecionados,
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_quantidade x ${prato.nome} adicionado',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prato = widget.prato;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHero(prato, screenWidth),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitlePanel(prato),
                      const SizedBox(height: 16),
                      if (_hasChoices(prato)) ...[
                        _SectionShell(
                          title: 'Personaliza',
                          icon: Icons.tune_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (prato.ingredientes.isNotEmpty)
                                _buildIngredientes(prato),
                              if (prato.molhos.isNotEmpty) ...[
                                if (prato.ingredientes.isNotEmpty)
                                  const SizedBox(height: 22),
                                _buildMolhos(prato),
                              ],
                              if (prato.extras.isNotEmpty) ...[
                                if (prato.ingredientes.isNotEmpty ||
                                    prato.molhos.isNotEmpty)
                                  const SizedBox(height: 22),
                                _buildExtras(prato),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _SectionShell(
                        title: 'Nota para a cozinha',
                        icon: Icons.edit_note_rounded,
                        child: _buildNotas(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(prato),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(Prato prato, double screenWidth) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      stretch: true,
      backgroundColor: _surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 66,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
        child: _GlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: prato.id,
              child: Image.network(
                prato.imageUrl,
                fit: BoxFit.cover,
                cacheWidth: (screenWidth * 2).toInt(),
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEDEFF4),
                  child: const Icon(
                    Icons.fastfood_rounded,
                    size: 58,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0xFFF6F7FB),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitlePanel(Prato prato) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    prato.categoria.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${prato.preco.toStringAsFixed(2)} EUR',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            prato.nome,
            style: const TextStyle(
              color: _ink,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Escolhe exatamente como queres receber o teu pedido.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientes(Prato prato) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubHeader(
          title: 'Ingredientes',
          subtitle: 'Toca para remover',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final ingrediente in prato.ingredientes)
              _ChoiceChipButton(
                label: ingrediente,
                selected: !_ingredientesRemovidos.contains(ingrediente),
                selectedColor: Colors.green,
                unselectedColor: Colors.red,
                selectedIcon: Icons.check_rounded,
                unselectedIcon: Icons.remove_rounded,
                unselectedTextDecoration: TextDecoration.lineThrough,
                onTap: () {
                  setState(() {
                    if (_ingredientesRemovidos.contains(ingrediente)) {
                      _ingredientesRemovidos.remove(ingrediente);
                    } else {
                      _ingredientesRemovidos.add(ingrediente);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMolhos(Prato prato) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubHeader(title: 'Molhos', subtitle: 'Opcional'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final molho in prato.molhos)
              _ChoiceChipButton(
                label: molho,
                selected: _molhosSelecionados.contains(molho),
                selectedColor: _ink,
                unselectedColor: Colors.grey,
                selectedIcon: Icons.check_rounded,
                unselectedIcon: Icons.add_rounded,
                onTap: () {
                  setState(() {
                    if (_molhosSelecionados.contains(molho)) {
                      _molhosSelecionados.remove(molho);
                    } else {
                      _molhosSelecionados.add(molho);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildExtras(Prato prato) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubHeader(title: 'Extras', subtitle: 'Opcional'),
        const SizedBox(height: 12),
        Column(
          children: [
            for (final extra in prato.extras)
              _buildExtraTile(Map<String, dynamic>.from(extra)),
          ],
        ),
      ],
    );
  }

  Widget _buildExtraTile(Map<String, dynamic> extra) {
    final nome = extra['nome']?.toString() ?? 'Extra';
    final preco = (extra['preco'] as num?)?.toDouble() ?? 0;
    final selected = _extrasSelecionados.any((item) => item['nome'] == nome);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color:
            selected ? _brand.withValues(alpha: 0.10) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              if (selected) {
                _extrasSelecionados.removeWhere((item) => item['nome'] == nome);
              } else {
                _extrasSelecionados.add(extra);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _brand : const Color(0xFFE7EAF0),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? _brand : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _brand : const Color(0xFFD1D5DB),
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nome,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '+ ${preco.toStringAsFixed(2)} EUR',
                  style: TextStyle(
                    color: selected ? _brand : _muted,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotas() {
    return TextField(
      controller: _notaController,
      maxLines: 3,
      minLines: 3,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: 'Ex: carne bem passada, pouco sal...',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 44),
          child: Icon(Icons.sticky_note_2_outlined),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE7EAF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE7EAF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _brand, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildSubHeader({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(Prato prato) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            border: const Border(top: BorderSide(color: Color(0xFFE7EAF0))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _buildQuantitySelector(),
                const SizedBox(width: 12),
                Expanded(
                  child: BouncyButton(
                    onPressed: () => _adicionarAoCarrinho(prato),
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: _brand,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _brand.withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Adicionar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_calcularTotal(prato).toStringAsFixed(2)} EUR',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E4EA)),
      ),
      child: Row(
        children: [
          _quantityButton(Icons.remove_rounded, () {
            if (_quantidade <= 1) return;
            setState(() => _quantidade--);
          }),
          SizedBox(
            width: 34,
            child: Text(
              '$_quantidade',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _quantityButton(Icons.add_rounded, () {
            setState(() => _quantidade++);
          }),
        ],
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 50,
          child: Icon(icon, color: _ink, size: 22),
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EAF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _PratoDetailScreenState._brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: _PratoDetailScreenState._brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: _PratoDetailScreenState._ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final TextDecoration? unselectedTextDecoration;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.selectedIcon,
    required this.unselectedIcon,
    this.unselectedTextDecoration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;

    return Material(
      color: color.withValues(alpha: selected ? 0.11 : 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : unselectedIcon,
                color: color,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  decoration: selected ? null : unselectedTextDecoration,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.72),
          child: InkWell(
            onTap: onTap,
            child: Icon(icon, color: _PratoDetailScreenState._ink, size: 19),
          ),
        ),
      ),
    );
  }
}
