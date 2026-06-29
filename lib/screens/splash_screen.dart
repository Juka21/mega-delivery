import 'package:flutter/material.dart';
import 'dart:async';
// Necessário para rodar os ícones de fundo
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _floatingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _floatingAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Configuração da Entrada (Pop elástico)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );

    _entranceController.forward();

    // 2. Configuração do Flutuar
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<Offset>(begin: const Offset(0, 0.03), end: const Offset(0, -0.03)).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    // 3. Navegação
    Timer(const Duration(seconds: 5), () { // Aumentei para 5s para apreciarem o design
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // CAMADA 1: FUNDO COM GRADIENTE RADIAL (EFEITO SPOTLIGHT)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Color(0xFFE53935), // Vermelho mais claro no centro (Luz)
                  Color(0xFF8B0000), // Vermelho escuro nas bordas (Sombra)
                ],
              ),
            ),
          ),

          // CAMADA 2: PADRÃO DE ÍCONES DE FUNDO (TEXTURA)
          // Espalhamos ícones transparentes para dar um look "Food App"
          Positioned(top: 50, left: 30, child: _backgroundIcon(Icons.lunch_dining, -0.5)),
          Positioned(top: 100, right: -20, child: _backgroundIcon(Icons.local_pizza, 0.5)),
          Positioned(bottom: 150, left: -20, child: _backgroundIcon(Icons.fastfood, 0.3)),
          Positioned(bottom: 80, right: 40, child: _backgroundIcon(Icons.local_drink, -0.3)),
          Positioned(top: 300, left: -40, child: _backgroundIcon(Icons.restaurant, 0.2)),
          Positioned(top: 250, right: -30, child: _backgroundIcon(Icons.delivery_dining, -0.4)),

          // CAMADA 3: CONTEÚDO PRINCIPAL (LOGO E TEXTO)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: SlideTransition(
                    position: _floatingAnimation,
                    child: Container(
                      width: 200,
                      height: 200,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        // Borda dupla para estilo extra
                        border: Border.all(color: Colors.orangeAccent, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/mega_cachorro_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // TÍTULO COM DESIGN MODERNO
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      const Text(
                        "MEGA CACHORRO",
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 15, offset: Offset(0, 5))
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "O MELHOR SABOR DA CIDADE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // LOADING BAR
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Função auxiliar para criar os ícones de fundo
  Widget _backgroundIcon(IconData icon, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Icon(
        icon,
        size: 100,
        color: Colors.white.withOpacity(0.05), // Muito transparente (subtil)
      ),
    );
  }
}