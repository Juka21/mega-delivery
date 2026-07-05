import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'dart:async';
import 'dart:ui';
import 'config/app_config.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFFF6F7FB),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFFF8A00), size: 42),
                const SizedBox(height: 14),
                const Text(
                  'Nao foi possivel abrir esta pagina.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  style: const TextStyle(height: 1.35),
                ),
              ],
            ),
          ),
        ),
      );

  try {
    await Firebase.initializeApp();

    try {
      await NotificationService().inicializar();
    } catch (e) {
      debugPrint("Erro nas notificacoes: $e");
    }
    if (AppConfig.stripePublishableKey.isNotEmpty) {
      Stripe.publishableKey = AppConfig.stripePublishableKey;
      Stripe.merchantIdentifier = AppConfig.stripeMerchantIdentifier;
      Stripe.urlScheme = Uri.parse(AppConfig.stripeReturnUrl).scheme;
      await Stripe.instance.applySettings();
    } else {
      debugPrint(
          "Stripe publishable key not configured. Pass STRIPE_PUBLISHABLE_KEY with --dart-define.");
    }

    try {
      await AuthService().inicializar();
    } catch (e) {
      debugPrint("Erro no AuthService: $e");
    }
  } catch (e) {
    debugPrint("❌ Erro na Inicialização: $e");
  }

  debugPrint("🚀 Tudo pronto! A iniciar a interface gráfica...");
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runZonedGuarded(
    () => runApp(const MyApp()),
    (error, stack) {
      debugPrint('Uncaught zone error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mega Delivery',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'PT')],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        primaryColor: const Color(0xFFFF8A00),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8A00),
          primary: const Color(0xFFFF8A00),
          secondary: const Color(0xFFFFC857),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFFF6F7FB),
          foregroundColor: Color(0xFF17212B),
          titleTextStyle: TextStyle(
            color: Color(0xFF17212B),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE7EAF0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFFF8A00), width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFFFF8A00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
      // ✅ A APP ARRANCA SEMPRE NO SPLASH SCREEN!
      home: const SplashScreen(),
    );
  }
}
