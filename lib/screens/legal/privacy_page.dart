import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Privacy Policy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('''
GEGES SmartBarber - Privacy Policy (Draft)

We collect minimal data required for the service: account information, tenant documents, and payment proofs.
Data is stored in Firebase (Firestore & Storage) and access is restricted by role-based rules (drafted separately).

(Placeholder policy — replace with legal-reviewed content before production.)
'''),
            ],
          ),
        ),
      ),
    );
  }
}
