import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';

enum _CartNextStep { keepShopping, viewCart, checkout }

Future<void> addProductAndOfferNextStep(
  BuildContext context,
  Product product,
) async {
  if (!_addProduct(context, product)) return;

  final nextStep = await showDialog<_CartNextStep>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Agregado al carrito'),
      content: const Text('¿Qué quieres hacer ahora?'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, _CartNextStep.keepShopping),
          child: const Text('Seguir comprando'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, _CartNextStep.viewCart),
          child: const Text('Ver carrito'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, _CartNextStep.checkout),
          child: const Text('Comprar ahora'),
        ),
      ],
    ),
  );

  if (!context.mounted) return;

  switch (nextStep) {
    case _CartNextStep.viewCart:
      context.push('/cart');
    case _CartNextStep.checkout:
      context.push('/checkout');
    case _CartNextStep.keepShopping:
    case null:
      break;
  }
}

void buyProductNow(BuildContext context, Product product) {
  if (!_addProduct(context, product)) return;
  context.push('/checkout');
}

bool _addProduct(BuildContext context, Product product) {
  final added = context.read<CartProvider>().addProduct(product);
  if (!added) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('No hay más existencias de ${product.name}')),
      );
  }
  return added;
}
