class StorePrice {
  final String storeName;
  final String price;
  final String state;
  final String date;

  StorePrice({
    required this.storeName,
    required this.price,
    required this.state,
    required this.date,
  });
}

class PriceDropItem {
  final String itemCode;
  final String barcode;
  final String category;
  final String title;
  String oldPrice;
  String newPrice;
  final String details;
  final String imageUrl;
  final String store;
  final bool isLocal;
  final List<StorePrice> storePrices;

  PriceDropItem({
    required this.itemCode,
    required this.barcode,
    required this.category,
    required this.title,
    required this.oldPrice,
    required this.newPrice,
    required this.details,
    required this.imageUrl,
    this.store = 'Nationwide',
    this.isLocal = false,
    List<StorePrice>? storePrices,
  }) : storePrices = storePrices ?? [];

  factory PriceDropItem.fromJson(Map<String, dynamic> json) {
    String parsedOldPrice = '';
    if (json['old_price'] != null && json['old_price'].toString().isNotEmpty) {
      parsedOldPrice = 'RM ${(json['old_price'] as num).toStringAsFixed(2)}';
    }

    return PriceDropItem(
      itemCode: json['item_code']?.toString() ?? 'N/A',
      barcode: json['barcode']?.toString() ?? 'N/A',
      category: json['category'] ?? 'UNKNOWN',
      title: json['item_name'] ?? 'Unknown Item',
      oldPrice: parsedOldPrice,
      newPrice: 'RM ${(json['price'] as num).toStringAsFixed(2)}',
      details: json['details'] ?? 'Nationwide standardized price.',
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800',
    );
  }
}