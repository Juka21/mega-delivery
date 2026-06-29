import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      initialData: AuthService().currentUser, 
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        
        // Vai buscar o utilizador (seja da memória inicial ou do stream)
        final utilizador = snapshot.data ?? AuthService().currentUser;

        // Se encontrou alguém guardado, entra direto na Loja
        if (utilizador != null) {
          debugPrint("✅ Utilizador detetado: ${utilizador.email}. A entrar...");
          return const HomeScreen();
        }

        // Se não há ninguém, vai para o Login! Sem demoras nem loops.
        debugPrint("👤 Nenhum utilizador ativo. A mostrar AuthScreen.");
        return const AuthScreen();
      },
    );
  }
}