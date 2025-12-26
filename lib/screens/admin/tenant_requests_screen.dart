import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

class TenantRequestsScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final TenantService? tenantService;

  const TenantRequestsScreen({super.key, this.firestore, this.tenantService});

  @override
  State<TenantRequestsScreen> createState() => _TenantRequestsScreenState();
}

class _TenantRequestsScreenState extends State<TenantRequestsScreen> {
  late final FirebaseFirestore _fs;
  late final TenantService _tenantService;

  @override
  void initState() {
    super.initState();
    _fs = widget.firestore ?? FirebaseFirestore.instance;
    _tenantService = widget.tenantService ?? TenantService();
  }

  Future<void> _approve(String tenantId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'admin_unknown';
    await _tenantService.verifyTenant(tenantId: tenantId, approve: true, verifiedBy: userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenant approved')));
  }

  Future<void> _reject(String tenantId) async {
    final reasonCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Tenant'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reject')),
        ],
      ),
    );

    if (res != true) return;

    await _tenantService.verifyTenant(tenantId: tenantId, approve: false, verifiedBy: FirebaseAuth.instance.currentUser?.uid, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenant rejected')));
  }

  Widget _buildTenantTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tenantId = doc.id;
    final businessName = data['business_name'] ?? '(no name)';
    final owner = data['owner_email'] ?? data['owner_name'] ?? 'owner';
    final status = data['status'] ?? 'unknown';
    final invoice = data['invoice'] ?? {};
    final invoiceStatus = invoice['status'] ?? 'none';
    final docs = (data['company_doc_url'] != null || data['tax_doc_url'] != null);

    return Card(
      child: ListTile(
        title: Text('$businessName'),
        subtitle: Text('Owner: $owner\nStatus: $status   Invoice: $invoiceStatus'),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_red_eye),
              onPressed: () {
                // show details
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Tenant: $businessName'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Owner: $owner'),
                        const SizedBox(height: 8),
                        Text('Docs uploaded: ${docs ? 'Yes' : 'No'}'),
                        const SizedBox(height: 8),
                        if (data['company_doc_url'] != null) TextButton.icon(
                          icon: const Icon(Icons.insert_drive_file),
                          label: const Text('View Company Doc'),
                          onPressed: () => _openUrl(data['company_doc_url']),
                        ),
                        if (data['tax_doc_url'] != null) TextButton.icon(
                          icon: const Icon(Icons.insert_drive_file),
                          label: const Text('View Tax Doc'),
                          onPressed: () => _openUrl(data['tax_doc_url']),
                        ),
                        if (invoice['status'] == 'payment_submitted' && invoice['payment_proof_url'] == null)
                          Text('Payment submitted: yes (check tenant docs)'),
                        if (invoice['status'] == 'payment_submitted' && invoice['payment_proof_url'] != null)
                          TextButton.icon(
                            icon: const Icon(Icons.image),
                            label: const Text('View Payment Proof'),
                            onPressed: () => _openUrl(invoice['payment_proof_url']),
                          ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _approve(tenantId),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _reject(tenantId),
            ),
          ],
        ),
      ),
    );
  }

  void _openUrl(String? url) {
    if (url == null) return;
    // For now, just launch externally
    // Links.openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.collection('tenants').where('status', whereNotIn: ['active', 'rejected']).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Error loading tenants'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No pending tenant requests'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) => _buildTenantTile(docs[i]),
          );
        },
      ),
    );
  }
}
