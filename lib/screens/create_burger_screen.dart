import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/prato.dart';

class CreateBurgerScreen extends StatefulWidget {
  const CreateBurgerScreen({super.key});

  @override
  State<CreateBurgerScreen> createState() => _CreateBurgerScreenState();
}

class _CreateBurgerScreenState extends State<CreateBurgerScreen> {
  final DatabaseService db = DatabaseService();

  // 🍔 1. CONFIGURAÇÃO DE PREÇOS BASE
  String _tamanhoSelecionado = 'Normal';
  final Map<String, double> _precosBase = {
    'Normal': 5.50, 
    'Mega': 8.50,   
  };

  // 🥬 2. LISTA DE INGREDIENTES
  final List<Map<String, dynamic>> _ingredientesDisponiveis = [
    {'nome': 'Queijo', 'preco': 0.50},
    {'nome': 'Fiambre', 'preco': 0.50},
    {'nome': 'Bacon', 'preco': 0.80},
    {'nome': 'Ovo', 'preco': 0.60},
    {'nome': 'Batata Palha', 'preco': 0.0},
    {'nome': 'Alface', 'preco': 0.0},
    {'nome': 'Tomate', 'preco': 0.0},
    {'nome': 'Cebola Tostada', 'preco': 0.30},
    {'nome': 'Cebola Refugada', 'preco': 0.30},
  ];

  // 🥫 3. LISTA DE MOLHOS
  final List<Map<String, dynamic>> _molhosDisponiveis = [
    {'nome': 'Ketchup', 'preco': 0.0},
    {'nome': 'Maionese', 'preco': 0.0},
    {'nome': 'Mostarda', 'preco': 0.0},
    {'nome': 'Molho Pita (Alho)', 'preco': 0.0},
    {'nome': 'Samurai (Picante)', 'preco': 0.0},
  ];

  final Set<int> _ingredientesSelecionadosIndices = {};
  final Set<int> _molhosSelecionadosIndices = {};

  double get _precoTotal {
    double total = _precosBase[_tamanhoSelecionado]!;
    
    for (int index in _ingredientesSelecionadosIndices) {
      total += _ingredientesDisponiveis[index]['preco'] as double;
    }
    
    for (int index in _molhosSelecionadosIndices) {
      total += _molhosDisponiveis[index]['preco'] as double;
    }
    
    return total;
  }

  void _adicionarAoCarrinho() async {
    List<Map<String, dynamic>> extrasFinais = [];
    List<String> descricaoIngredientes = [];

    // Adiciona Ingredientes
    for (int index in _ingredientesSelecionadosIndices) {
      extrasFinais.add(_ingredientesDisponiveis[index]);
      descricaoIngredientes.add(_ingredientesDisponiveis[index]['nome']);
    }

    // Adiciona Molhos
    for (int index in _molhosSelecionadosIndices) {
      extrasFinais.add(_molhosDisponiveis[index]);
      descricaoIngredientes.add(_molhosDisponiveis[index]['nome']);
    }

    Prato pratoPersonalizado = Prato(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      nome: "Hambúrguer $_tamanhoSelecionado (Personalizado)",
      descricao: descricaoIngredientes.isNotEmpty 
          ? "Com: ${descricaoIngredientes.join(', ')}" 
          : "Sem extras",
      preco: _precosBase[_tamanhoSelecionado]!,
      categoria: "Hambúrgueres",
      imageUrl: "https://img.freepik.com/fotos-gratis/hamburguer-de-carne-com-salada-de-queijo-e-tomate-em-piso-escuro_140725-89524.jpg",
      ingredientes: descricaoIngredientes,
    );

    await db.addToCart(
      prato: pratoPersonalizado,
      quantidade: 1,
      ingredientesRemovidos: [], // 👈 Adiciona isto vazio
      extras: extrasFinais,
      molhosSelecionados: [],    // 👈 ✅ O ERRO ESTAVA AQUI (Faltava isto)
      notaCliente: "Personalizado ao gosto do cliente",
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hambúrguer adicionado ao carrinho! 🍔")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // CABEÇALHO
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Cria o teu Hambúrguer", 
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)]
                )
              ),
              background: Image.network(
                "https://img.freepik.com/fotos-gratis/vista-frontal-do-hamburguer-de-carne-com-queijo-e-salada-na-frente-do-fundo-escuro_140725-89524.jpg",
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(color: Colors.grey[900], child: const Center(child: CircularProgressIndicator(color: Colors.white)));
                },
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900], child: const Icon(Icons.fastfood, color: Colors.white54, size: 50)),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("1. Escolhe o Tamanho", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _buildSizeOption("Normal", _precosBase['Normal']!),
                      const SizedBox(width: 15),
                      _buildSizeOption("Mega", _precosBase['Mega']!),
                    ],
                  ),

                  const SizedBox(height: 30),
                  
                  const Text("2. Adiciona Ingredientes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text("O pão e a carne já estão incluídos.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),

          // LISTA DE INGREDIENTES
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ingrediente = _ingredientesDisponiveis[index];
                bool isSelected = _ingredientesSelecionadosIndices.contains(index);
                return _buildCheckboxItem(ingrediente, isSelected, (val) {
                  setState(() {
                    if (val == true) {
                      _ingredientesSelecionadosIndices.add(index);
                    } else {
                      _ingredientesSelecionadosIndices.remove(index);
                    }
                  });
                });
              },
              childCount: _ingredientesDisponiveis.length,
            ),
          ),

          // TÍTULO DA SECÇÃO DE MOLHOS
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("3. Escolhe os Molhos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text("Dá sabor ao teu hambúrguer!", style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // LISTA DE MOLHOS
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final molho = _molhosDisponiveis[index];
                bool isSelected = _molhosSelecionadosIndices.contains(index);
                return _buildCheckboxItem(molho, isSelected, (val) {
                  setState(() {
                    if (val == true) {
                      _molhosSelecionadosIndices.add(index);
                    } else {
                      _molhosSelecionadosIndices.remove(index);
                    }
                  });
                });
              },
              childCount: _molhosDisponiveis.length,
            ),
          ),

          // Espaço extra para o conteúdo não ficar escondido atrás da barra inferior
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
      
      // BARRA INFERIOR
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total", style: TextStyle(color: Colors.grey)),
                  Text("${_precoTotal.toStringAsFixed(2)}€", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _adicionarAoCarrinho,
                child: const Text("ADICIONAR 🛒", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET HELPER PARA OS ITENS
  Widget _buildCheckboxItem(Map<String, dynamic> item, bool isSelected, Function(bool?) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? Colors.deepOrange : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]
      ),
      child: CheckboxListTile(
        activeColor: Colors.deepOrange,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Mais espaço
        title: Text(
          item['nome'], 
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1, 
          overflow: TextOverflow.ellipsis // ✅ Blindagem contra textos longos
        ),
        subtitle: Text(item['preco'] == 0 
            ? "Grátis" 
            : "+ ${item['preco'].toStringAsFixed(2)}€", 
            style: TextStyle(color: item['preco'] == 0 ? Colors.green : Colors.grey[600], fontWeight: FontWeight.bold)),
        value: isSelected,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSizeOption(String label, double price) {
    bool isSelected = _tamanhoSelecionado == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tamanhoSelecionado = label),
        child: AnimatedContainer( // ✅ Animação suave na seleção
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300),
            boxShadow: [if (!isSelected) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 5),
              Text("${price.toStringAsFixed(2)}€", style: TextStyle(color: isSelected ? Colors.grey[400] : Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}