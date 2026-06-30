import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

enum ChatMode { support, delivery }

class ChatScreen extends StatefulWidget {
  final String chatId;
  final ChatMode mode;
  final String title;
  final String subtitle;
  final String? senderIdOverride;
  final String? senderNameOverride;
  final String? senderRoleOverride;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.mode,
    required this.title,
    this.subtitle = '',
    this.senderIdOverride,
    this.senderNameOverride,
    this.senderRoleOverride,
  });

  const ChatScreen.delivery({
    super.key,
    required String pedidoId,
    String title = 'Chat da Entrega',
    String subtitle = '',
    String? senderId,
    String? senderName,
    String? senderRole,
  })  : chatId = pedidoId,
        mode = ChatMode.delivery,
        title = title,
        subtitle = subtitle,
        senderIdOverride = senderId,
        senderNameOverride = senderName,
        senderRoleOverride = senderRole;

  const ChatScreen.support({
    super.key,
    required String ticketId,
    String title = 'Suporte',
    String subtitle = '',
  })  : chatId = ticketId,
        mode = ChatMode.support,
        title = title,
        subtitle = subtitle,
        senderIdOverride = null,
        senderNameOverride = null,
        senderRoleOverride = null;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _brand = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _db = DatabaseService();

  AppUser? get currentUser => AuthService().currentUser;
  String get currentUserId =>
      widget.senderIdOverride ?? currentUser?.uid ?? 'anon';
  String get currentSenderName =>
      widget.senderNameOverride ?? currentUser?.nome ?? 'Utilizador';
  String get currentSenderRole =>
      widget.senderRoleOverride ?? currentUser?.role ?? 'cliente';

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _messageStream() {
    if (widget.mode == ChatMode.support) {
      return _db.getSupportChatStream(widget.chatId);
    }
    return _db.getDeliveryChatStream(widget.chatId);
  }

  Future<void> _sendMessage() async {
    final texto = _msgController.text.trim();
    if (texto.isEmpty) return;

    final message = {
      'texto': texto,
      'senderId': currentUserId,
      'senderName': currentSenderName,
      'senderRole': currentSenderRole,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _msgController.clear();
    if (widget.mode == ChatMode.support) {
      await _db.sendSupportChatMessage(widget.chatId, message);
    } else {
      await _db.sendDeliveryChatMessage(widget.chatId, message);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messageStream(),
              builder: (context, snapshot) {
                final mensagens = snapshot.data ?? [];
                if (mensagens.isEmpty) return _buildEmptyState();

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  itemCount: mensagens.length,
                  itemBuilder: (context, index) {
                    final data = mensagens[index];
                    return _buildChatBubble(data);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> data) {
    final isMe = data['senderId'] == currentUserId;
    final role = data['senderRole']?.toString() ?? '';
    final senderName = data['senderName']?.toString() ?? '';
    final texto = data['texto']?.toString() ?? '';
    final bubbleColor = isMe
        ? _brand
        : role == 'admin'
            ? const Color(0xFF17212B)
            : Colors.white;
    final textColor = isMe || role == 'admin' ? Colors.white : _ink;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 3),
                child: Text(
                  senderName,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(5),
                  bottomRight: isMe
                      ? const Radius.circular(5)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                texto,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _msgController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Escreve uma mensagem...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _sendMessage,
                child: const Icon(Icons.send_rounded, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_rounded, size: 58, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Inicia a conversa',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
