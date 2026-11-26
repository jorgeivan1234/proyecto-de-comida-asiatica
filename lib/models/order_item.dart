class OrderItem {
  final String productName;
  final int quantity;
  final double unitPrice;
  final bool cancellationRecoverable;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.cancellationRecoverable = false,
  });

  double get subtotal => unitPrice * quantity;
}
