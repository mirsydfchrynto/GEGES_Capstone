// lib/screens/customer/tabs/chat_assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';

// --- THEME COLORS (Konsisten) ---
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kSurface = Color(
  0xFF121212,
); // Dibuat sedikit lebih gelap dari 1B1B1B
const Color kCardColor = Color(0xFF2C2C2C);
const Color kUserBubble = Color(0xFFE9B01A);
const Color kTextDark = Color(0xFF1B1B1B);
const Color kTextGrey = Colors.white70;

// --- DUMMY DATA ---

class ChatMessage {
  final String text;
  final bool isUser;
  final List<HaircutRecommendation>? recommendations;

  ChatMessage({required this.text, required this.isUser, this.recommendations});
}

class HaircutRecommendation {
  final String title;
  final String imageUrl;
  final String description; // Tambah deskripsi untuk card
  final VoidCallback onTap;

  HaircutRecommendation({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.description = "Lihat detail gaya rambut ini.",
  });
}

// --- SCREEN WIDGET ---

class ChatAssistantScreen extends StatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final QueueService _queueService = QueueService();
  final BarbershopService _barbershopService = BarbershopService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // Data Dummy untuk Demo UI diperbarui
  final List<ChatMessage> _messages = [];
  bool _isGiaTyping = false; // State untuk indikator mengetik

  @override
  void initState() {
    super.initState();
    // Start initial conversation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _addGiaMessage(l10n.giaGreeting);
      }
    });
  }

  void _addGiaMessage(
    String text, {
    List<HaircutRecommendation>? recommendations,
  }) {
    if (!mounted) return;
    // Hapus indikator mengetik sebelum menambahkan pesan baru
    _messages.removeWhere((msg) => msg.text == "GIA is typing...");
    _isGiaTyping = false;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: false,
          recommendations: recommendations,
        ),
      );
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
    });
    _scrollToBottom();
    // Simulate GIA response logic
    _handleGiaLogic(userText: text);
  }

  Future<void> _handleGiaLogic({required String userText}) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    // Tampilkan indikator mengetik
    setState(() {
      _isGiaTyping = true;
      _messages.add(ChatMessage(text: "GIA is typing...", isUser: false));
    });
    _scrollToBottom();

    String lowerCaseText = userText.toLowerCase();

    // LOGIKA NYATA (REAL LOGIC)
    
    // 1. CEK ANTRIAN
    if (lowerCaseText.contains("antrian") || lowerCaseText.contains("booking") || lowerCaseText.contains("jadwal") || lowerCaseText.contains("queue")) {
       if (_uid == null) {
         _addGiaMessage(l10n.errMustLoginChat);
         return;
       }
       
       try {
         // Ambil booking aktif
         final queuesStream = _queueService.streamQueuesForCustomer(_uid, statusFilter: ['waiting', 'awaiting_payment', 'booked', 'ongoing']);
         final queues = await queuesStream.first; // Ambil snapshot pertama

         if (!mounted) return; // FIX: Async gap check

         if (queues.isEmpty) {
           _addGiaMessage(l10n.noActiveBookings);
         } else {
           final q = queues.first;
           final locale = Localizations.localeOf(context).toString();
           final dateStr = DateFormat('EEEE, d MMM HH:mm', locale).format(q.bookingTime.toDate());
           final statusStr = q.status.value.toUpperCase();
           _addGiaMessage(l10n.activeBookingDesc(dateStr, statusStr, q.barbershopId));
         }
       } catch (e) {
         _addGiaMessage(l10n.errCheckQueueFailed);
       }
       return;
    }

    // 2. REKOMENDASI GAYA (Ambil dari Services di DB)
    if (lowerCaseText.contains("rekomendasi") || lowerCaseText.contains("gaya") || lowerCaseText.contains("potongan") || lowerCaseText.contains("style") || lowerCaseText.contains("recommendation")) {
      try {
        final services = await _barbershopService.getAllServices();
        if (services.isEmpty) {
           _addGiaMessage(l10n.errNoStylesAvailable);
        } else {
          // Ambil 3 acak
          services.shuffle();
          final top3 = services.take(3).toList();
          
          _addGiaMessage(l10n.popularServicesHeader);
          _addGiaMessage("", recommendations: top3.map((s) => HaircutRecommendation(
            title: s.name,
            imageUrl: "https://via.placeholder.com/300?text=${s.name.replaceAll(' ', '+')}", // Placeholder jika tidak ada gambar
            description: "${s.defaultDuration} ${l10n.chatMinutes} - Rp${s.price}",
            onTap: () {}
          )).toList());
        }
      } catch (e) {
         _addGiaMessage(l10n.errLoadRecommendationFailed);
      }
      return;
    }
    
    // 3. STATIC INFO (Alamat, Jam Buka)
    if (lowerCaseText.contains("alamat") || lowerCaseText.contains("lokasi") || lowerCaseText.contains("address") || lowerCaseText.contains("location")) {
       _addGiaMessage(l10n.branchInfo);
       return;
    }

    // DEFAULT FALLBACK
    Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _addGiaMessage(l10n.giaFallback);
        }
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !_isGiaTyping) {
      _addUserMessage(text);
    }
  }

  void _scrollToBottom() {
    // Memberi waktu untuk widget baru dirender sebelum scroll
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.chatTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Ganti placeholder asset dengan Ikon User (lebih elegan untuk desain gelap)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: kCardColor,
              child: Icon(Icons.person_outline, color: kBrownAccent, size: 24),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                if (message.text == "GIA is typing...") {
                  return _buildTypingIndicator();
                }
                if (message.recommendations != null) {
                  return _buildRecommendationBubble(message);
                }
                return _buildMessageBubble(message);
              },
            ),
          ),
          // --- Action Buttons dan Input dipisahkan agar rapi ---
          _buildActionButtons(),
          _buildInputArea(),
        ],
      ),
    );
  }

  // --- WIDGET KOMPONEN ---

  Widget _buildMessageBubble(ChatMessage message) {
    final color = message.isUser ? kUserBubble : kCardColor;
    final textColor = message.isUser ? kTextDark : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment:
            CrossAxisAlignment.end, // Untuk menyamakan posisi teks
        children: [
          // Avatar GIA (Jika bukan User)
          if (!message.isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: kBrownAccent.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: kBrownAccent,
                  size: 20,
                ),
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: message.isUser
                      ? const Radius.circular(16)
                      : Radius.zero,
                  topRight: message.isUser
                      ? Radius.zero
                      : const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                // Tambah sedikit shadow untuk efek elegan
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Text(
                message.text,
                style: TextStyle(color: textColor, fontSize: 15.5),
              ),
            ),
          ),
          // Avatar User (Opsional, tapi di desain ini tidak ada)
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // lib/screens/customer/tabs/chat_assistant_screen.dart
  // ...

  Widget _buildTypingIndicator() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar GIA
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: kBrownAccent.withValues(alpha: 0.2),
              child: const Icon(
                Icons.psychology_outlined,
                color: kBrownAccent,
                size: 20,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(
                16,
              ).copyWith(topLeft: Radius.zero),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.giaTyping,
                  style: const TextStyle(
                    color: kTextGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 6),
                // Indikator Titik (Menggunakan widget kustom yang diperbaiki)
                // Gantikan TweenAnimationBuilder yang Error dengan widget kustom yang menggunakan AnimationController
                _LoadingDots(color: kTextGrey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... (lanjutkan kode lainnya) ...

  Widget _buildRecommendationBubble(ChatMessage message) {
    if (message.recommendations == null || message.recommendations!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Bubble card ditempatkan di bawah bubble teks GIA sebelumnya
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 40), // Offset sejajar dengan isi bubble GIA
          Expanded(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: message.recommendations!.length,
                itemBuilder: (context, index) {
                  final rec = message.recommendations![index];
                  return _buildHaircutCard(rec);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHaircutCard(HaircutRecommendation rec) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: rec.onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kBrownAccent.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: rec.imageUrl,
                height: 120, // Diperkecil sedikit
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: kSurface),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.cut, color: kTextGrey, size: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.style, size: 14, color: kBrownAccent),
                      const SizedBox(width: 4),
                      Text(
                        l10n.seeDetail,
                        style: const TextStyle(color: kBrownAccent, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: kSurface, // Pastikan background konsisten
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            _buildActionButton(
              l10n.btnCheckMyQueue,
              () => _addUserMessage(l10n.btnCheckMyQueue),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              l10n.btnHaircutRecommendation,
              () => _addUserMessage(l10n.btnHaircutRecommendation),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              l10n.btnAskAddress,
              () => _addUserMessage(l10n.btnAskAddress),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              l10n.btnCreateNewBooking,
              () => _addUserMessage(l10n.btnCreateNewBooking),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: kCardColor.withValues(
          alpha: 0.5,
        ), // Agar terlihat berbeda dari input
        side: const BorderSide(color: kBrownAccent, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildInputArea() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kCardColor, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Attachment Button
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.add, color: kBrownAccent, size: 24),
          ),
          const SizedBox(width: 12),
          // Text Input
          Expanded(
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: l10n.chatHint,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                  enabled: !_isGiaTyping, // Disable input saat GIA mengetik
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send Button
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _textController.text.trim().isEmpty
                    ? kCardColor
                    : kUserBubble,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.send,
                color: _textController.text.trim().isEmpty
                    ? kTextGrey
                    : kTextDark,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET BARU UNTUK ANIMASI TITIK-TITIK ---
class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => __LoadingDotsState();
}

class __LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Logika animasi titik-titik
        final value = _animation.value;
        String dots;
        if (value < 0.33) {
          dots = '.';
        } else if (value < 0.66) {
          dots = '..';
        } else {
          dots = '...';
        }

        return Text(
          dots,
          style: TextStyle(color: widget.color, fontSize: 20, height: 0.5),
        );
      },
    );
  }
}
