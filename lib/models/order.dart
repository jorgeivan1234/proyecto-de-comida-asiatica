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
  final String? paymentProvider;
  final String? refundDestination;
  final double walletAmount;

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
    this.paymentProvider,
    this.refundDestination,
    this.walletAmount = 0,
  }) : items = List.unmodifiable(items);

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  bool get canCustomerCancel {
    if (status != 'pending_payment' && status != 'paid') return false;
    if (fulfillmentStatus == 'pending') return true;
    return fulfillmentStatus == 'preparing' &&
        items.isNotEmpty &&
        items.every((item) => item.cancellationRecoverable);
  }
}
