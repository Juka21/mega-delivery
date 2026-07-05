import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'complete_profile_screen.dart';
import 'home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      initialData: AuthService().currentUser,
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Erro no estado de autenticacao: ${snapshot.error}');
          return const AuthScreen();
        }

        final utilizador = snapshot.data ?? AuthService().currentUser;

        if (utilizador != null) {
          if (utilizador.needsProfileCompletion) {
            debugPrint(
              'Perfil incompleto para ${utilizador.email}. A completar...',
            );
            return CompleteProfileScreen(user: utilizador);
          }

          debugPrint('Utilizador detetado: ${utilizador.email}. A entrar...');
          return const HomeScreen();
        }

        debugPrint('Nenhum utilizador ativo. A mostrar AuthScreen.');
        return const AuthScreen();
      },
    );
  }
}
