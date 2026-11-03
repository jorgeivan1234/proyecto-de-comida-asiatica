import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};
  final List<Order> _orders = [];
  int _nextOrderId = 1;

  List<CartItem> get items => List.unmodifiable(_items.values);
  List<Order> get orders => List.unmodifiable(_orders);

  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);

  double get total => _items.values.fold(
    0,
    (sum, item) => sum + item.product.price * item.quantity,
  );

  bool addProduct(Product product) {
    final currentItem = _items[product.id];
    if (product.stock <= 0 ||
        (currentItem != null && currentItem.quantity >= product.stock)) {
      return false;
    }

    _items[product.id] = currentItem == null
        ? CartItem(product: product, quantity: 1)
        : currentItem.copyWith(quantity: currentItem.quantity + 1);
    notifyListeners();
    return true;
  }

  void decreaseQuantity(int productId) {
    final item = _items[productId];
    if (item == null) return;

    if (item.quantity == 1) {
      _items.remove(productId);
    } else {
      _items[productId] = item.copyWith(quantity: item.quantity - 1);
    }
    notifyListeners();
  }

  void removeProduct(int productId) {
    if (_items.remove(productId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  // Esta compra de demostración registra el pedido localmente; no procesa pagos.
  Order? checkout() {
    if (_items.isEmpty) return null;

    final order = Order(
      id: _nextOrderId++,
      createdAt: DateTime.now(),
      items: _items.values
          .map(
            (item) => OrderItem(
              product: item.product,
              quantity: item.quantity,
              unitPrice: item.product.price,
            ),
          )
          .toList(),
    );

    // Guardamos el pedido antes de vaciar el carrito para conservar su contenido.
    _orders.insert(0, order);
    _items.clear();
    notifyListeners();
    return order;
  }
}
