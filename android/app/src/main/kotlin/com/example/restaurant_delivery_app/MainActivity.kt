package com.mycompany.megadelivey

// 👇 MUDANÇA 1: Importar FlutterFragmentActivity
import io.flutter.embedding.android.FlutterFragmentActivity 

// 👇 MUDANÇA 2: Herdar de FlutterFragmentActivity em vez de FlutterActivity
class MainActivity: FlutterFragmentActivity() {
}