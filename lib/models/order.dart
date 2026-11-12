import 'order_item.dart';

class Order {
  final int id;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String status;

  Order({
    required this.id,
    required this.createdAt,
    required List<OrderItem> items,
    required this.status,
  }) : items = List.unmodifiable(items);

  // El total se calcula con los precios guardados al confirmar la compra.
  double get total => items.fold(0, (sum, item) => sum + item.subtotal);
}
