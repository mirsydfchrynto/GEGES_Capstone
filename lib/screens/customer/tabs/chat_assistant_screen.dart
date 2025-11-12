// lib/screens/customer/tabs/chat_assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- THEME COLORS (Konsisten) ---
const Color kBrownAccent = Color(0xFFC3A47B); 
const Color kSurface = Color(0xFF121212); // Dibuat sedikit lebih gelap dari 1B1B1B
const Color kCardColor = Color(0xFF2C2C2C); 
const Color kUserBubble = Color(0xFFE9B01A); 
const Color kTextDark = Color(0xFF1B1B1B); 
const Color kTextGrey = Colors.white70;

// --- DUMMY DATA ---

class ChatMessage {
  final String text;
  final bool isUser;
  final List<HaircutRecommendation>? recommendations;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.recommendations,
  });
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

  // Data Dummy untuk Demo UI diperbarui
  final List<ChatMessage> _messages = [];
  bool _isGiaTyping = false; // State untuk indikator mengetik

  @override
  void initState() {
    super.initState();
    // Start initial conversation
    Future.delayed(const Duration(milliseconds: 500), () {
      _addGiaMessage("Halo! Saya GIA, asisten virtual GEGES. Ada yang bisa saya bantu?");
    });
  }

  void _addGiaMessage(String text, {List<HaircutRecommendation>? recommendations}) {
    // Hapus indikator mengetik sebelum menambahkan pesan baru
    _messages.removeWhere((msg) => msg.text == "GIA is typing...");
    _isGiaTyping = false;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false, recommendations: recommendations));
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
    _simulateGiaResponse(text);
  }

  void _simulateGiaResponse(String userText) {
    // Tampilkan indikator mengetik
    setState(() {
      _isGiaTyping = true;
      _messages.add(ChatMessage(text: "GIA is typing...", isUser: false));
    });
    _scrollToBottom();

    // Logic balasan (simulasi)
    String lowerCaseText = userText.toLowerCase();

    if (lowerCaseText.contains("rekomendasi") || lowerCaseText.contains("gaya rambut")) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        _addGiaMessage(
          "Tentu! Berikut beberapa gaya rambut populer yang cocok untuk Anda:",
        );
        _addGiaMessage(
          "", // Pesan kosong untuk menampung bubble card
          recommendations: [
            HaircutRecommendation(
              title: 'Side Part',
              imageUrl: 'https://images.unsplash.com/photo-1621607567117-91f7c006c9a3?q=80&w=300&h=300&fit=crop', 
              onTap: () { /* Navigasi ke detail potongan */ },
            ),
            HaircutRecommendation(
              title: 'Undercut Klasik',
              imageUrl: 'https://images.unsplash.com/photo-1600880292203-757bb62b2baf?q=80&w=300&h=300&fit=crop', 
              onTap: () { /* Navigasi ke detail potongan */ },
            ),
            HaircutRecommendation(
              title: 'French Crop',
              imageUrl: 'https://images.unsplash.com/photo-1596484196191-4d3e5b306e98?q=80&w=300&h=300&fit=crop', 
              onTap: () { /* Navigasi ke detail potongan */ },
            ),
          ],
        );
      });
    } else if (lowerCaseText.contains("antrian") || lowerCaseText.contains("booking")) {
        Future.delayed(const Duration(milliseconds: 2000), () {
          _addGiaMessage("Antrian Anda saat ini (Booking ID: #GGS001) dijadwalkan pada hari Selasa, 10 Nov 2025, pukul 15:00 di Barbershop Utama. Apakah Anda ingin mengubah jadwal atau melihat detail?");
        });
    } else if (lowerCaseText.contains("alamat")) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          _addGiaMessage("GEGES Barbershop Utama berlokasi di Jl. Merdeka No. 45, Tegal. Kami buka setiap hari, 10:00 - 21:00.");
        });
    } else {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _addGiaMessage("Maaf, saya belum mengerti pertanyaan Anda. Anda bisa mencoba tombol aksi di bawah untuk bantuan cepat.");
      });
    }
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
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'GIA - GEGES Intelligent Assistant',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end, // Untuk menyamakan posisi teks
        children: [
          // Avatar GIA (Jika bukan User)
          if (!message.isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: kBrownAccent.withOpacity(0.2),
                child: const Icon(Icons.psychology_outlined, color: kBrownAccent, size: 20), 
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: message.isUser ? const Radius.circular(16) : Radius.zero,
                  topRight: message.isUser ? Radius.zero : const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                // Tambah sedikit shadow untuk efek elegan
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
              backgroundColor: kBrownAccent.withOpacity(0.2),
              child: const Icon(Icons.psychology_outlined, color: kBrownAccent, size: 20), 
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(16).copyWith(topLeft: Radius.zero),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GIA is typing', style: TextStyle(color: kTextGrey, fontStyle: FontStyle.italic)),
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
    return GestureDetector(
      onTap: rec.onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBrownAccent.withOpacity(0.3), width: 0.5)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: rec.imageUrl,
                height: 120, // Diperkecil sedikit
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: kSurface),
                errorWidget: (context, url, error) => const Center(child: Icon(Icons.cut, color: kTextGrey, size: 40)),
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
                      Text("Lihat Detail", style: TextStyle(color: kBrownAccent, fontSize: 12)),
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
    return Container(
      color: kSurface, // Pastikan background konsisten
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            _buildActionButton('Cek antrian saya', () => _addUserMessage('Cek antrian saya')),
            const SizedBox(width: 8),
            _buildActionButton('Rekomendasi gaya rambut', () => _addUserMessage('Rekomendasi gaya rambut')),
            const SizedBox(width: 8),
            _buildActionButton('Tanyakan alamat', () => _addUserMessage('Tanyakan alamat barbershop')),
            const SizedBox(width: 8),
            _buildActionButton('Buat Booking Baru', () => _addUserMessage('Buatkan booking baru')),
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
        backgroundColor: kCardColor.withOpacity(0.5), // Agar terlihat berbeda dari input
        side: const BorderSide(color: kBrownAccent, width: 1.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevation: 0,
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildInputArea() {
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
                    hintText: 'Tulis pesan...',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
                color: _textController.text.trim().isEmpty ? kCardColor : kUserBubble,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.send, color: _textController.text.trim().isEmpty ? kTextGrey : kTextDark, size: 24),
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

class __LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );
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
          style: TextStyle(color: widget.color, fontSize: 20, height: 0.5)
        );
      },
    );
  }
}