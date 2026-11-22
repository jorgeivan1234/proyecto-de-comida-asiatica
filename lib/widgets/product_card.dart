import 'package:ccomcercio_electronico/models/product.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'product_cart_actions.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: InkWell(
              onTap: () => context.push('/details_product', extra: product),
              child: Image.asset(
                product.image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.image_not_supported, size: 50),
                  );
                },
              ),
            ),
          ),
          InkWell(
            onTap: () => context.push('/details_product', extra: product),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.category,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: product.stock > 0
                        ? () => addProductAndOfferNextStep(context, product)
                        : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Agregar'),
                  ),
                ),
                
                SizedBox(height: 5),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
        ],
      ),
    );
  }
}
