import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

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
                                title: Text(item.product.name),
                                subtitle: Text(
                                  '${item.quantity} × '
                                  '\$${item.unitPrice.toStringAsFixed(2)}',
                                ),
                                trailing: Text(
                                  '\$${item.subtotal.toStringAsFixed(2)}',
                                ),
                              ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Estado: registrado (demostración)',
                                ),
                              ),
                            ),
                          ],
                        ),
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
