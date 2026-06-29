import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'home_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Volta para a Home automaticamente após 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animação da Internet (sem baixar ficheiros)
            Lottie.network(
              'https://raw.githubusercontent.com/arashgh/Lottie-Examples/master/assets/checkmark.json', 
              height: 200,
              repeat: false,
              // Se a internet falhar, mostra um ícone normal para não dar erro vermelho
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.check_circle, color: Colors.green, size: 100);
              },
            ),
            const SizedBox(height: 20),
            const Text("Pedido Enviado!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("A cozinha já recebeu o teu pedido.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}