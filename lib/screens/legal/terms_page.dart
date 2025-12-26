import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Terms of Service', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('''
GEGES SmartBarber - Terms of Service (Draft)

1. Service Description
GEGES provides a platform for barbershops to manage bookings, staff, and customer interactions.

2. Tenant Agreement
By registering as a tenant, you agree to pay registration fees and abide by our service policies.

3. Payment & Refund
Registration fees are processed manually in MVP; refunds handled at admin discretion.

4. Content & Responsibility
Tenants are responsible for their content, pricing, working hours, and legal compliance.

(Placeholder terms — replace with legal-reviewed content before production.)
'''),
            ],
          ),
        ),
      ),
    );
  }
}
