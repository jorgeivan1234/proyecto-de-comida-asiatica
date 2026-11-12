class OrderItem {
  final String productName;
  final int quantity;
  final double unitPrice;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => unitPrice * quantity;
}
