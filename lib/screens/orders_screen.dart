import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<void> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = context.read<CartProvider>().loadOrders();
  }

  void _retryLoadingOrders() {
    setState(() {
      _ordersFuture = context.read<CartProvider>().loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppNavigationBar(),
            Expanded(
              child: Consumer<CartProvider>(
                builder: (context, cart, _) {
                  return FutureBuilder<void>(
                    future: _ordersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No se pudieron cargar tus pedidos: '
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _retryLoadingOrders,
                                  child: const Text('Volver a intentar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (cart.orders.isEmpty) {
                        return const Center(
                          child: Text('Todavía no tienes pedidos.'),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: cart.orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = cart.orders[index];

                          return Card(
                            child: ExpansionTile(
                              title: Text('Pedido #${order.id}'),
                              subtitle: Text(
                                '${order.createdAt.day}/'
                                '${order.createdAt.month}/'
                                '${order.createdAt.year} · '
                                '\$${order.total.toStringAsFixed(2)}',
                              ),
                              children: [
                                for (final item in order.items)
                                  ListTile(
                                    title: Text(item.productName),
                                    subtitle: Text(
                                      '${item.quantity} × '
                                      '\$${item.unitPrice.toStringAsFixed(2)}',
                                    ),
                                    trailing: Text(
                                      '\$${item.subtotal.toStringAsFixed(2)}',
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Estado: ${order.status} '
                                      '(pago no integrado)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
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
