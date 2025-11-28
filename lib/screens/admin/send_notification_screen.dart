import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _queueIdCtrl = TextEditingController();
  bool _submitting = false;
  bool _isBroadcast = false;
  final FocusNode _userFocus = FocusNode();
  Timer? _debounce;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _searchResults = [];
  String? _selectedUserName;
  bool _alsoPush = false;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final userId = _userIdCtrl.text.trim();
      final title = _titleCtrl.text.trim();
      final body = _bodyCtrl.text.trim();
      final queueId = _queueIdCtrl.text.trim().isEmpty ? null : _queueIdCtrl.text.trim();

      final payload = {
        'title': title,
        'body': body,
        'created_at': FieldValue.serverTimestamp(),
        'read': false,
        'delivered': false,
      };
      if (queueId != null) payload['queue_id'] = queueId;

      if (_isBroadcast) {
        await FirebaseFirestore.instance.collection('notifications').add({...payload, 'broadcast': true});
      } else {
        // require user id if not broadcast
        if (userId.isEmpty) throw Exception('User ID kosong untuk notifikasi personal');
        await FirebaseFirestore.instance.collection('notifications').add({...payload, 'user_id': userId, 'broadcast': false});
      }

      // Optionally create a push_requests doc for server-side processing
      if (_alsoPush) {
        final pr = {
          'title': title,
          'body': body,
          'created_at': FieldValue.serverTimestamp(),
          'processed': false,
          'broadcast': _isBroadcast,
        };
        if (!_isBroadcast) pr['user_id'] = userId;
        if (queueId != null) pr['queue_id'] = queueId;
        await FirebaseFirestore.instance.collection('push_requests').add(pr);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifikasi dibuat')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat notifikasi: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _queueIdCtrl.dispose();
    _userFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim Notifikasi')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _userIdCtrl,
                focusNode: _userFocus,
                decoration: const InputDecoration(labelText: 'User ID atau cari nama (kosong = broadcast)'),
                onChanged: (v) {
                  // clear selected display name when typing
                  setState(() { _selectedUserName = null; });
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    _doUserSearch(v.trim());
                  });
                },
              ),
              if (_searchResults.isNotEmpty && !_isBroadcast)
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  margin: const EdgeInsets.only(top: 8.0),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6), color: Colors.white),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final d = _searchResults[i].data();
                      final name = (d['name'] as String?) ?? 'User';
                      final email = (d['email'] as String?) ?? '';
                      return ListTile(
                        title: Text(name),
                        subtitle: email.isNotEmpty ? Text(email) : null,
                        onTap: () {
                          final id = _searchResults[i].id;
                          _userIdCtrl.text = id;
                          setState(() {
                            _selectedUserName = name;
                            _searchResults = [];
                          });
                          // unfocus after selection
                          _userFocus.unfocus();
                        },
                      );
                    },
                  ),
                ),
              if (_selectedUserName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Terpilih: $_selectedUserName', style: const TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Judul'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(labelText: 'Isi'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Isi notifikasi wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _queueIdCtrl,
                decoration: const InputDecoration(labelText: 'Queue ID (opsional)'),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _isBroadcast,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _isBroadcast = v;
                    if (v) _userIdCtrl.clear();
                  });
                },
                title: const Text('Broadcast ke semua pengguna'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _alsoPush,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _alsoPush = v);
                },
                title: const Text('Kirim push melalui server (jika tersedia)'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_isBroadcast)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('Notifikasi akan dikirim ke semua pengguna terdaftar (broadcast).', style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _send,
                child: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kirim'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doUserSearch(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(10)
          .get();
      setState(() => _searchResults = qs.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>());
    } catch (e) {
      // ignore search errors for now
      setState(() => _searchResults = []);
    }
  }
}
