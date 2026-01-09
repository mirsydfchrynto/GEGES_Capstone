// lib/screens/customer/tabs/chat_assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Clipboard
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/services/chatbot_service.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';

// --- THEME COLORS ---
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kSurface = Color(0xFF121212);
const Color kCardColor = Color(0xFF2C2C2C);
const Color kUserBubble = Color(0xFFE9B01A);
const Color kTextDark = Color(0xFF1B1B1B);
const Color kTextGrey = Colors.white70;
const Color kDarkGrey = Color(0xFF1E1E1E);

// --- MODELS ---
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});

  Map<String, dynamic> toMap() => {'text': text, 'isUser': isUser};

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        text: map['text'] ?? '',
        isUser: map['isUser'] ?? false,
      );
}

// --- SCREEN WIDGET ---
class ChatAssistantScreen extends StatefulWidget {
  final AuthService? authService;
  final ChatbotService? chatbotService;

  const ChatAssistantScreen({
    super.key,
    this.authService,
    this.chatbotService,
  });

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatbotService _chatbotService;
  late final AuthService _authService;
  String? _uid;

  final List<ChatMessage> _messages = [];
  bool _isGiaTyping = false;

  @override
  bool get wantKeepAlive => true; // Tab tidak akan reset saat pindah

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _chatbotService = widget.chatbotService ?? ChatbotService();
    _uid = _authService.currentUser?.uid;
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? chatData = prefs.getString('chat_history_${_uid ?? "guest"}');

      if (chatData != null) {
        final List<dynamic> decoded = jsonDecode(chatData);
        if (mounted) {
          setState(() {
            _messages.addAll(decoded.map((m) => ChatMessage.fromMap(m)).toList());
          });
          _scrollToBottom();
        }
      } else {
        // Initial Greeting
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _messages.isEmpty) {
            _addGiaMessage(AppLocalizations.of(context)!.giaGreeting);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> toSave = _messages
          .where((m) => !m.text.contains("mengetik"))
          .map((m) => m.toMap())
          .toList();
      await prefs.setString('chat_history_${_uid ?? "guest"}', jsonEncode(toSave));
    } catch (e) {
      debugPrint("Error saving history: $e");
    }
  }

  void _addGiaMessage(String text) {
    if (!mounted) return;
    _messages.removeWhere((msg) => msg.text == "GIA sedang mengetik...");
    setState(() {
      _isGiaTyping = false;
      _messages.add(ChatMessage(text: text, isUser: false));
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
    });
    _saveChatHistory();
    _scrollToBottom();
    _handleGiaLogic(userText: text);
  }

  Future<void> _handleGiaLogic({required String userText}) async {
    if (!mounted) return;
    setState(() {
      _isGiaTyping = true;
      _messages.add(ChatMessage(text: "GIA sedang mengetik...", isUser: false));
    });
    _scrollToBottom();

    try {
      // 100% Menggunakan API Anda (app.py)
      final response = await _chatbotService.askQuestion(userText);
      if (mounted) {
        _addGiaMessage(response.answer);
      }
    } catch (e) {
      if (mounted) {
        _addGiaMessage(AppLocalizations.of(context)!.giaFallback);
      }
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !_isGiaTyping) {
      _addUserMessage(text);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.chatTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
            onPressed: _messages.isEmpty ? null : _confirmClearChat,
            tooltip: "Hapus Riwayat",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                if (message.text == "GIA sedang mengetik...") {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text("Hapus Riwayat?", style: TextStyle(color: Colors.white)),
        content: const Text("Semua percakapan akan dihapus secara permanen.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: kTextGrey))),
          TextButton(
            onPressed: () async {
              final greetingText = AppLocalizations.of(context)!.giaGreeting;
              Navigator.pop(context);
              setState(() => _messages.clear());
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('chat_history_${_uid ?? "guest"}');
              if (!mounted) return;
              _addGiaMessage(greetingText);
            }, 
            child: const Text("Hapus", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final color = message.isUser ? kUserBubble : kCardColor;
    final textColor = message.isUser ? kTextDark : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(),
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Pesan disalin"), duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: message.isUser ? const Radius.circular(16) : Radius.zero,
                    bottomRight: message.isUser ? Radius.zero : const Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: MarkdownBody(
                  data: message.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: textColor, fontSize: 15.5, height: 1.4),
                    strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                    listBullet: TextStyle(color: textColor),
                  ),
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return const Padding(
      padding: EdgeInsets.only(right: 8.0, top: 4.0),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Color(0x33C3A47B),
        child: Icon(Icons.psychology_outlined, color: kBrownAccent, size: 20),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          _buildAvatar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(16).copyWith(topLeft: Radius.zero),
            ),
            child: const _LoadingDots(color: kTextGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kCardColor, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: l10n.chatHint,
                  hintStyle: const TextStyle(color: kTextGrey, fontSize: 14),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSend(),
                enabled: !_isGiaTyping, 
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _textController.text.trim().isEmpty ? kCardColor : kUserBubble,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send, color: _textController.text.trim().isEmpty ? kTextGrey : kTextDark, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});
  @override
  State<_LoadingDots> createState() => __LoadingDotsState();
}

class __LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this)..repeat();
    _animation = IntTween(begin: 0, end: 3).animate(_controller);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Text("." * (_animation.value + 1), style: TextStyle(color: widget.color, fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}
