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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mis pedidos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar estado de pago',
                    onPressed: _retryLoadingOrders,
                    icon: const Icon(Icons.refresh),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pedido: ${_statusLabel(order.status, order.expiresAt, isCashPayment: order.paymentMethod == 'cash')}',
                                        ),
                                        Text(
                                          'Pago: ${_paymentStatusLabel(order.paymentStatus)}',
                                        ),
                                        if (order.paymentMethod != null)
                                          Text(
                                            'Método: '
                                            '${_paymentMethodLabel(order.paymentMethod!, order.fulfillmentMethod)}',
                                          ),
                                        if (order.fulfillmentMethod != null)
                                          Text(
                                            'Entrega: '
                                            '${_fulfillmentMethodLabel(order.fulfillmentMethod!)}',
                                          ),
                                        if (order.fulfillmentMethod ==
                                                'delivery' &&
                                            order.deliveryAddress != null)
                                          Text(
                                            'Dirección: ${order.deliveryAddress}',
                                          ),
                                        if (order.fulfillmentStatus != null)
                                          Text(
                                            'Estado de entrega: '
                                            '${_fulfillmentStatusLabel(order.fulfillmentStatus!)}',
                                          ),
                                        if (order.status == 'paid')
                                          Text(
                                            order.paymentMethod == 'cash'
                                                ? 'Pago en efectivo recibido para el pedido #${order.id}.'
                                                : 'Pago del pedido #${order.id} confirmado por Mercado Pago.',
                                          ),
                                        if (order.status == 'pending_payment' &&
                                            order.expiresAt != null)
                                          Text(
                                            'Paga antes de: '
                                            '${order.expiresAt!.toLocal().toString().substring(0, 16)}',
                                          ),
                                        if (order.status == 'pending_payment' &&
                                            order.reservationExpiresAt != null)
                                          Text(
                                            'Existencias apartadas hasta: '
                                            '${order.reservationExpiresAt!.toLocal().toString().substring(0, 16)}',
                                          ),
                                        if (order.paymentTicketUrl != null)
                                          TextButton.icon(
                                            onPressed: () => _openPaymentTicket(
                                              order.paymentTicketUrl!,
                                            ),
                                            icon: const Icon(
                                              Icons.receipt_long,
                                            ),
                                            label: const Text(
                                              'Ver boleto o instrucciones',
                                            ),
                                          ),
                                        if (order.status == 'pending_payment' &&
                                            order.paymentMethod != 'cash' &&
                                            order.expiresAt != null &&
                                            order.expiresAt!.isAfter(
                                              DateTime.now(),
                                            ))
                                          FilledButton.icon(
                                            onPressed:
                                                _openingPaymentFor == order.id
                                                ? null
                                                : () =>
                                                      _openPayment(cart, order),
                                            icon: _openingPaymentFor == order.id
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(Icons.open_in_new),
                                            label: const Text('Continuar pago'),
                                          ),
                                        TextButton.icon(
                                          onPressed: () => context.go('/home'),
                                          icon: const Icon(
                                            Icons.storefront_outlined,
                                          ),
                                          label: const Text('Seguir comprando'),
                                        ),
                                      ],
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

  Future<void> _openPaymentTicket(String ticketUrl) async {
    final uri = Uri.tryParse(ticketUrl);
    if (uri == null || uri.scheme != 'https') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El enlace del boleto no es válido.')),
        );
      }
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el boleto de pago.')),
      );
    }
  }

  String _statusLabel(
    String status,
    DateTime? paymentExpiresAt, {
    bool isCashPayment = false,
  }) {
    switch (status) {
      case 'pending_payment':
        if (isCashPayment) return 'Pendiente de pago en efectivo';
        if (paymentExpiresAt != null &&
            !paymentExpiresAt.isAfter(DateTime.now())) {
          return 'Esperando confirmación del proveedor';
        }
        return 'Pendiente de pago';
      case 'paid':
        return 'Pagado';
      case 'rejected':
        return 'Pago rechazado';
      case 'cancelled':
        return 'Cancelado';
      case 'expired':
        return 'Vencido';
      case 'confirmed':
        return 'Confirmado';
      case 'payment_review':
        return 'Pago en revisión';
      case 'refunded':
        return 'Reembolsado';
      default:
        return status;
    }
  }

  String _paymentMethodLabel(String method, String? fulfillmentMethod) {
    switch (method.toLowerCase()) {
      case 'cash':
        return fulfillmentMethod == 'delivery'
            ? 'Efectivo al repartidor'
            : 'Efectivo en caja al recoger';
      case 'online':
        return 'Pago en línea con Mercado Pago';
      case 'oxxo':
        return 'Efectivo en OXXO';
      case 'visa':
        return 'Tarjeta Visa';
      case 'master':
      case 'mastercard':
        return 'Tarjeta Mastercard';
      case 'amex':
        return 'Tarjeta American Express';
      default:
        return method;
    }
  }

  String _fulfillmentMethodLabel(String method) {
    switch (method) {
      case 'pickup':
        return 'Recoger en el local';
      case 'delivery':
        return 'Entrega a domicilio (gratis)';
      default:
        return method;
    }
  }

  String _fulfillmentStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'preparing':
        return 'En preparación';
      case 'shipped':
        return 'Enviado';
      case 'delivered':
        return 'Entregado';
      case 'ready_for_pickup':
        return 'Listo para recoger';
      case 'picked_up':
        return 'Recogido';
      default:
        return status;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'not_started':
        return 'No iniciado';
      case 'pending':
        return 'Pendiente';
      case 'in_process':
        return 'En proceso';
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado; puedes intentar otro método';
      case 'cancelled':
        return 'Cancelado';
      case 'expired':
        return 'Vencido';
      case 'refunded':
        return 'Reembolsado';
      case 'charged_back':
        return 'Desconocido por el banco';
      default:
        return status;
    }
  }
}
