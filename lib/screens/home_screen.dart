import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/menu_seed.dart';
import '../models/prato.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'cart_screen.dart';
import 'create_burger_screen.dart';
import 'driver_screen.dart';
import 'news_screen.dart';
import 'orders_screen.dart';
import 'prato_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _brand = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);
  static const Color _surface = Color(0xFFF6F7FB);

  final DatabaseService db = DatabaseService();

  int _selectedIndex = 0;
  String _searchQuery = "";
  String? _categoriaAberta;
  String? _activeDriverId;
  late Stream<List<Prato>> _menuStream;
  List<String> _readNewsIds = [];

  @override
  void initState() {
    super.initState();
    _loadReadNews();
    _menuStream = db.menuStream;
  }

  Future<void> _loadReadNews() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _readNewsIds = prefs.getStringList('readNews') ?? []);
  }

  Future<void> _markAllAsRead(List<dynamic> news) async {
    final newIds = news.map((n) => n['_id'].toString()).toList();
    final finalList = {..._readNewsIds, ...newIds}.toList();

    setState(() => _readNewsIds = finalList);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NewsScreen()),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('readNews', finalList);
  }

  void _ativarModoEstafeta(String driverId) {
    setState(() {
      _activeDriverId = driverId;
      _selectedIndex = 4;
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMenuPrincipal(),
          const OrdersScreen(),
          const CartScreen(),
          ProfileScreen(onDriverLogin: _ativarModoEstafeta),
          if (_activeDriverId != null)
            DriverScreen(driverId: _activeDriverId!)
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildMenuPrincipal() {
    return StreamBuilder<List<Prato>>(
      stream: _menuStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _brand));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Menu não disponível"));
        }

        final allPratos = snapshot.data!;
        final resultados = allPratos
            .where((p) =>
                p.nome.toLowerCase().contains(_searchQuery) ||
                p.categoria.toLowerCase().contains(_searchQuery))
            .toList();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(allPratos)),
            if (_searchQuery.isEmpty)
              SliverToBoxAdapter(child: _buildCreateBurgerBanner()),
            if (_searchQuery.isNotEmpty)
              _buildListaDiretaSliver(resultados)
            else
              _buildListaCategoriasSliver(allPratos),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(List<Prato> pratos) {
    final currentUser = AuthService().currentUser;
    final firstName = (currentUser?.nome.isNotEmpty ?? false)
        ? currentUser!.nome.split(' ').first
        : 'Cliente';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 22),
      decoration: const BoxDecoration(
        color: _brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Olá, $firstName",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Mega Delivery",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _buildNewsButton(),
            ],
          ),
          const SizedBox(height: 18),
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildNewsButton() {
    return StreamBuilder<dynamic>(
      stream: db.getNoticias,
      builder: (context, snapshot) {
        int unreadCount = 0;
        List<dynamic> allNews = [];

        if (snapshot.hasData) {
          allNews = snapshot.data;
          for (var n in allNews) {
            if (!_readNewsIds.contains(n['_id'])) unreadCount++;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _markAllAsRead(allNews),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.notifications_rounded, color: Colors.white),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _brand, width: 2),
                  ),
                  child: Text(
                    "$unreadCount",
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) =>
          setState(() => _searchQuery = value.trim().toLowerCase()),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: "Pesquisar hambúrguer, tosta, kebab...",
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: const Icon(Icons.search_rounded, color: _brand),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _searchQuery = ''),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }

  Widget _buildCreateBurgerBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 2),
      child: Material(
        color: _ink,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateBurgerScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF17212B), Color(0xFF2A3540)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.tune_rounded, color: _ink, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cria o teu burger",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Escolhe ingredientes, molhos e extras",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListaDiretaSliver(List<Prato> pratos) {
    if (pratos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: Text("Nada encontrado")),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      sliver: SliverList.separated(
        itemCount: pratos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildProductCard(pratos[i]),
      ),
    );
  }

  Widget _buildListaCategoriasSliver(List<Prato> all) {
    final cats = <String, List<Prato>>{};
    for (var p in all) {
      cats.putIfAbsent(p.categoria, () => []).add(p);
    }
    final orderedCategories = [
      ...menuSeedCategories.where((categoria) => cats.containsKey(categoria)),
      ...cats.keys
          .where((categoria) => !menuSeedCategories.contains(categoria)),
    ];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      sliver: SliverList.separated(
        itemCount: orderedCategories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final category = orderedCategories[index];
          return _buildCategorySection(category, cats[category]!);
        },
      ),
    );
  }

  Widget _buildCategorySection(String title, List<Prato> items) {
    final isOpen = _categoriaAberta == title;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isOpen ? _brand.withOpacity(0.18) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isOpen ? 0.07 : 0.04),
            blurRadius: isOpen ? 18 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () =>
                setState(() => _categoriaAberta = isOpen ? null : title),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  _buildCategoryIcon(title),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "${items.length} opções",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _ink),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: isOpen
                ? _buildCategoryItems(title, items)
                : const SizedBox.shrink(key: ValueKey('closed')),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItems(String category, List<Prato> items) {
    return Padding(
      key: ValueKey('open-$category'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          for (final p in items) _buildProductCard(p),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(String category) {
    final icon = switch (category) {
      'Mega Hambúrguer' || 'Hambúrgueres' => Icons.lunch_dining_rounded,
      'Mega Tostas' || 'Tostas' => Icons.breakfast_dining_rounded,
      'Kebab' => Icons.kebab_dining_rounded,
      'Francesinhas' => Icons.restaurant_rounded,
      'Bitoques' => Icons.dinner_dining_rounded,
      'Vegetariano' => Icons.eco_rounded,
      'Kids' => Icons.child_care_rounded,
      'Sobremesas' => Icons.icecream_rounded,
      'Extras' => Icons.add_circle_rounded,
      _ => Icons.fastfood_rounded,
    };

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _brand.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: _brand, size: 24),
    );
  }

  Widget _buildProductCard(Prato p) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: const Color(0xFFFBFCFE),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PratoDetailScreen(prato: p)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Hero(
                    tag: p.id,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        p.imageUrl,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        cacheWidth: 184,
                        cacheHeight: 184,
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Container(
                          width: 92,
                          height: 92,
                          color: const Color(0xFFEDEFF4),
                          child: const Icon(Icons.fastfood_rounded,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Text(
                              "${p.preco.toStringAsFixed(2)}€",
                              style: const TextStyle(
                                color: _brand,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _brand,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final items = [
      _NavItem(Icons.home_rounded, 'Menu'),
      _NavItem(Icons.receipt_long_rounded, 'Pedidos'),
      _NavItem(Icons.shopping_bag_rounded, 'Carrinho'),
      _NavItem(Icons.person_rounded, 'Perfil'),
      if (_activeDriverId != null)
        _NavItem(Icons.motorcycle_rounded, 'Estafeta'),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = _selectedIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => _onItemTapped(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        color: selected ? _brand : Colors.white54,
                        size: 22,
                      ),
                      if (selected) ...[
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}
