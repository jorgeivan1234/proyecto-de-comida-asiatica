import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
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
  int? _openingPaymentFor;

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

  Future<void> _openPayment(CartProvider cart, Order order) async {
    setState(() => _openingPaymentFor = order.id);
    try {
      final checkoutUrl = order.checkoutUrl == null
          ? await cart.createPaymentCheckout(order.id)
          : Uri.parse(order.checkoutUrl!);
      final opened = await launchUrl(
        checkoutUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw StateError('No se pudo abrir el enlace de pago.');
      }
      await cart.loadOrders();
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on FunctionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir el pago: '
            '${error.details ?? error.reasonPhrase ?? error.status}',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el pago: $error')),
      );
    } finally {
      if (mounted) setState(() => _openingPaymentFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppNavigationBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis pedidos',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text('Consulta el historial y rastrea tus entregas en tiempo real.'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar pedidos',
                    onPressed: _retryLoadingOrders,
                    icon: const Icon(Icons.refresh, color: Colors.deepOrange),
                  ),
                ],
              ),
            ),
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
                                  'No se pudieron cargar tus pedidos: ${snapshot.error}',
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('Todavía no tienes pedidos realizados.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => context.go('/home'),
                                child: const Text('Ir al Catálogo'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: cart.orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = cart.orders[index];

                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            clipBehavior: Clip.antiAlias,
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              title: Text(
                                'Pedido #${order.id}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} · \$${order.total.toStringAsFixed(2)} MXN',
                              ),
                              trailing: Chip(
                                label: Text(
                                  _statusLabel(order.status, order.expiresAt, isCashPayment: order.paymentMethod == 'cash'),
                                  style: const TextStyle(fontSize: 12, color: Colors.white),
                                ),
                                backgroundColor: order.status == 'paid' || order.status == 'confirmed' ? Colors.green : Colors.deepOrange,
                              ),
                              children: [
                                const Divider(),
                                for (final item in order.items)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(item.productName),
                                    subtitle: Text('${item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}'),
                                    trailing: Text('\$${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                const Divider(height: 24),
                                
                                // Mostrar botón de rastreo GPS solo si es a domicilio
                                if (order.fulfillmentMethod == 'delivery') ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.deepOrange,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => context.push('/order-tracking/${order.id}'),
                                      icon: const Icon(Icons.location_on),
                                      label: const Text('Ver Seguimiento y Repartidor en Vivo'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Pago: ${_paymentStatusLabel(order.paymentStatus)}'),
                                      if (order.paymentMethod != null)
                                        Text('Método: ${_paymentMethodLabel(order.paymentMethod!, order.fulfillmentMethod)}'),
                                      if (order.fulfillmentMethod != null)
                                        Text('Entrega: ${_fulfillmentMethodLabel(order.fulfillmentMethod!)}'),
                                      if (order.fulfillmentMethod == 'delivery' && order.deliveryAddress != null)
                                        Text('Dirección: ${order.deliveryAddress}'),
                                      if (order.fulfillmentStatus != null)
                                        Text('Estado de envío: ${_fulfillmentStatusLabel(order.fulfillmentStatus!)}', 
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                    ],
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

  String _statusLabel(String status, DateTime? paymentExpiresAt, {bool isCashPayment = false}) {
    switch (status) {
      case 'pending_payment': return 'Pendiente';
      case 'paid': return 'Pagado';
      case 'rejected': return 'Rechazado';
      case 'cancelled': return 'Cancelado';
      case 'confirmed': return 'Confirmado';
      default: return status;
    }
  }

  String _paymentMethodLabel(String method, String? fulfillmentMethod) {
    switch (method.toLowerCase()) {
      case 'cash': return fulfillmentMethod == 'delivery' ? 'Efectivo al repartidor' : 'Efectivo en caja';
      case 'online': return 'Mercado Pago';
      default: return method;
    }
  }

  String _fulfillmentMethodLabel(String method) {
    return method == 'pickup' ? 'Recoger en local' : 'A domicilio (Gratis)';
  }

  String _fulfillmentStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pendiente de preparar';
      case 'preparing': return 'En preparación en cocina';
      case 'shipped': return 'En camino con repartidor';
      case 'delivered': return 'Entregado en domicilio';
      case 'ready_for_pickup': return 'Listo para recoger en mostrador';
      case 'picked_up': return 'Recogido';
      default: return status;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'approved': return 'Aprobado';
      case 'pending': return 'Pendiente';
      case 'rejected': return 'Rechazado';
      default: return status;
    }
  }
}