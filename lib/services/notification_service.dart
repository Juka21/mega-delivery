import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  // Cria uma instância única (Singleton) para podermos usar em qualquer lado
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> inicializar() async {
    // 1. Pedir permissão ao utilizador (Aparece aquele popup "Deseja receber notificações?")
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Permissão para notificações concedida!');
      
      // 2. Ir buscar o "Número de Telefone" (Token) único deste aparelho
      String? token = await _fcm.getToken();
      debugPrint('📱 TOKEN DO TELEMÓVEL: $token');
      
      // O AuthService grava o token FCM no documento do utilizador no Firestore.

      // 3. Ficar à escuta de notificações enquanto a app está ABERTA
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 NOTIFICAÇÃO RECEBIDA (App Aberta): ${message.notification?.title}');
        // Aqui podes mostrar um SnackBar ou um alerta no ecrã
      });

    } else {
      debugPrint('❌ Permissão para notificações recusada.');
    }
  }
}
