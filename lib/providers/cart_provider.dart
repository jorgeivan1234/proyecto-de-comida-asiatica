import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};
  final List<Order> _orders = [];
  bool _checkoutInProgress = false;

  List<CartItem> get items => List.unmodifiable(_items.values);
  List<Order> get orders => List.unmodifiable(_orders);

  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);

  double get total => _items.values.fold(0, (sum, item) => sum + item.subtotal);

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

  Future<Order?> checkout() async {
    if (_items.isEmpty) return null;

    if (_checkoutInProgress) {
      throw StateError('Ya se esta procesando este pedido.');
    }

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Inicia sesion antes de confirmar la compra.');
    }

    _checkoutInProgress = true;
    final itemsToOrders = List<CartItem>.of(_items.values);

    try {
      final response = await client.rpc(
        'place_order',
        params: {
          'p_items': itemsToOrders
              .map(
                (item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                },
              )
              .toList(),
        },
      );

      if (response is! Map) {
        throw const FormatException('Respuesta invalida al crear el pedido.');
      }

      final orderData = Map<String, dynamic>.from(response);
      final responseItems = orderData['items'];
      if (responseItems is! List) {
        throw const FormatException(
          'La respuesta del pedido no contiene sus productos.',
        );
      }

      final orderItems = responseItems.map((rawItem) {
        final itemData = Map<String, dynamic>.from(rawItem as Map);
        return OrderItem(
          productName: itemData['product_name'] as String,
          quantity: itemData['quantity'] as int,
          unitPrice: (itemData['unit_price'] as num).toDouble(),
        );
      }).toList();

      final order = Order(
        id: orderData['id'] as int,
        createdAt: DateTime.parse(orderData['created_at'] as String),
        status: orderData['status'] as String,
        paymentStatus: orderData['payment_status'] as String,
        items: orderItems,
        expiresAt: DateTime.parse(orderData['expires_at'] as String),
        reservationExpiresAt: DateTime.parse(
          orderData['reservation_expires_at'] as String,
        ),
      );

      _orders.insert(0, order);
      _items.clear();
      notifyListeners();
      return order;
    } finally {
      _checkoutInProgress = false;
    }
  }

  Future<Uri> createPaymentCheckout(int orderId) async {
    final response = await Supabase.instance.client.functions.invoke(
      'create-payment-checkout',
      body: {'order_id': orderId},
    );

    if (response.data is! Map) {
      throw const FormatException('Respuesta inválida al abrir el pago.');
    }

    final responseData = Map<String, dynamic>.from(response.data as Map);
    final checkoutUrl = responseData['checkout_url'];
    if (checkoutUrl is! String) {
      throw const FormatException('El servidor no devolvió el enlace de pago.');
    }

    final uri = Uri.tryParse(checkoutUrl);
    const allowedHosts = ['mercadopago.com', 'mercadopago.com.mx'];
    if (uri == null ||
        uri.scheme != 'https' ||
        !allowedHosts.any(
          (host) => uri.host == host || uri.host.endsWith('.$host'),
        )) {
      throw const FormatException('El enlace de pago no es válido.');
    }

    return uri;
  }

  Future<void> loadOrders() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Inicia sesion para consultar tus pedidos.');
    }

    await client.rpc('expire_my_pending_orders');

    final rows = await client
        .from('orders')
        .select(
          'id, created_at, status, payment_status, expires_at, '
          'reservation_expires_at, checkout_url, '
          'payment_ticket_url, payment_method, '
          'order_items(product_name, quantity, unit_price)',
        )
        .order('created_at', ascending: false);

    final loadedOrders = rows.map((row) {
      final expiresAt = row['expires_at'] as String?;
      final reservationExpiresAt = row['reservation_expires_at'] as String?;
      final orderItems = (row['order_items'] as List).map((rawItem) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        return OrderItem(
          productName: item['product_name'] as String,
          quantity: item['quantity'] as int,
          unitPrice: (item['unit_price'] as num).toDouble(),
        );
      }).toList();

      return Order(
        id: row['id'] as int,
        createdAt: DateTime.parse(row['created_at'] as String),
        items: orderItems,
        status: row['status'] as String,
        paymentStatus: row['payment_status'] as String,
        expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt),
        reservationExpiresAt: reservationExpiresAt == null
            ? null
            : DateTime.parse(reservationExpiresAt),
        checkoutUrl: row['checkout_url'] as String?,
        paymentTicketUrl: row['payment_ticket_url'] as String?,
        paymentMethod: row['payment_method'] as String?,
      );
    }).toList();

    _orders
      ..clear()
      ..addAll(loadedOrders);
    notifyListeners();
  }
}
