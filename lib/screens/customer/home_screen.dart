// lib/screens/customer/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/promo_banner.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/location_service.dart';
import 'package:geges_smartbarber/screens/customer/tabs/barbershop_detail_screen.dart';
import 'package:geges_smartbarber/screens/customer/tabs/profile_screen.dart';
import 'package:geges_smartbarber/screens/customer/tabs/chat_assistant_screen.dart';
import 'package:geges_smartbarber/screens/customer/tabs/stylescan_screen.dart';
import 'package:geges_smartbarber/screens/customer/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final BarbershopService? barbershopService;
  const HomeScreen({super.key, this.barbershopService});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BarbershopService _barbershopService;
  final LocationService _locationService = LocationService();
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  int _selectedIndex = 0;
  late Future<List<Barbershop>> _barbershopFuture;
  String _currentAddress = 'Menentukan lokasi...';
  bool _isLocating = false;
  List<Barbershop>? _searchResults;
  Timer? _debounce;
  Map<String, String> _serviceNames = {};

  late final List<Widget> _widgetOptions = <Widget>[
    _buildHomePageBody(), const StyleScanScreen(), const ChatAssistantScreen(), const ProfileScreen(),
  ];

  @override void initState() {
    super.initState();
    _barbershopService = widget.barbershopService ?? BarbershopService();
    _barbershopFuture = _barbershopService.getAllBarbershops();
    _updateLocation();
    _fetchServiceNames();
  }

  Future<void> _fetchServiceNames() async {
    try {
      final services = await _barbershopService.getAllServices();
      if (mounted) setState(() => _serviceNames = {for (var s in services) s.id: s.name});
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _updateLocation() async {
    if (_isLocating) return;
    setState(() { _isLocating = true; _currentAddress = 'Menentukan lokasi...'; });
    try {
      final address = await _locationService.getCurrentLocationAddress();
      if (mounted) setState(() { _currentAddress = address ?? 'Lokasi tidak ditemukan'; _isLocating = false; });
    } catch (e) { if (mounted) setState(() { _currentAddress = 'Error lokasi'; _isLocating = false; }); }
  }

  @override void dispose() { _pageController.dispose(); _searchController.dispose(); _debounce?.cancel(); super.dispose(); }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) { setState(() => _searchResults = null); return; }
    _debounce = Timer(const Duration(milliseconds: 100), () async {
      try { final results = await _barbershopService.searchBarbershops(query); if (mounted) setState(() => _searchResults = results); } catch (e) { if (mounted) setState(() => _searchResults = []); }
    });
  }

  void _onItemTapped(int index) { setState(() => _selectedIndex = index); _pageController.jumpToPage(index); }

  Widget _buildHeader() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      GestureDetector(onTap: _isLocating ? null : _updateLocation, child: Row(children: [const Icon(Icons.location_on, color: Colors.white, size: 20), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Text('Lokasi Saya', style: TextStyle(color: Colors.white70, fontSize: 12)), if (_isLocating) ...[const SizedBox(width: 8), const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: kBrownAccent))] else ...[const SizedBox(width: 4), const Icon(Icons.refresh, color: Colors.white54, size: 12)]]), Text(_currentAddress, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))])])),
      IconButton(icon: const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())), tooltip: 'Notifikasi'),
    ]));
  }

  Widget _buildSearchBar() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: TextField(controller: _searchController, onChanged: _onSearchChanged, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Search Barbershop or Services', hintStyle: const TextStyle(color: Color(0xFF6B6B6B)), prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B)), suffixIcon: ValueListenableBuilder<TextEditingValue>(valueListenable: _searchController, builder: (context, value, _) => value.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Color(0xFF6B6B6B), size: 20), onPressed: () { _searchController.clear(); _onSearchChanged(''); }) : const SizedBox.shrink()), filled: true, fillColor: kDarkGrey, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: const BorderSide(color: kBrownAccent, width: 1.5)))));
  }

  Widget _buildRecommendedList() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: FutureBuilder<List<Barbershop>>(future: _barbershopFuture, builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kBrownAccent)); if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) return Container(padding: const EdgeInsets.symmetric(vertical: 40), child: const Center(child: Text("Gagal memuat barbershop.", style: TextStyle(color: Colors.white70)))); return Column(children: snapshot.data!.map((shop) => _buildBarbershopCard(context, shop)).toList());
    }));
  }

  Widget _buildBarbershopCard(BuildContext context, Barbershop shop) {
    return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BarbershopDetailScreen(barbershop: shop))), child: Container(margin: const EdgeInsets.only(bottom: 20.0), decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: SizedBox(height: 180, width: double.infinity, child: _buildImage(shop.imageUrl))),
      Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(shop.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(width: 16), Row(children: [const Icon(Icons.access_time, color: kBrownAccent, size: 18), const SizedBox(width: 6), Text("${shop.openHour}:00 - ${shop.closeHour}:00", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))])]),
        const SizedBox(height: 8), Text(shop.addres, style: const TextStyle(color: Colors.white70, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: shop.services.map((id) => _buildTagChip(id)).toList(),
        ),
        const SizedBox(height: 20), 
        ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BarbershopDetailScreen(barbershop: shop))), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: kBrownAccent, foregroundColor: Colors.black), child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold)))
      ]))
    ])));
  }

  Widget _buildImage(String path) => path.startsWith('http') ? CachedNetworkImage(imageUrl: path, fit: BoxFit.cover, placeholder: (c, u) => Container(color: kDarkGrey), errorWidget: (c, u, e) => Container(color: kDarkGrey, child: const Icon(Icons.broken_image, color: Colors.white54, size: 48))) : Image.asset(path, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: kDarkGrey, child: const Icon(Icons.broken_image, color: Colors.white54, size: 48)));

  Widget _buildTagChip(String id) {
    final bool loading = _serviceNames.isEmpty;
    final String label = loading ? "••••••" : (_serviceNames[id] ?? id);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), decoration: BoxDecoration(color: loading ? Colors.white10 : Colors.grey.shade800, borderRadius: BorderRadius.circular(30.0)), child: Text(label, style: TextStyle(color: loading ? Colors.transparent : Colors.white, fontSize: 12)));
  }

  Widget _buildHomePageBody() {
    return SafeArea(bottom: false, child: ListView(padding: EdgeInsets.zero, children: [
      _buildHeader(), const SizedBox(height: 5), _buildSearchBar(), const SizedBox(height: 24),
      ValueListenableBuilder<TextEditingValue>(valueListenable: _searchController, builder: (context, value, _) => value.text.isEmpty ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [PromoCarousel(barbershopService: _barbershopService), const SizedBox(height: 21), _buildTitle("Barbershops\nnear you"), const SizedBox(height: 18), _buildRecommendedList()]) : _buildSearch(value.text)),
      const SizedBox(height: 30),
    ]));
  }

  Widget _buildSearch(String q) {
    if (_searchResults == null) return const Padding(padding: EdgeInsets.only(top: 40.0), child: Center(child: CircularProgressIndicator(color: kBrownAccent)));
    if (_searchResults!.isEmpty) return Padding(padding: const EdgeInsets.only(top: 40.0), child: Center(child: Column(children: [const Icon(Icons.search_off, size: 64, color: Colors.white24), const SizedBox(height: 16), Text('Tidak ditemukan hasil untuk "$q"', style: const TextStyle(color: Colors.white54, fontSize: 16))])));
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Found ${_searchResults!.length} results", style: const TextStyle(color: kBrownAccent, fontWeight: FontWeight.bold)), const SizedBox(height: 16), ..._searchResults!.map((shop) => _buildBarbershopCard(context, shop))]));
  }

  Widget _buildTitle(String t) => Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 35, fontFamily: 'Poppins', fontWeight: FontWeight.w800, height: 0.7)));

  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.black, body: PageView(controller: _pageController, onPageChanged: (i) => setState(() => _selectedIndex = i), physics: const NeverScrollableScrollPhysics(), children: _widgetOptions), bottomNavigationBar: BottomNavigationBar(items: const [BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'), BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'StyleScan'), BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chatbot'), BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile')], type: BottomNavigationBarType.fixed, backgroundColor: kDarkGrey, selectedItemColor: kBrownAccent, unselectedItemColor: Colors.white54, currentIndex: _selectedIndex, showUnselectedLabels: true, showSelectedLabels: true, selectedFontSize: 12, unselectedFontSize: 12, onTap: _onItemTapped)); }
}

class PromoCarousel extends StatefulWidget {
  final BarbershopService barbershopService;
  const PromoCarousel({required this.barbershopService, super.key});
  @override State<PromoCarousel> createState() => _PromoCarouselState();
}
class _PromoCarouselState extends State<PromoCarousel> with AutomaticKeepAliveClientMixin {
  final PageController _controller = PageController(initialPage: 0);
  Timer? _timer;
  int _current = 0;
  bool _interacting = false;
  List<PromoBanner> _banners = [];
  StreamSubscription? _sub;

  @override void initState() {
    super.initState();
    _sub = widget.barbershopService.getPromoBanners().listen((data) {
      if (mounted) setState(() { _banners = data; });
    });
    _timer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (mounted && !_interacting && _controller.hasClients && _banners.length > 1) {
        _current = (_current + 1) % _banners.length;
        _controller.animateToPage(_current, duration: const Duration(milliseconds: 380), curve: Curves.easeInOut);
      }
    });
  }

  @override void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    if (_banners.isEmpty) return Container(height: 160, margin: const EdgeInsets.symmetric(horizontal: 24.0), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)), child: const Center(child: CircularProgressIndicator(color: Color(0xFFC3A47B))));
    return Column(children: [
      SizedBox(height: 160, child: Listener(
        onPointerDown: (_) => _interacting = true,
        onPointerUp: (_) => Future.delayed(const Duration(milliseconds: 400), () => _interacting = false),
        child: PageView.builder(controller: _controller, itemCount: _banners.length, onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (context, index) {
            final p = _banners[index];
            return Container(margin: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(imageUrl: p.imageUrl, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.black12), errorWidget: (c, u, e) => const Icon(Icons.broken_image)),
                Container(color: Colors.black26),
                Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(p.subtitle, style: const TextStyle(color: Colors.white, fontSize: 14))]))
              ]))
            );
          }
        )
      ))
    ]);
  }

  @override bool get wantKeepAlive => true;
}