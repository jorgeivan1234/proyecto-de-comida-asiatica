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
  int? _cancellingOrderId;

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

  Future<String?> _askCancellationDestination(Order order) async {
    final isPaid = order.status == 'paid' && order.paymentStatus == 'approved';

    if (!isPaid) {
      return showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Cancelar este pedido?'),
          content: const Text(
            'Puedes cancelar antes de que esté listo para recoger o salga '
            'con el repartidor. Si ya empezó a prepararse, solo se permite '
            'cuando todos sus productos son recuperables.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'mercadopago'),
              child: const Text('Confirmar cancelación'),
            ),
          ],
        ),
      );
    }

    if (order.paymentProvider == 'cash') {
      return showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancelar pedido pagado en efectivo'),
          content: const Text(
            'El dueño tendrá que gestionar manualmente la devolución del '
            'efectivo cobrado. El saldo de tienda usado en el pedido se '
            'devolverá a tu cuenta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'manual'),
              child: const Text('Cancelar pedido'),
            ),
          ],
        ),
      );
    }

    if (order.paymentProvider == 'wallet') {
      return showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancelar pedido'),
          content: const Text(
            'El importe volverá a tu saldo de tienda, que puedes usar en '
            'próximas compras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'store_credit'),
              child: const Text('Confirmar y devolver al saldo'),
            ),
          ],
        ),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text(
          'Elige cómo recibir el importe pagado. El reembolso al medio de '
          'pago se procesa con Mercado Pago; también puedes recibirlo como '
          'saldo de tienda para futuras compras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Volver'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'mercadopago'),
            child: const Text('Reembolsar a Mercado Pago'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'store_credit'),
            child: const Text('Guardar como saldo'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(CartProvider cart, Order order) async {
    final destination = await _askCancellationDestination(order);
    if (destination == null || !mounted) return;

    setState(() => _cancellingOrderId = order.id);
    try {
      final result = await cart.cancelOrder(
        orderId: order.id,
        refundDestination: destination,
      );
      if (!mounted) return;

      final message = switch (result['result']) {
        'refund_requested' =>
          'Pedido cancelado; Mercado Pago recibió la solicitud de reembolso.',
        'credited' =>
          'Pedido cancelado. El saldo quedó disponible en tu cuenta.',
        'manual_refund_pending' =>
          'Pedido cancelado. El dueño gestionará la devolución en efectivo.',
        'already_cancelled' => 'Este pedido ya estaba cancelado.',
        _ => 'Pedido cancelado.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on FunctionException catch (error) {
      if (!mounted) return;
      _retryLoadingOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.details?.toString() ??
                error.reasonPhrase ??
                'No se pudo completar la cancelación.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      _retryLoadingOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar el pedido: $error')),
      );
    } finally {
      if (mounted) setState(() => _cancellingOrderId = null);
    }
  }

  Future<void> _retryMercadoPagoRefund(CartProvider cart, Order order) async {
    setState(() => _cancellingOrderId = order.id);
    try {
      final result = await cart.cancelOrder(
        orderId: order.id,
        refundDestination: 'mercadopago',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['result'] == 'refund_requested'
                ? 'Mercado Pago recibió la solicitud de reembolso.'
                : 'El reembolso sigue pendiente. Intenta de nuevo más tarde.',
          ),
        ),
      );
    } on FunctionException catch (error) {
      if (!mounted) return;
      _retryLoadingOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.details?.toString() ??
                error.reasonPhrase ??
                'No se pudo reintentar el reembolso.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      _retryLoadingOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reintentar el reembolso: $error')),
      );
    } finally {
      if (mounted) setState(() => _cancellingOrderId = null);
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
                        Text(
                          'Consulta el historial y el estado de tus pedidos.',
                        ),
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
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Todavía no tienes pedidos realizados.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                16,
                              ),
                              title: Text(
                                'Pedido #${order.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} · \$${order.total.toStringAsFixed(2)} MXN',
                              ),
                              trailing: Chip(
                                label: Text(
                                  _statusLabel(
                                    order.status,
                                    order.expiresAt,
                                    isCashPayment:
                                        order.paymentMethod == 'cash',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: order.status == 'cancelled'
                                    ? Colors.grey
                                    : order.status == 'paid' ||
                                          order.status == 'confirmed'
                                    ? Colors.green
                                    : Colors.deepOrange,
                              ),
                              children: [
                                const Divider(),
                                for (final item in order.items)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(item.productName),
                                    subtitle: Text(
                                      '${item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}',
                                    ),
                                    trailing: Text(
                                      '\$${item.subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const Divider(height: 24),

                                // Mostrar botón de rastreo GPS solo si es a domicilio
                                if (order.fulfillmentMethod == 'delivery' &&
                                    order.status != 'cancelled') ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.deepOrange,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => context.push(
                                        '/order-tracking/${order.id}',
                                      ),
                                      icon: const Icon(Icons.location_on),
                                      label: const Text(
                                        'Ver seguimiento del pedido',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pago: ${_paymentStatusLabel(order.paymentStatus)}',
                                      ),
                                      if (order.paymentMethod != null)
                                        Text(
                                          'Método: ${_paymentMethodLabel(order.paymentMethod!, order.fulfillmentMethod)}',
                                        ),
                                      if (order.walletAmount > 0)
                                        Text(
                                          'Saldo de tienda aplicado: '
                                          '\$${order.walletAmount.toStringAsFixed(2)}',
                                        ),
                                      if (order.fulfillmentMethod != null)
                                        Text(
                                          'Entrega: ${_fulfillmentMethodLabel(order.fulfillmentMethod!)}',
                                        ),
                                      if (order.fulfillmentMethod ==
                                              'delivery' &&
                                          order.deliveryAddress != null)
                                        Text(
                                          'Dirección: ${order.deliveryAddress}',
                                        ),
                                      if (order.paymentStatus ==
                                          'refund_pending')
                                        const Text(
                                          'Reembolso pendiente de confirmación.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      if (order.paymentStatus ==
                                          'refund_requested')
                                        const Text(
                                          'Mercado Pago recibió la solicitud; el reembolso está en proceso.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      if (order.paymentStatus == 'credited')
                                        const Text(
                                          'Reembolso acreditado al saldo de tienda.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      if (order.paymentStatus == 'refunded')
                                        const Text(
                                          'Reembolso confirmado.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      if (order.fulfillmentStatus != null)
                                        Text(
                                          'Estado de envío: ${_fulfillmentStatusLabel(order.fulfillmentStatus!)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (order.canCustomerCancel) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _cancellingOrderId == order.id
                                          ? null
                                          : () => _cancelOrder(cart, order),
                                      icon: _cancellingOrderId == order.id
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.cancel_outlined),
                                      label: Text(
                                        _cancellingOrderId == order.id
                                            ? 'Cancelando...'
                                            : 'Cancelar pedido',
                                      ),
                                    ),
                                  ),
                                ],
                                if (order.status != 'cancelled' &&
                                    order.fulfillmentStatus == 'preparing' &&
                                    !order.canCustomerCancel)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'La cocina ya empezó y al menos un producto no es recuperable; este pedido no se puede cancelar.',
                                        style: TextStyle(
                                          color: Colors.deepOrange,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (order.paymentStatus == 'refund_pending' &&
                                    order.refundDestination ==
                                        'mercadopago') ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _cancellingOrderId == order.id
                                          ? null
                                          : () => _retryMercadoPagoRefund(
                                              cart,
                                              order,
                                            ),
                                      icon: _cancellingOrderId == order.id
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh),
                                      label: const Text('Reintentar reembolso'),
                                    ),
                                  ),
                                ],
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

  String _statusLabel(
    String status,
    DateTime? paymentExpiresAt, {
    bool isCashPayment = false,
  }) {
    switch (status) {
      case 'pending_payment':
        return 'Pendiente';
      case 'paid':
        return 'Pagado';
      case 'rejected':
        return 'Rechazado';
      case 'cancelled':
        return 'Cancelado';
      case 'confirmed':
        return 'Confirmado';
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
            : 'Efectivo en caja';
      case 'online':
        return 'Mercado Pago';
      case 'wallet':
        return 'Saldo de tienda';
      default:
        return method;
    }
  }

  String _fulfillmentMethodLabel(String method) {
    return method == 'pickup' ? 'Recoger en local' : 'A domicilio (Gratis)';
  }

  String _fulfillmentStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente de preparar';
      case 'preparing':
        return 'En preparación en cocina';
      case 'shipped':
        return 'En camino con repartidor';
      case 'delivered':
        return 'Entregado en domicilio';
      case 'ready_for_pickup':
        return 'Listo para recoger en mostrador';
      case 'picked_up':
        return 'Recogido';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Aprobado';
      case 'pending':
        return 'Pendiente';
      case 'rejected':
        return 'Rechazado';
      case 'refund_pending':
        return 'Reembolso pendiente';
      case 'refund_requested':
        return 'Reembolso en proceso';
      case 'refunded':
        return 'Reembolsado';
      case 'credited':
        return 'Acreditado al saldo';
      default:
        return status;
    }
  }
}
