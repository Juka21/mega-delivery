const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

admin.initializeApp();

const db = admin.firestore();
const CHANNEL_ID = "high_importance_channel";

exports.createStripePaymentSheet = onCall(
  {
    region: "us-central1",
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
        throw new HttpsError(
          "invalid-argument",
          "amount must be an integer >= 50 cents",
        );
      }

      if (parsedCurrency !== "eur") {
        throw new HttpsError("invalid-argument", "unsupported currency");
      }

      const stripe = require("stripe")(stripeSecretKey.value());
      const customer = await stripe.customers.create({
        metadata: { uid: request.auth.uid },
        address: { country: "PT" },
      });

      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: customer.id },
        { apiVersion: "2023-10-16" },
      );

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
      console.error("Stripe error:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error.message);
    }
  },
);

function toStringValue(value) {
  return value === undefined || value === null ? "" : String(value);
}

function uniqueTokens(tokens) {
  return [
    ...new Set(
      tokens.filter((token) => typeof token === "string" && token.trim()),
    ),
  ];
}

async function sendToTokens(tokens, title, body, data = {}) {
  const cleanTokens = uniqueTokens(tokens);
  if (cleanTokens.length === 0) {
    console.log("Sem tokens para notificacao:", title);
    return null;
  }

  const payloadData = {};
  for (const [key, value] of Object.entries(data)) {
    payloadData[key] = toStringValue(value);
  }

  const chunks = [];
  for (let i = 0; i < cleanTokens.length; i += 500) {
    chunks.push(cleanTokens.slice(i, i + 500));
  }

  const results = [];
  for (const chunk of chunks) {
    results.push(
      await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        android: {
          priority: "high",
          notification: {
            channelId: CHANNEL_ID,
            priority: "max",
            defaultSound: true,
            visibility: "public",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        data: {
          title,
          body,
          ...payloadData,
        },
      }),
    );
  }

  return results;
}

async function tokenFromDoc(collection, id) {
  if (!id) return null;
  const snapshot = await db.collection(collection).doc(id).get();
  return snapshot.data()?.fcmToken || null;
}

async function adminTokens() {
  const snapshot = await db.collection("users").where("role", "==", "admin").get();
  return snapshot.docs.map((doc) => doc.data().fcmToken);
}

async function allUserTokens() {
  const snapshot = await db.collection("users").get();
  return snapshot.docs.map((doc) => doc.data().fcmToken);
}

function orderStatusMessage(status) {
  const messages = {
    Aceite: ["Pedido aceite", "O restaurante aceitou o teu pedido."],
    "Em Preparação": ["Pedido em preparacao", "A cozinha ja esta a preparar o teu pedido."],
    "Pronto para Recolha": ["Pedido pronto", "O teu pedido esta pronto para recolha."],
    "A Caminho": ["Estafeta a caminho", "O teu pedido saiu para entrega."],
    Entregue: ["Pedido entregue", "Confirma na app quando receberes o pedido."],
    "Recebido pelo Cliente": ["Recebido confirmado", "Obrigado pela confirmacao."],
    "Concluído": ["Pedido concluido", "O teu pedido foi concluido."],
    Cancelado: ["Pedido cancelado", "O teu pedido foi cancelado."],
  };

  return messages[status] || ["Atualizacao do pedido", `O estado mudou para: ${status}`];
}

exports.notificarNovaNoticia = onDocumentCreated("noticias/{newsId}", async (event) => {
  const noticia = event.data?.data();
  if (!noticia) return null;

  const title = noticia.titulo || noticia.title || "Nova noticia";
  const body =
    noticia.texto ||
    noticia.conteudo ||
    noticia.descricao ||
    "Tens uma nova noticia no Mega Delivery.";

  return sendToTokens(await allUserTokens(), title, body, {
    type: "news",
    newsId: event.params.newsId,
  });
});

exports.notificarNovoPedidoAdmin = onDocumentCreated("pedidos/{pedidoId}", async (event) => {
  const pedido = event.data?.data();
  if (!pedido) return null;

  const cliente = pedido.cliente || pedido.nomeCliente || "Cliente";
  const total = Number(pedido.total || 0).toFixed(2);
  return sendToTokens(
    await adminTokens(),
    "Nova encomenda",
    `${cliente} fez um pedido de ${total} EUR.`,
    {
      type: "new_order",
      pedidoId: event.params.pedidoId,
    },
  );
});

exports.notificarEstadoPedido = onDocumentUpdated("pedidos/{pedidoId}", async (event) => {
  if (!event.data) return null;

  const after = event.data.after.data();
  const before = event.data.before.data();
  const newStatus = after.status || after.estado;
  const oldStatus = before.status || before.estado;
  if (!after || !before || newStatus === oldStatus) return null;

  const token = await tokenFromDoc("users", after.userId);
  const [title, body] = orderStatusMessage(newStatus);
  return sendToTokens([token], title, body, {
    type: "order_status",
    pedidoId: event.params.pedidoId,
    status: newStatus,
  });
});

exports.notificarChatEntrega = onDocumentCreated(
  "pedidos/{pedidoId}/delivery_messages/{messageId}",
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) return null;

    const pedidoId = event.params.pedidoId;
    const pedidoSnapshot = await db.collection("pedidos").doc(pedidoId).get();
    const pedido = pedidoSnapshot.data();
    if (!pedido) return null;

    const senderId = messageData.senderId;
    const senderRole = messageData.senderRole || "";
    const text = messageData.texto || "Nova mensagem";
    const tokens = [];
    let title = "Nova mensagem";

    if (senderRole === "estafeta" || senderId === pedido.driverId) {
      tokens.push(await tokenFromDoc("users", pedido.userId));
      title = "Mensagem do estafeta";
    } else if (senderRole === "admin") {
      tokens.push(await tokenFromDoc("users", pedido.userId));
      tokens.push(await tokenFromDoc("drivers", pedido.driverId));
      title = "Mensagem do admin";
    } else {
      tokens.push(await tokenFromDoc("drivers", pedido.driverId));
      title = `Mensagem de ${pedido.cliente || pedido.nomeCliente || "Cliente"}`;
    }

    return sendToTokens(tokens, title, text, {
      type: "delivery_chat",
      pedidoId,
    });
  },
);

exports.notificarTicketSuporte = onDocumentCreated(
  "support_tickets/{ticketId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) return null;

    const ticketId = event.params.ticketId;
    const ticketSnapshot = await db.collection("support_tickets").doc(ticketId).get();
    const ticket = ticketSnapshot.data();
    if (!ticket) return null;

    const senderRole = messageData.senderRole || "";
    const text = messageData.texto || "Nova mensagem";

    if (senderRole === "admin") {
      return sendToTokens(
        [await tokenFromDoc("users", ticket.userId)],
        "Resposta do suporte",
        text,
        {
          type: "support_chat",
          ticketId,
        },
      );
    }

    return sendToTokens(await adminTokens(), `Ticket: ${ticket.assunto || "Suporte"}`, text, {
      type: "support_chat",
      ticketId,
    });
  },
);
