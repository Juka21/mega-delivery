const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https"); // Adicionado para Stripe
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

admin.initializeApp();

// --- FUNÇÃO STRIPE ---
exports.createStripePaymentSheet = onCall(
  {
    region: "us-central1",
    // Set to true after Firebase App Check is configured in the Flutter app.
    enforceAppCheck: false,
    secrets: [stripeSecretKey],
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const { amount, currency } = request.data;
      const parsedAmount = Number(amount);
      const parsedCurrency = (currency || "eur").toString().toLowerCase();

      if (!Number.isInteger(parsedAmount) || parsedAmount < 50) {
        throw new HttpsError("invalid-argument", "amount must be an integer >= 50 cents");
      }

      if (parsedCurrency !== "eur") {
        throw new HttpsError("invalid-argument", "unsupported currency");
      }

      const stripe = require("stripe")(stripeSecretKey.value());

      // 1️⃣ Customer
      const customer = await stripe.customers.create({
        metadata: { uid: request.auth.uid },
        address: { country: 'PT' }, // Ajuda o automático a saber a região
      });

      // 2️⃣ Ephemeral Key
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: customer.id },
        { apiVersion: "2023-10-16" }
      );

      // 3 Payment Intent
      const paymentIntent = await stripe.paymentIntents.create({
        amount: parsedAmount,
        currency: parsedCurrency,
        customer: customer.id,
        receipt_email: request.auth.token.email,
        metadata: { uid: request.auth.uid },
        payment_method_types: ["card", "multibanco"],
      });

      return {
        clientSecret: paymentIntent.client_secret,
        customer: customer.id,
        ephemeralKey: ephemeralKey.secret,
      };

    } catch (error) {
      console.error("🔥 Stripe error:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", error.message);
    }
  }
);


// --- 1. FUNÇÃO PARA O CLIENTE (MANTIDA) ---
exports.enviarNotificacaoPedido = onDocumentUpdated("pedidos/{pedidoId}", async (event) => {
    if (!event.data) return null;

    const novoPedido = event.data.after.data();
    const antigoPedido = event.data.before.data();

    if (!novoPedido || !antigoPedido || novoPedido.estado === antigoPedido.estado) {
        return null;
    }

    const userId = novoPedido.userId;
    const novoEstado = novoPedido.estado;

    const userSnapshot = await admin.firestore().collection("users").doc(userId).get();
    const userData = userSnapshot.data();

    if (!userData || !userData.fcmToken) {
        console.log("Utilizador não tem token.");
        return null;
    }

    let titulo = "Atualização do Pedido 🔔";
    let corpo = `O estado do teu pedido mudou para: ${novoEstado}`;

    if (novoEstado === "Em Preparação") {
        titulo = "👨‍🍳 A Cozinha aceitou!";
        corpo = "O teu pedido começou a ser preparado.";
    } else if (novoEstado === "Pronto para Recolha") {
        titulo = "🛍️ Pronto!";
        corpo = "O teu pedido está pronto para ser levantado.";
    }

    const message = {
        token: userData.fcmToken,
        notification: { title: titulo, body: corpo },
        android: {
            notification: {
                channelId: "high_importance_channel",
                priority: "max",
                defaultSound: true,
                visibility: "public",
            }
        },
        data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            pedidoId: event.params.pedidoId,
        },
    };

    return admin.messaging().send(message);
});

// --- 2. FUNÇÃO PARA O ADMIN (MANTIDA) ---
exports.enviarNotificacaoChat = onDocumentCreated("pedidos/{pedidoId}/messages/{messageId}", async (event) => {
    const messageData = event.data.data();
    const pedidoId = event.params.pedidoId;

    if (!messageData) return null;

    // 1. Buscar dados do Pedido
    const pedidoSnapshot = await admin.firestore().collection("pedidos").doc(pedidoId).get();
    const pedidoData = pedidoSnapshot.data();

    if (!pedidoData) return null;

    const senderId = messageData.senderId;
    let receiverId;
    let titulo;
    let targetCollection = "users"; // Por defeito procura em users

    // 2. Lógica INTELIGENTE de Coleções
    // Se quem escreveu foi o CLIENTE (userId) -> O destino é o DRIVER (drivers)
    if (senderId === pedidoData.userId) {
        receiverId = pedidoData.driverId;
        titulo = `💬 Mensagem de ${pedidoData.userName || 'Cliente'}`;
        targetCollection = "drivers"; // <--- MUDANÇA CRÍTICA AQUI
    } 
    // Se quem escreveu foi o DRIVER -> O destino é o CLIENTE (users)
    else if (senderId === pedidoData.driverId) {
        receiverId = pedidoData.userId;
        titulo = `💬 Mensagem do Estafeta`;
        targetCollection = "users";
    } else {
        return null; 
    }

    if (!receiverId) return null;

    // 3. Buscar Token na Colecao CERTA
    const userSnapshot = await admin.firestore().collection(targetCollection).doc(receiverId).get();
    const userData = userSnapshot.data();

    if (!userData || !userData.fcmToken) {
        console.log(`Falta token para ${receiverId} na coleção ${targetCollection}`);
        return null;
    }

    // 4. Enviar Notificação
    const message = {
        token: userData.fcmToken,
        notification: {
            title: titulo,
            body: messageData.texto,
        },
        android: {
            priority: "high",
            notification: {
                channelId: "high_importance_channel",
                priority: "max",
                defaultSound: true,
                visibility: "public",
                icon: "ic_launcher"
            }
        },
        data: {
            title: titulo,
            body: messageData.texto,
            pedidoId: pedidoId,
            type: "chat"
        }
    };

    return admin.messaging().send(message);
});
