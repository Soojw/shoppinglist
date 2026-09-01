import 'package:flutter/material.dart';


class BasketItem {
  final String id;
  final String name;
  final String size;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Map<String, double> prices;

  BasketItem({
    required this.id, required this.name, required this.size, required this.icon,
    required this.bgColor, required this.iconColor, required this.prices,
  });
}

final List<BasketItem> databaseProducts = [
  BasketItem(id: 'p1', name: 'Farm Fresh Milk', size: '2 Litres', icon: Icons.water_drop_outlined, bgColor: const Color(0xFFD1FAE5), iconColor: const Color(0xFF059669), prices: {"Lotus's": 15.50, "AEON": 16.20, "Jaya Grocer": 16.50, "FreshMart": 15.80}),
  BasketItem(id: 'p2', name: 'Grade A Eggs', size: '30 pack', icon: Icons.egg_alt_outlined, bgColor: const Color(0xFFFEF3C7), iconColor: const Color(0xFFD97706), prices: {"Lotus's": 12.90, "AEON": 13.50, "Jaya Grocer": 14.10, "FreshMart": 13.20}),
  BasketItem(id: 'p3', name: 'Wholemeal Bread', size: '400g', icon: Icons.bakery_dining_outlined, bgColor: const Color(0xFFE0E7FF), iconColor: const Color(0xFF4338CA), prices: {"Lotus's": 3.80, "AEON": 3.80, "Jaya Grocer": 4.20, "FreshMart": 4.00}),
];



class CartItem {
  final BasketItem product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}



class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();


  void addItem(BasketItem item) {
    if (_items.containsKey(item.id)) {
      _items[item.id]!.quantity += 1;
    } else {
      _items[item.id] = CartItem(product: item);
    }
    notifyListeners();
  }


  void decreaseItem(String productId) {
    if (!_items.containsKey(productId)) return;

    if (_items[productId]!.quantity > 1) {
      _items[productId]!.quantity -= 1;
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }



  Map<String, dynamic>? getOptimizationResult() {
    if (_items.isEmpty) return null;

    Map<String, double> storeTotals = {
      "Lotus's": 0.0, "AEON": 0.0, "Jaya Grocer": 0.0, "FreshMart": 0.0,
    };

    _items.forEach((id, cartItem) {
      storeTotals.forEach((store, total) {
        storeTotals[store] = total + ((cartItem.product.prices[store] ?? 999.0) * cartItem.quantity);
      });
    });

    String winnerStore = "";
    double lowestTotal = 99999.0;
    double highestTotal = 0.0;

    storeTotals.forEach((store, total) {
      if (total < lowestTotal) {
        lowestTotal = total;
        winnerStore = store;
      }
      if (total > highestTotal) {
        highestTotal = total;
      }
    });

    return {
      "winner": winnerStore,
      "lowestTotal": lowestTotal,
      "savings": highestTotal - lowestTotal,
    };
  }
}