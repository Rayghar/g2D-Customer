// File: lib/models/admin/admin_order_item_data.dart

class AdminOrderItemData {
  final String productId;
  final String name;
  final int quantity;
  final double pricePerUnit;
  final double itemTotal;
  final String? imageUrl; // Optional image URL for the product

  AdminOrderItemData({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.pricePerUnit,
    required this.itemTotal,
    this.imageUrl,
  });

  factory AdminOrderItemData.fromJson(Map<String, dynamic> json) {
    return AdminOrderItemData(
      productId: json['productId'] as String? ?? 'unknown_product',
      name: json['name'] as String? ?? 'Unknown Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      pricePerUnit: (json['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
      itemTotal: (json['itemTotal'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'itemTotal': itemTotal,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }
}
