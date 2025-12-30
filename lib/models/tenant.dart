class Tenant {
  final String id;
  final String businessName;
  final String documentBase64;
  final String packageId;
  final String? status;

  Tenant({required this.id, required this.businessName, required this.documentBase64, required this.packageId, this.status});

  factory Tenant.fromMap(String id, Map<String, dynamic> data) => Tenant(
        id: id,
        businessName: data['business_name'] as String? ?? '',
        documentBase64: data['document_base64'] as String? ?? '',
        packageId: data['package_id'] as String? ?? '',
        status: data['status'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'business_name': businessName,
        'document_base64': documentBase64,
        'package_id': packageId,
        'status': status,
      };
}

class Invoice {
  final String id;
  final String tenantId;
  final DateTime deadline;
  final int? amount;
  String? status;
  bool paid;

  Invoice({required this.id, required this.tenantId, required this.deadline, this.amount, this.status, this.paid = false});

  factory Invoice.fromMap(String id, Map<String, dynamic> data) => Invoice(
        id: id,
        tenantId: data['tenant_id'] as String? ?? '',
        deadline: (data['payment_deadline'] as DateTime?) ?? DateTime.now(),
        amount: data['amount'] as int?,
        status: data['status'] as String?,
        paid: data['paid'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'payment_deadline': deadline.toIso8601String(),
        'amount': amount,
        'status': status,
        'paid': paid,
      };
}
