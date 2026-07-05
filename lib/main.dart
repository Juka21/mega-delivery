import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

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

  ErrorWidget.builder = (details) => AppErrorView(
        title: 'Nao foi possivel abrir esta pagina.',
        message: details.exceptionAsString(),
      );

  final startupError = await _initializeServices();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runZonedGuarded(
    () => runApp(MyApp(startupError: startupError)),
    (error, stack) {
      debugPrint('Uncaught zone error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

Future<Object?> _initializeServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      await NotificationService().inicializar();
    } catch (error) {
      debugPrint('Erro nas notificacoes: $error');
    }

    if (AppConfig.stripePublishableKey.isNotEmpty) {
      Stripe.publishableKey = AppConfig.stripePublishableKey;
      Stripe.merchantIdentifier = AppConfig.stripeMerchantIdentifier;
      Stripe.urlScheme = Uri.parse(AppConfig.stripeReturnUrl).scheme;
      await Stripe.instance.applySettings();
    } else {
      debugPrint(
        'Stripe publishable key not configured. Pass STRIPE_PUBLISHABLE_KEY with --dart-define.',
      );
    }

    try {
      await AuthService().inicializar();
    } catch (error) {
      debugPrint('Erro no AuthService: $error');
    }

    debugPrint('Tudo pronto. A iniciar a interface grafica...');
    return null;
  } catch (error) {
    debugPrint('Erro na inicializacao: $error');
    return error;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.startupError});

  final Object? startupError;

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
      home: startupError == null
          ? const SplashScreen()
          : AppErrorView(
              title: 'Nao foi possivel iniciar a app.',
              message: startupError.toString(),
              subtitle:
                  'A ligacao ao Firebase falhou. Fecha a app e tenta abrir novamente.',
            ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.title,
    required this.message,
    this.subtitle,
  });

  final String title;
  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F7FB),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF8A00),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF17212B),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: Color(0xFF626A73),
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SelectableText(
                message,
                style: const TextStyle(
                  color: Color(0xFF17212B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
