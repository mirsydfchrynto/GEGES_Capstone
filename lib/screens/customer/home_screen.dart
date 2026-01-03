// lib/screens/customer/home_screen.dart
// Versi: Multi-tab Navigation (Home, StyleScan, Chat Assistant, Profile)

import 'dart:async';
// Menggunakan Platform hanya untuk pengecekan OS
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import Model & Service ASLI
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/promo_banner.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

// Import Screens
import 'package:geges_smartbarber/screens/customer/tabs/barbershop_detail_screen.dart';
import 'package:geges_smartbarber/screens/customer/tabs/profile_screen.dart';
import 'package:geges_smartbarber/screens/customer/tabs/chat_assistant_screen.dart'; // CHATBOT
import 'package:geges_smartbarber/screens/customer/tabs/stylescan_screen.dart'; // STYLESCA N BARU
import 'package:geges_smartbarber/screens/customer/notifications_screen.dart'; // NOTIFIKASI

class HomeScreen extends StatefulWidget {
  final BarbershopService? barbershopService;
  const HomeScreen({super.key, this.barbershopService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BarbershopService _barbershopService;
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);

  int _selectedIndex = 0;
  late Future<List<Barbershop>> _barbershopFuture;
  
  // List of Screens (sesuai urutan BottomNavigationBar)
  late final List<Widget> _widgetOptions = <Widget>[
    _buildHomePageBody(), // Index 0: Home
    const StyleScanScreen(), // Index 1: StyleScan
    const ChatAssistantScreen(), // Index 2: Chatbot
    const ProfileScreen(), // Index 3: Profile
  ];

  // Search State
  List<Barbershop>? _searchResults;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _barbershopService = widget.barbershopService ?? BarbershopService();
    _barbershopFuture = _barbershopService.getAllBarbershops();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = null;
      });
      return;
    }

    // Set searching to true immediately to show feedback during debounce
    setState(() {
      _isSearching = true;
    });

    // In tests (where widget.barbershopService is provided), use zero delay
    final debounceDuration = widget.barbershopService != null
        ? Duration.zero
        : const Duration(milliseconds: 500);

    _debounce = Timer(debounceDuration, () async {
      try {
        final results = await _barbershopService.searchBarbershops(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint("Error in search debounce: $e");
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false; // Ensure loading stops even on error
          });
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Pindah halaman tanpa animasi (instan)
    _pageController.jumpToPage(index);
  }

  // --- UTILITY WIDGETS ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lokasi Saya',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'Mejasem, Tegal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_none_outlined,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            tooltip: 'Notifikasi',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search Barbershop or Services',
                  hintStyle: const TextStyle(color: Color(0xFF6B6B6B)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B)),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      return value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Color(0xFF6B6B6B), size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                  filled: true,          fillColor: kDarkGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: const BorderSide(color: kBrownAccent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 35,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w800,
          height: 0.7,
        ),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      ),
    );
  }

  Widget _buildRecommendedList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: FutureBuilder<List<Barbershop>>(
        future: _barbershopFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kBrownAccent),
            );
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            // Error handling/No Data
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: const Center(
                child: Text(
                  "Gagal memuat barbershop atau tidak ada data.",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }
          final barbershops = snapshot.data!;
          return Column(
            children: barbershops
                .map((shop) => _buildBarbershopCard(context, shop))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildBarbershopCard(BuildContext context, Barbershop shop) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarbershopDetailScreen(barbershop: shop),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: _buildImageFromPath(shop.imageUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          shop.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Icon(Icons.star, color: kBrownAccent, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            "${shop.rating} (133)",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shop.addres,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: shop.services
                        .map((s) => _buildTagChip(s))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BarbershopDetailScreen(barbershop: shop),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: kBrownAccent,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFromPath(String? path) {
    final String imgPath = path ?? '';
    if (imgPath.toLowerCase().startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imgPath,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: kDarkGrey),
        errorWidget: (context, url, error) => Container(
          color: kDarkGrey,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
          ),
        ),
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
      );
    } else {
      // Menggunakan Image.asset untuk path lokal
      return Image.asset(
        imgPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: kDarkGrey,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
            ),
          );
        },
      );
    }
  }

  Widget _buildTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  // Widget khusus untuk BODY Home Tab
  Widget _buildHomePageBody() {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          const SizedBox(height: 5),
          _buildSearchBar(),
          const SizedBox(height: 24),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PromoCarousel(
                      barbershopService: _barbershopService,
                    ),
                    const SizedBox(height: 21),
                    _buildSectionTitle("Barbershops\nnear you"),
                    const SizedBox(height: 18),
                    _buildRecommendedList(),
                  ],
                );
              } else {
                return _buildSearchResultsView();
              }
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 40.0),
        child: Center(child: CircularProgressIndicator(color: kBrownAccent)),
      );
    }

    if (_searchResults != null && _searchResults!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40.0),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                'Tidak ditemukan hasil untuk "${_searchController.text}"',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final results = _searchResults!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Found ${results.length} ${results.length == 1 ? 'result' : 'results'}",
            style: const TextStyle(color: kBrownAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...results.map((shop) => _buildBarbershopCard(context, shop)),
        ],
      ),
    );
  }

  // --- WIDGET UTAMA (SCAFFOLD) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // Menggunakan PageView untuk beralih antar tab
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        physics: const NeverScrollableScrollPhysics(), // Nonaktifkan swipe
        children: _widgetOptions,
      ),

      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'StyleScan',
          ), // Update Icon & Label
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chatbot',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        backgroundColor: kDarkGrey,
        selectedItemColor: kBrownAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        showUnselectedLabels: true,
        showSelectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: _onItemTapped, // Menggunakan handler
      ),
    );
  }
}

// --- PromoCarousel WIDGET (TIDAK BERUBAH) ---
/// PromoCarousel: widget terpisah untuk mengelola stream, pagecontroller, timer, interaksi
class PromoCarousel extends StatefulWidget {
  final BarbershopService barbershopService;
  const PromoCarousel({required this.barbershopService, super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel>
    with AutomaticKeepAliveClientMixin {
  final PageController _controller = PageController(initialPage: 0);
  Timer? _timer;
  int _current = 0;
  bool _userInteracting = false;
  List<PromoBanner> _banners = [];
  StreamSubscription<List<PromoBanner>>? _sub;

  Timer? _attachChecker;

  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kBrownAccent = Color(0xFFC3A47B);

  @override
  void initState() {
    super.initState();

    _sub = widget.barbershopService.getPromoBanners().listen(
      (data) {
        final changed = !_listEqualsByUrl(_banners, data);
        _banners = data;

        if (mounted && changed) {
          setState(() {
            if (_current >= _banners.length) _current = 0;
            if (_controller.hasClients) {
              try {
                _controller.jumpToPage(_current);
              } catch (_) {}
            }
          });
        }

        _startAutoWhenAttached();
      },
      onError: (e) {
        debugPrint("Promo stream error: $e");
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoWhenAttached();
    });
  }

  void _startAutoWhenAttached() {
    if (_timer != null && _timer!.isActive) return;
    _attachChecker?.cancel();

    int tries = 0;
    _attachChecker = Timer.periodic(const Duration(milliseconds: 100), (t) {
      tries++;
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_controller.hasClients && _banners.length > 1) {
        t.cancel();
        _attachChecker = null;
        _ensureAutoScroll();
        return;
      }
      if (tries >= 50) {
        t.cancel();
        _attachChecker = null;
        _ensureAutoScroll();
      }
    });
  }

  bool _listEqualsByUrl(List<PromoBanner> a, List<PromoBanner> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].imageUrl != b[i].imageUrl) return false;
    }
    return true;
  }

  void _ensureAutoScroll() {
    _timer?.cancel();
    _timer = null;

    if (_banners.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 4), (t) async {
      if (!mounted) return;
      if (_userInteracting) return;
      if (!_controller.hasClients) return;

      final next = (_current + 1) % _banners.length;
      try {
        await _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        debugPrint("Auto animate error: $e");
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _attachChecker?.cancel();
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_banners.isEmpty) {
      return Container(
        height: 160,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: kBrownAccent),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Listener(
            onPointerDown: (_) {
              _userInteracting = true;
            },
            onPointerUp: (_) {
              Future.delayed(const Duration(milliseconds: 400), () {
                _userInteracting = false;
              });
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: _banners.length,
              onPageChanged: (index) {
                setState(() {
                  _current = index;
                });
              },
              itemBuilder: (context, index) {
                final promo = _banners[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: promo.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: kDarkGrey),
                          errorWidget: (context, url, error) => Container(
                            color: kDarkGrey,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          useOldImageOnUrlChange: true,
                        ),
                        Container(color: Colors.black.withValues(alpha: 0.28)),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                promo.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8.0,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                promo.subtitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
