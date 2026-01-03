import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutTab extends StatelessWidget {
  final Barbershop shop;

  const AboutTab({super.key, required this.shop});

  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    
    // Pastikan URL memiliki prefix protocol
    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http') && !finalUrl.startsWith('https') && !finalUrl.startsWith('whatsapp')) {
      finalUrl = 'https://$finalUrl';
    }

    final uri = Uri.parse(finalUrl);
    try {
      // Pada Android modern, terkadang launchUrl langsung lebih stabil
      // Mode externalApplication akan memaksa keluar dari WebView internal
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        debugPrint('Could not launch $finalUrl via external app, trying non-browser...');
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching URL ($finalUrl): $e');
      // Fallback terakhir: coba buka di browser default jika gagal total
      try {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Location
          const Text(
            'Location',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _launchUrl(shop.googleMapsUrl),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: kBrownAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.addres,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        if (shop.googleMapsUrl != null && shop.googleMapsUrl!.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Tap to view on Google Maps',
                              style: TextStyle(color: kBrownAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 32),

          // 2. Working Hours
          const Text(
            'Working Hours',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time_outlined, color: kBrownAccent, size: 28),
            title: Text(
              'Mon - Sun (${shop.openHour}:00 - ${shop.closeHour}:00)',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const Divider(color: Colors.white12, height: 32),

          // 3. Facilities
          const Text(
            'Facilities',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (shop.facilities.isEmpty)
            const Text('No facilities listed.', style: TextStyle(color: Colors.white54, fontSize: 14))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: shop.facilities.map((f) => _buildFacilityBadge(f)).toList(),
            ),
          const Divider(color: Colors.white12, height: 40),

          // 4. Social Media
          const Text(
            'Social Media',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSocialGrid(),
          const SizedBox(height: 24), // Reduced from 40
        ],
      ),
    );
  }

  Widget _buildSocialGrid() {
    final List<Widget> items = [];
    
    if (shop.instagramUrl?.isNotEmpty ?? false) {
      items.add(_buildSocialIcon(Icons.camera_alt_outlined, 'Instagram', () => _launchUrl(shop.instagramUrl)));
    }
    if (shop.whatsappNumber?.isNotEmpty ?? false) {
      items.add(_buildSocialIcon(Icons.chat_outlined, 'WhatsApp', () => _launchUrl('https://wa.me/${shop.whatsappNumber}')));
    }
    if (shop.tiktokUrl?.isNotEmpty ?? false) {
      items.add(_buildSocialIcon(Icons.music_note_outlined, 'TikTok', () => _launchUrl(shop.tiktokUrl)));
    }
    if (shop.facebookUrl?.isNotEmpty ?? false) {
      items.add(_buildSocialIcon(Icons.facebook_outlined, 'Facebook', () => _launchUrl(shop.facebookUrl)));
    }
    if (shop.twitterUrl?.isNotEmpty ?? false) {
      items.add(_buildSocialIcon(Icons.close, 'Twitter/X', () => _launchUrl(shop.twitterUrl)));
    }

    if (items.isEmpty) {
      return const Text('No social media available.', style: TextStyle(color: Colors.white54, fontSize: 14));
    }

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: items,
    );
  }

  Widget _buildFacilityBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBrownAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: kBrownAccent, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kDarkGrey,
                shape: BoxShape.circle,
                border: Border.all(color: kBrownAccent.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: kBrownAccent, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label, 
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}