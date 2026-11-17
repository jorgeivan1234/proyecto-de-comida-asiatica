import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/cart_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isSubmitting = false;
  String _fulfillmentMethod = 'pickup';
  final _deliveryAddressController = TextEditingController();
  
  @override
  void dispose (){
    _deliveryAddressController.dispose();
    super.dispose();
  }

  // Pide confirmación antes de convertir el contenido del carrito en un pedido.
  Future<void> _confirmPurchase(BuildContext context, CartProvider cart) async {
    if (_isSubmitting) return;

    if (_fulfillmentMethod == 'delivery' &&
        _deliveryAddressController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escribe la direccion de entrega.')),
          );
          return;
        }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar compra'),
        content: Text(
          '¿Deseas confirmar el pedido por '
          '\$${cart.total.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir comprando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final order = await cart.checkout();
      if (order == null || !context.mounted) return;

      await Supabase.instance.client.rpc(
        'set_my_pending_order_fulfillment',
        params: {
          'p_order_id': order.id,
          'p_method': _fulfillmentMethod,
          'p_delivery address': _fulfillmentMethod == 'delivery'
              ? _deliveryAddressController.text.trim()
              : null,
        },
      );

      final checkoutUrl = await cart.createPaymentCheckout(order.id);
      final opened = await launchUrl(
        checkoutUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw StateError(
          'No se pudo abrir el checkout. Puedes reintentarlo desde Mis pedidos.',
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Se abrió el checkout seguro. El stock físico no se descontó; '
              'el pago se confirmará cuando Mercado Pago notifique el resultado.',
            ),
          ),
        );
    } on PostgrestException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar la compra: ${error.message}'),
        ),
      );
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Respuesta inválida del servidor: ${error.message}'),
        ),
      );
    } on FunctionException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir el pago: ${error.details ?? error.reasonPhrase ?? error.status}',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el pago: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[200],
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppNavigationBar(),
            Expanded(
              child: Consumer<CartProvider>(
                builder: (context, cart, _) {
                  if (cart.items.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Tu carrito está vacío',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Explora nuestros productos y agrega tus '
                              'favoritos para verlos aquí.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => context.go('/home'),
                              icon: const Icon(Icons.storefront_outlined),
                              label: const Text('Explorar productos'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: cart.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = cart.items[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        item.product.image,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '\$${item.product.price.toStringAsFixed(2)} c/u',
                                          ),
                                          Text(
                                            'Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Quitar uno',
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => cart.decreaseQuantity(
                                              item.product.id,
                                            ),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text('${item.quantity}'),
                                    IconButton(
                                      tooltip: 'Agregar uno',
                                      onPressed: _isSubmitting
                                          ? null
                                          : () {
                                              final added = cart.addProduct(
                                                item.product,
                                              );
                                              if (!added) {
                                                ScaffoldMessenger.of(context)
                                                  ..hideCurrentSnackBar()
                                                  ..showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'No hay más existencias de '
                                                        '${item.product.name}',
                                                      ),
                                                    ),
                                                  );
                                              }
                                            },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Align(
                                alignment: Alignment.center,
                                child: Text(
                                  '¿Como quieres recibir tu pedido?',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              RadioListTile<String>(
                                title: const Text('Recoger en el local'),
                                value: 'pickup',
                                groupValue: _fulfillmentMethod,
                                onChanged: _isSubmitting
                                    ? null
                                    : (String? value) {
                                        if (value != null) {
                                          setState(
                                            () => _fulfillmentMethod = value,
                                          );
                                        }
                                      },
                              ),
                              RadioListTile<String>(
                                title: const Text('Entregar a domicilio'),
                                value: 'delivery',
                                groupValue: _fulfillmentMethod,
                                onChanged: _isSubmitting
                                    ? null
                                    : (String? value) {
                                        if (value != null) {
                                          setState(
                                            () => _fulfillmentMethod = value,
                                          );
                                        }
                                      },
                              ),

                              if (_fulfillmentMethod == 'delivery')
                                TextField(
                                  controller: _deliveryAddressController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Direccion de entrega',
                                    hintText: 'Calle, numero, colonia, codigo postal y referencias',
                                  border: OutlineInputBorder(),
                                  ),
                                ),
                              Text(
                                'Total: \$${cart.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : cart.clear,
                                    child: const Text('Vaciar carrito'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _confirmPurchase(context, cart),
                                    icon: _isSubmitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.shopping_bag),
                                    label: Text(
                                      _isSubmitting
                                          ? 'Registrando...'
                                          : 'Confirmar pedido',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
