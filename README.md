# Mega Delivery

Aplicacao Flutter para pedidos de restaurante com area de cliente, admin, estafeta, pagamentos Stripe, mapas e notificacoes.

## Configuracao da app

A app usa `--dart-define` para separar configuracao de desenvolvimento e producao:

```bash
flutter run \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx \
  --dart-define=GOOGLE_GEOCODING_API_KEY=AIza... \
  --dart-define=GOOGLE_SIGN_IN_SERVER_CLIENT_ID=158452862906-1t5eo38n9tmgr3nilcbbu5rsm0mki3fj.apps.googleusercontent.com \
  --dart-define=ADMIN_EMAILS=mega.cachorro2014@gmail.com
```

O backend da app usa Firebase Auth, Firestore, Storage, Cloud Functions e FCM no projeto `mega-delivery-44580`.

## Firebase Functions

A secret da Stripe nao deve ficar no codigo. Configura-a no Firebase:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase deploy --only functions
```

A callable function `createStripePaymentSheet` exige utilizador autenticado. App Check ficou preparado nas Functions, mas deve ser ativado depois de configurares Firebase App Check no Flutter.

## Colecoes Firestore usadas

- `users`: perfil do cliente/admin, role e fcmToken.
- `menu`: pratos, categorias, ingredientes, molhos, extras e imagens.
- `pedidos`: pedidos, estado, morada, estafeta e itens.
- `pedidos/{pedidoId}/messages`: chat por pedido.
- `moradas`: moradas guardadas por utilizador.
- `drivers`: estafetas, PIN, status e token de notificacao.
- `noticias`: novidades/notificacoes publicadas pelo admin.

Para tornar um utilizador admin, muda o documento `users/{uid}` no Firestore:

```json
{
  "role": "admin"
}
```

O email em `ADMIN_EMAILS` tambem e promovido automaticamente para `role: "admin"` ao iniciar sessao. Se mudares esse email, atualiza tambem a lista em `firestore.rules`.

## Importar Cardapio

O cardapio base esta em `lib/data/menu_seed.dart` e nao inclui bebidas. Para carregar os itens no Firestore, entra com uma conta admin, abre `Painel de Administracao > Gestao de Menu` e toca no icone de importar no topo. A importacao usa IDs fixos, por isso pode ser repetida sem duplicar itens e sem apagar fotos ja adicionadas.

## Deploy Firebase

Depois de confirmares o projeto `mega-delivery-44580`, podes publicar regras e functions:

```bash
firebase use mega-delivery-44580
firebase deploy --only firestore:rules,storage,functions
```

Se fores correr em iOS, Web, macOS ou Windows, gera tambem as opcoes FlutterFire:

```bash
flutterfire configure --project=mega-delivery-44580
```

## Qualidade

```bash
flutter pub get
flutter analyze
flutter test
```

## Notas de seguranca

- Restringe as chaves Google no Google Cloud por app/package/API.
- Usa HTTPS em producao e evita `usesCleartextTraffic`.
- Mantem `node_modules` e ficheiros `.env` fora do Git.
