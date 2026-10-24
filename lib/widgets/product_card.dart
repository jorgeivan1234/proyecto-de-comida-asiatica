import 'package:ccomcercio_electronico/models/product.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 5,
      child: InkWell(
        onTap: () {
          context.push('/details_product', extra: product);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //imagen del producto
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.asset(
                product.image,
                fit: BoxFit.cover,
                //si la imagen o carga mostraremos un icono
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.image_not_supported, size: 50),
                  );
                },
              ),
            ),

            //informacion del producto
            Padding(
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

                  FilledButton.icon(
                    onPressed: () {
                      final added = context.read<CartProvider>().addProduct(
                        product,
                      );
                      final message = added
                          ? '${product.name} agregado al carrito'
                          : 'No hay más existencias de ${product.name}';
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(message)));
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Agregar al carrito'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
