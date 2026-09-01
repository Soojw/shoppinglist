class CartItemModel {
  final int? id;
  final String itemName;
  final String price;
  final String storeName;
  final int quantity;

  CartItemModel({
    this.id,
    required this.itemName,
    required this.price,
    required this.storeName,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemName': itemName,
    'price': price,
    'storeName': storeName,
    'quantity': quantity,
  };
}