import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  final bool isAdmin;

  const SupportTicketsScreen({super.key, this.isAdmin = false});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  static const Color _brand = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);

  final DatabaseService _db = DatabaseService();

  Future<void> _openNewTicketSheet() async {
    final assuntoController = TextEditingController();
    final mensagemController = TextEditingController();
    var isSending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Novo ticket',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: assuntoController,
                        enabled: !isSending,
                        decoration: _inputDecoration('Assunto'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: mensagemController,
                        enabled: !isSending,
                        minLines: 4,
                        maxLines: 6,
                        decoration: _inputDecoration('Escreve a tua pergunta'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isSending
                              ? null
                              : () async {
                                  final assunto = assuntoController.text.trim();
                                  final mensagem =
                                      mensagemController.text.trim();
                                  if (assunto.isEmpty || mensagem.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Preenche o assunto e a mensagem.'),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() => isSending = true);
                                  try {
                                    final ticketId =
                                        await _db.createSupportTicket(
                                      assunto: assunto,
                                      mensagem: mensagem,
                                    );
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    if (!mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen.support(
                                          ticketId: ticketId,
                                          title: assunto,
                                          subtitle: 'Suporte Mega Delivery',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setSheetState(() => isSending = false);
                                    }
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Não foi possível abrir o ticket: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          icon: isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            isSending
                                ? 'A enviar...'
                                : 'Enviar pedido de ajuda',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    assuntoController.dispose();
    mensagemController.dispose();
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 58, color: Colors.red[300]),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar o suporte',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error?.toString() ?? 'Erro desconhecido.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF4F6F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isAdmin = widget.isAdmin || user?.role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Tickets de Suporte' : 'Ajuda e Suporte',
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        actions: [
          if (!isAdmin)
            IconButton(
              onPressed: _openNewTicketSheet,
              icon: const Icon(Icons.add_circle_rounded, color: _brand),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNewTicketSheet,
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo ticket'),
            ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.getSupportTicketsStream(isAdmin: isAdmin),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _brand));
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final tickets = snapshot.data ?? [];
          if (tickets.isEmpty) {
            return _EmptyTickets(isAdmin: isAdmin);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _TicketCard(
                ticket: tickets[index],
                isAdmin: isAdmin,
                onTap: () {
                  final ticket = tickets[index];
                  final ticketId = ticket['id']?.toString() ?? '';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen.support(
                        ticketId: ticketId,
                        title: ticket['assunto']?.toString() ?? 'Suporte',
                        subtitle: isAdmin
                            ? ticket['userName']?.toString() ?? 'Cliente'
                            : 'Suporte Mega Delivery',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final bool isAdmin;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final assunto = ticket['assunto']?.toString() ?? 'Ticket';
    final status = ticket['status']?.toString() ?? 'Aberto';
    final lastMessage = ticket['lastMessage']?.toString() ?? '';
    final userName = ticket['userName']?.toString() ?? 'Cliente';
    final updated =
        DateTime.tryParse(ticket['updatedAtText']?.toString() ?? '');
    final date = updated == null
        ? ''
        : DateFormat('dd/MM HH:mm', 'pt_PT').format(updated.toLocal());
    final isOpen = status != 'Fechado';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isOpen ? const Color(0xFFFF8A00) : Colors.grey)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isOpen
                      ? Icons.support_agent_rounded
                      : Icons.check_circle_rounded,
                  color: isOpen ? const Color(0xFFFF8A00) : Colors.grey,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            assunto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF17212B),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 3),
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTickets extends StatelessWidget {
  final bool isAdmin;

  const _EmptyTickets({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_chat_unread_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isAdmin ? 'Sem tickets abertos' : 'Ainda não abriste tickets',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAdmin
                  ? 'Quando um cliente pedir ajuda, aparece aqui.'
                  : 'Cria um ticket para falar diretamente com o admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
