# DOKUMENTASI PROMO CAROUSEL WIDGET

## Lokasi File
`lib/screens/customer/home_screen.dart` (bagian PromoCarousel)

## Deskripsi
PromoCarousel adalah widget yang menampilkan slider gambar promo dengan animasi otomatis.

## Features
- Menampilkan banner promo dengan scroll horizontal
- Auto-slide setiap 4 detik
- Pause auto-slide saat user sedang interact (touch)
- Load data realtime dari firebase
- Indicator dot untuk show posisi banner sekarang

## Struktur Code

```dart
// =====================================================
// PROMO CAROUSEL WIDGET (STATELESS - WRAPPER)
// =====================================================
class PromoCarousel extends StatefulWidget {
  final BarbershopService barbershopService;
  const PromoCarousel({required this.barbershopService, super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

// penjelasan:
// - PromoCarousel adalah stateful widget yang menerima parameter barbershopservice
// - parameter ini adalah instance dari service yang berfungsi untuk ambil promo data
// - createState() return state class (_PromoCarouselState) yang mengelola logic
```

## State Class (_PromoCarouselState)

### Lifecycle Mixin
```dart
class _PromoCarouselState extends State<PromoCarousel> 
    with AutomaticKeepAliveClientMixin {
```

**Penjelasan AutomaticKeepAliveClientMixin:**
- Mixin adalah class yang memberikan fungsionalitas tambahan
- AutomaticKeepAliveClientMixin membuat widget tetap hidup (tidak di-dispose) meski tidak visible
- Sangat penting untuk carousel yang punya timer otomatis
- Tanpa ini, carousel akan di-dispose ketika user swipe ke tab lain, dan timer akan hilang
- Dengan ini, carousel tetap jalan di background

### Properties

```dart
// =====================================================
// CONTROLLERS & DATA
// =====================================================
final PageController _controller = PageController(initialPage: 0);
// PageController: untuk programmatic control pageview
// initialPage: 0 = mulai dari halaman pertama
// gunakan _controller.jumpToPage() atau _controller.animateToPage() untuk pindah halaman

Timer? _timer;
// Timer: untuk auto-slide setiap 4 detik
// nullable (bisa null) karena mungkin tidak ada banner (tidak perlu timer)

int _current = 0;
// index banner yang sekarang ditampilkan (0, 1, 2, 3, ...)
// digunakan untuk update indicator dot

bool _userInteracting = false;
// flag: apakah user sedang menyentuh screen (drag pageview)
// jika true, pause auto-slide (jangan auto-slide saat user drag)
// jika false, lanjutkan auto-slide

List<PromoBanner> _banners = [];
// list yang berisi semua promo banner
// diupdate setiap kali ada data baru dari stream

StreamSubscription<List<PromoBanner>>? _sub;
// stream subscription: listen pada perubahan data promo di firebase
// nullable karena perlu di-cancel di dispose
// ?? digunakan untuk unsubscribe dari stream

Timer? _attachChecker;
// timer khusus untuk check apakah pagecontroller sudah ready
// ketika pagecontroller belum ready, tidak bisa animate/jump
// timer ini delay sampai pagecontroller ready baru jalankan auto-slide
```

### Key Methods

#### initState() - Initialization
```dart
@override
void initState() {
  super.initState();

  // penjelasan listen():
  // - subscribe pada stream promo banners dari service
  // - setiap kali ada perubahan data di firebase, callback akan dipanggil
  // - data adalah list<promobanner> terbaru
  _sub = widget.barbershopService.getPromoBanners().listen((data) {
    // penjelasan _listequalsbyurl():
    // - cek apakah data banner berubah
    // - compare menggunakan imageurl (jangan compare object langsung, cek propertinya)
    // - changed = true jika ada perubahan, false jika sama
    final changed = !_listEqualsByUrl(_banners, data);
    _banners = data;  // update local variable

    // jika ada perubahan data, update UI
    if (mounted && changed) {
      setState(() {
        // jika current index > length banner baru, reset ke 0
        if (_current >= _banners.length) _current = 0;
        
        // jika pagecontroller sudah ready, jump ke halaman sesuai _current
        if (_controller.hasClients) {
          try {
            _controller.jumpToPage(_current);  // instant jump
          } catch (_) {}  // catch error (jangan throw, just ignore)
        }
      });
    }

    // jalankan auto-scroll setelah data update
    _startAutoWhenAttached();
  }, onError: (e) {
    // handle error saat stream (contoh: network error, permission denied, dll)
    debugPrint("Promo stream error: $e");
  });

  // penjelasan addpostframecallback():
  // - jalankan callback SETELAH frame pertama selesai render
  // - gunakan untuk akses pagecontroller yang baru ready
  // - tanpa ini, pagecontroller mungkin belum attach saat initstate
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startAutoWhenAttached();  // coba jalankan auto-scroll
  });
}
```

#### _startAutoWhenAttached() - Check PageController Ready
```dart
void _startAutoWhenAttached() {
  // penjelasan:
  // - method ini coba start auto-scroll
  // - tapi harus tunggu sampai pagecontroller ready (hasClients == true)
  // - gunakan timer yang check setiap 100ms sampai ready
  
  // jika timer sudah jalan, jangan buat yang baru
  if (_timer != null && _timer!.isActive) return;
  
  // cancel attach checker yang lama (jika ada)
  _attachChecker?.cancel();

  int tries = 0;
  // periodic timer: jalankan callback setiap 100ms
  _attachChecker = Timer.periodic(const Duration(milliseconds: 100), (t) {
    tries++;
    
    // jika widget sudah di-dispose, stop timer
    if (!mounted) {
      t.cancel();
      return;
    }
    
    // kondisi sukses: pagecontroller ready dan ada lebih dari 1 banner
    if (_controller.hasClients && _banners.length > 1) {
      t.cancel();  // stop checking
      _attachChecker = null;
      _ensureAutoScroll();  // start auto-scroll
      return;
    }
    
    // jika sudah coba 50x (5 detik) dan belum ready, force start anyway
    if (tries >= 50) {
      t.cancel();
      _attachChecker = null;
      _ensureAutoScroll();
    }
  });
}
```

#### _listEqualsByUrl() - Compare Banners
```dart
bool _listEqualsByUrl(List<PromoBanner> a, List<PromoBanner> b) {
  // penjelasan:
  // - compare 2 list banner berdasarkan url
  // - gunakan url karena url adalah identifier unik untuk image
  // - jika list panjang berbeda, pasti berbeda
  
  if (a.length != b.length) return false;
  
  // compare setiap element berdasarkan imageurl
  for (int i = 0; i < a.length; i++) {
    if (a[i].imageUrl != b[i].imageUrl) return false;
  }
  
  // semua sama, return true
  return true;
}
```

#### _ensureAutoScroll() - Start Auto Animation
```dart
void _ensureAutoScroll() {
  // penjelasan:
  // - method ini menjalankan auto-scroll setiap 4 detik
  // - gunakan timer.periodic() untuk repeat setiap interval
  
  // cancel timer yang lama dulu (cleanup)
  _timer?.cancel();
  _timer = null;

  // jika hanya 1 atau 0 banner, tidak perlu auto-scroll
  if (_banners.length <= 1) return;

  // jalankan auto-scroll setiap 4 detik
  _timer = Timer.periodic(const Duration(seconds: 4), (t) async {
    // jika widget di-dispose, stop
    if (!mounted) return;
    
    // jika user sedang drag, jangan auto-scroll (pause)
    if (_userInteracting) return;
    
    // jika pagecontroller belum ready, skip
    if (!_controller.hasClients) return;

    // hitung index berikutnya
    // % adalah operator modulo (sisa bagi)
    // contoh: jika current = 2, length = 3, next = (2+1)%3 = 0 (kembali ke awal)
    final next = (_current + 1) % _banners.length;
    
    try {
      // animasi ke halaman berikutnya (smooth scroll 380ms)
      await _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),  // lama animasi
        curve: Curves.easeInOut,  // jenis kurva animasi (smooth acceleration/deceleration)
      );
    } catch (e) {
      // catch error (contoh: pagecontroller sudah di-dispose)
      debugPrint("Auto animate error: $e");
    }
  });
}
```

#### dispose() - Cleanup Resources
```dart
@override
void dispose() {
  // penjelasan dispose:
  // - method ini dipanggil saat widget dihapus/ditutup
  // - HARUS cleanup semua resource yang pake memory/CPU
  // - jika tidak cleanup, bisa memory leak atau timer terus jalan
  
  _timer?.cancel();          // stop auto-scroll timer
  _attachChecker?.cancel();  // stop attach checker timer
  _sub?.cancel();            // unsubscribe dari stream (stop listen data)
  _controller.dispose();     // release pagecontroller
  super.dispose();           // call parent dispose
}
```

#### build() - UI Rendering
```dart
@override
Widget build(BuildContext context) {
  // penjelasan super.build(context):
  // - harus dipanggil di awal build() saat menggunakan AutomaticKeepAliveClientMixin
  // - ini memberi tahu flutter bahwa widget ingin tetap alive
  super.build(context);
  
  // jika belum ada banner, tampilkan loading
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

  // jika ada banner, tampilkan carousel
  return Column(
    children: [
      SizedBox(
        height: 160,  // tinggi carousel
        child: Listener(
          // penjelasan listener:
          // - membuat child widget responsive terhadap pointer event (tap, drag)
          // - onPointerDown: callback saat user mulai touch
          // - onPointerUp: callback saat user berhenti touch
          onPointerDown: (_) {
            // user mulai drag, set userinteracting = true
            // ini akan pause auto-scroll di _ensureautoscroll()
            _userInteracting = true;
          },
          onPointerUp: (_) {
            // user selesai drag, tapi delay 400ms baru set false
            // ini agar user bisa swipe beberapa kali tanpa auto-scroll
            Future.delayed(const Duration(milliseconds: 400), () {
              _userInteracting = false;
            });
          },
          child: PageView.builder(
            // penjelasan pageview.builder:
            // - pageview yang lazy-load item (efficient untuk banyak item)
            // - itembuilder: callback untuk build item sesuai index
            controller: _controller,
            itemCount: _banners.length,  // jumlah item = jumlah banner
            onPageChanged: (index) {
              // callback saat user swipe atau pagecontroller.jumptopage()/animatetopage()
              // update _current untuk indicator dot
              setState(() {
                _current = index;
              });
            },
            itemBuilder: (context, index) {
              final promo = _banners[index];
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ClipRRect(
                  // penjelasan cliprrect:
                  // - clip child widget ke rounded rectangle shape
                  // - jadi image tidak keluar dari border rounded
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    // penjelasan stack:
                    // - overlay multiple widgets (yang belakang dulu, yang depan terakhir)
                    // - digunakan untuk put text dan overlay di atas image
                    fit: StackFit.expand,  // stretch semua child sesuai stack size
                    children: [
                      // layer 1: image promo (paling belakang)
                      CachedNetworkImage(
                        imageUrl: promo.imageUrl ?? '',
                        fit: BoxFit.cover,  // stretch image untuk fill container
                        placeholder: (context, url) => Container(color: kDarkGrey),
                        errorWidget: (context, url, error) => Container(
                          color: kDarkGrey,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54),
                          ),
                        ),
                        fadeInDuration: Duration.zero,  // tanpa fade animation
                        fadeOutDuration: Duration.zero,
                        useOldImageOnUrlChange: true,   // cache image lama sampai baru ready
                      ),
                      
                      // layer 2: dark overlay (gelap untuk baca text)
                      Container(
                        color: Colors.black.withOpacity(0.28),  // 28% opaque black
                      ),
                      
                      // layer 3: text promo (paling depan)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // title promo
                            Text(
                              promo.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    blurRadius: 8.0,
                                    color: Colors.black45,  // shadow untuk baca text
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // subtitle promo
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
                );
              };
            },
          ),
        ),
      ),
    ],
  );
}
```

#### wantKeepAlive Getter
```dart
@override
bool get wantKeepAlive => true;

// penjelasan:
// - getter ini harus return true saat menggunakan AutomaticKeepAliveClientMixin
// - memberitahu flutter: "jangan dispose widget ini, aku mau tetap hidup"
// - ini penting untuk timer carousel yang ingin tetap jalan
```

## Flow Diagram

```
initState()
    ↓
subscribe ke stream promo banners (barbershopservice.getpromombanners())
    ↓
setiap ada data baru dari stream:
    ├── cek apakah data berubah (_listequalsbyurl)
    ├── update _banners local variable
    ├── setState() untuk rebuild UI
    └── jalankan _startautowhenattached()
        ↓
    cek apakah pagecontroller ready
        ├── jika belum ready: gunakan timer check setiap 100ms
        └── jika sudah ready: jalankan _ensureautoscroll()
            ↓
            jalankan timer auto-scroll setiap 4 detik
            ├── cek: jika user touch, pause
            ├── hitung next index
            └── animate ke next index (smooth 380ms)

Saat user touch:
    ├── onPointerDown: _userinteracting = true (pause auto-scroll)
    └── onPointerUp: delay 400ms, set _userinteracting = false (resume auto-scroll)

Saat dispose:
    ├── cancel timer auto-scroll
    ├── cancel attach checker timer
    ├── unsubscribe stream
    └── dispose pagecontroller
```

## Best Practices

1. **Always Check mounted**
   ```dart
   if (!mounted) return;  // widget sudah di-dispose
   ```

2. **Cancel Resources di Dispose**
   ```dart
   @override
   void dispose() {
     _timer?.cancel();
     _sub?.cancel();
     _controller.dispose();
     super.dispose();
   }
   ```

3. **Use AutomaticKeepAliveClientMixin untuk Widget dengan Timer**
   - Ini memastikan timer tidak berhenti saat swipe ke tab lain

4. **Handle Errors Gracefully**
   ```dart
   try {
     await _controller.animateToPage(...);
   } catch (e) {
     debugPrint("Error: $e");
     // jangan throw, cukup log
   }
   ```

5. **Compare Data dengan Smart Way**
   - Jangan compare object langsung (a == b mungkin false meski isi sama)
   - Compare berdasarkan unique identifier (imageUrl dalam hal ini)

---

