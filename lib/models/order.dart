import 'models.dart';

class Order {
  final int id;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String status;
  final String paymentStatus;
  final DateTime? expiresAt;
  final DateTime? reservationExpiresAt;
  final String? checkoutUrl;
  final String? paymentTicketUrl;
  final String? paymentMethod;
  final String? fulfillmentMethod; 
  final String? deliveryAddress;
  final String? fulfillmentStatus;

  Order({
    required this.id,
    required this.createdAt,
    required List<OrderItem> items,
    required this.status,
    required this.paymentStatus,
    this.expiresAt,
    this.reservationExpiresAt,
    this.checkoutUrl,
    this.paymentTicketUrl,
    this.paymentMethod,
    this.fulfillmentMethod,
    this.deliveryAddress,
    this.fulfillmentStatus,
  }) : items = List.unmodifiable(items);

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);
}