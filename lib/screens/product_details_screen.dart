import 'package:flutter/material.dart';

import '../models/product.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/product_cart_actions.dart';

class ProductDetailsScreen extends StatelessWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppNavigationBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProductImage(height: 320),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: _buildProductInfo(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.brown.shade100)),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6F4E37),
                          side: const BorderSide(color: Color(0xFF6F4E37)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: product.stock > 0
                            ? () => addProductAndOfferNextStep(context, product)
                            : null,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Agregar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6F4E37),
                          foregroundColor: const Color(0xFFF3E5AB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: product.stock > 0
                            ? () => buyProductNow(context, product)
                            : null,
                        icon: const Icon(Icons.flash_on),
                        label: const Text('Comprar ahora'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage({required double height}) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            product.image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return ColoredBox(
                color: const Color(0xFFF4E8DE),
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 56,
                  color: Colors.brown.shade300,
                ),
              );
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _imageBadge(
              product.category,
              backgroundColor: const Color(0xFF6F4E37),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _imageBadge(
              product.stock > 0 ? 'Disponible' : 'Agotado',
              backgroundColor: product.stock > 0
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
              icon: product.stock > 0
                  ? Icons.check_circle_outline
                  : Icons.remove_shopping_cart_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageBadge(
    String label, {
    required Color backgroundColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.name,
          style: const TextStyle(
            color: Color(0xFF30231F),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Precio',
          style: TextStyle(
            color: Color(0xFF795548),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '\$${product.price.toStringAsFixed(2)} MXN',
          style: const TextStyle(
            color: Color(0xFF6F4E37),
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(height: 1),
        ),
        const Text(
          'Descripción',
          style: TextStyle(
            color: Color(0xFF30231F),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.description,
          style: TextStyle(
            color: Colors.brown.shade700,
            fontSize: 15,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: product.stock > 0
                ? const Color(0xFFF0F7EE)
                : const Color(0xFFFFF0EE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                product.stock > 0
                    ? Icons.inventory_2_outlined
                    : Icons.info_outline,
                color: product.stock > 0
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  product.stock > 0
                      ? '${product.stock} disponibles'
                      : 'Producto agotado',
                  style: TextStyle(
                    color: product.stock > 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
