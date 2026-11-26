import 'package:ccomcercio_electronico/models/order.dart';
import 'package:ccomcercio_electronico/models/order_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Order order({
    String status = 'paid',
    String fulfillmentStatus = 'pending',
    List<OrderItem>? items,
  }) {
    return Order(
      id: 1,
      createdAt: DateTime(2026),
      items:
          items ??
          const [
            OrderItem(
              productName: 'Onigiri',
              quantity: 1,
              unitPrice: 40,
              cancellationRecoverable: true,
            ),
          ],
      status: status,
      paymentStatus: 'approved',
      fulfillmentStatus: fulfillmentStatus,
    );
  }

  test('can cancel while waiting for preparation', () {
    expect(order().canCustomerCancel, isTrue);
  });

  test('can cancel during preparation only when every item is recoverable', () {
    expect(order(fulfillmentStatus: 'preparing').canCustomerCancel, isTrue);
    expect(
      order(
        fulfillmentStatus: 'preparing',
        items: const [
          OrderItem(
            productName: 'Onigiri',
            quantity: 1,
            unitPrice: 40,
            cancellationRecoverable: true,
          ),
          OrderItem(productName: 'Ramen', quantity: 1, unitPrice: 120),
        ],
      ).canCustomerCancel,
      isFalse,
    );
  });

  test('cannot cancel once ready, shipped, or already cancelled', () {
    expect(
      order(fulfillmentStatus: 'ready_for_pickup').canCustomerCancel,
      isFalse,
    );
    expect(order(fulfillmentStatus: 'shipped').canCustomerCancel, isFalse);
    expect(
      order(
        status: 'cancelled',
        fulfillmentStatus: 'cancelled',
      ).canCustomerCancel,
      isFalse,
    );
  });
}
