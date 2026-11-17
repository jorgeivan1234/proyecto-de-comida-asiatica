import 'package:ccomcercio_electronico/widgets/app_drawer.dart';
import 'package:ccomcercio_electronico/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  int? _updatingOrderId;
  int? _confirmingCashOrderId;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    final rows = await Supabase.instance.client
        .from('orders')
        .select(
          'id, user_id, status, payment_status, payment_provider, '
          'payment_method, fulfillment_status, fulfillment_method, '
          'delivery_address, total, created_at, '
          'order_items(product_name, quantity, unit_price)',
        )
        .order('created_at', ascending: false);

    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = _loadOrders();
    });
  }

  Future<void> _updateFulfillmentStatus(int orderId, String newStatus) async {
    setState(() => _updatingOrderId = orderId);

    try {
      final updated = await Supabase.instance.client
          .from('orders')
          .update({'fulfillment_status': newStatus})
          .eq('id', orderId)
          .eq('status', 'paid')
          .eq('payment_status', 'approved')
          .select('id')
          .maybeSingle();

      if (updated == null) {
        throw StateError(
          'No se actualizó el pedido. Confirma que el pago siga aprobado.',
        );
      }

      if (!mounted) return;
      setState(() {
        _ordersFuture = _loadOrders();
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el envío: ${error.message}'),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  Future<void> _confirmCashPayment(int orderId) async {
    setState(() => _confirmingCashOrderId = orderId);

    try {
      await Supabase.instance.client.rpc(
        'confirm_cash_order_payment',
        params: {'p_order_id': orderId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago en efectivo confirmado.')),
      );
      setState(() {
        _ordersFuture = _loadOrders();
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo confirmar el efectivo: ${error.message}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingCashOrderId = null);
    }
  }

  List<DropdownMenuItem<String>> _fulfillmentOptions(bool isPickup) {
    if (isPickup) {
      return const [
        DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
        DropdownMenuItem(value: 'preparing', child: Text('En preparación')),
        DropdownMenuItem(
          value: 'ready_for_pickup',
          child: Text('Listo para recoger'),
        ),
        DropdownMenuItem(value: 'picked_up', child: Text('Recogido')),
      ];
    }

    return const [
      DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
      DropdownMenuItem(value: 'preparing', child: Text('En preparación')),
      DropdownMenuItem(value: 'shipped', child: Text('Enviado')),
      DropdownMenuItem(value: 'delivered', child: Text('Entregado')),
    ];
  }

  String _paymentMethodLabel(Map<String, dynamic> order) {
    if (order['payment_provider'] == 'cash') {
      return 'Efectivo';
    }

    final method = order['payment_method'] as String?;
    if (method == null || method == 'online') {
      return 'Mercado Pago';
    }

    switch (method.toLowerCase()) {
      case 'visa':
        return 'Tarjeta Visa';
      case 'master':
      case 'mastercard':
        return 'Tarjeta Mastercard';
      case 'amex':
        return 'Tarjeta American Express';
      case 'oxxo':
        return 'Efectivo en OXXO';
      default:
        return method;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente de pago';
      case 'approved':
        return 'Pagado';
      case 'in_process':
        return 'Pago en proceso';
      case 'rejected':
        return 'Pago rechazado';
      case 'cancelled':
        return 'Pago cancelado';
      case 'expired':
        return 'Pago vencido';
      default:
        return status;
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
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedidos y envíos',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('Consulta los pedidos y actualiza su entrega.'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar pedidos',
                    onPressed: _refreshOrders,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
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
                              'No se pudieron cargar los pedidos: '
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _refreshOrders,
                              child: const Text('Volver a intentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final orders = snapshot.data ?? [];
                  if (orders.isEmpty) {
                    return const Center(child: Text('Todavía no hay pedidos.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final orderId = order['id'] as int;
                      final isPaid =
                          order['status'] == 'paid' &&
                          order['payment_status'] == 'approved';
                      final isCashPayment =
                          order['payment_provider'] == 'cash' &&
                          order['payment_method'] == 'cash';
                      final isPendingCash =
                          !isPaid &&
                          isCashPayment &&
                          order['status'] == 'pending_payment';
                      final isPickup =
                          (order['fulfillment_method'] as String? ??
                              'pickup') ==
                          'pickup';
                      final fulfillmentStatus =
                          order['fulfillment_status'] as String? ?? 'pending';
                      final createdAt = DateTime.parse(
                        order['created_at'] as String,
                      ).toLocal();
                      final items = order['order_items'] as List? ?? [];

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          childrenPadding: const EdgeInsets.only(bottom: 12),
                          title: Text(
                            'Pedido #$orderId',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${createdAt.day}/${createdAt.month}/'
                            '${createdAt.year} · '
                            '\$${(order['total'] as num).toStringAsFixed(2)}',
                          ),
                          children: [
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  for (final rawItem in items)
                                    Builder(
                                      builder: (context) {
                                        final item = Map<String, dynamic>.from(
                                          rawItem as Map,
                                        );
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            item['product_name'] as String,
                                          ),
                                          subtitle: Text(
                                            '${item['quantity']} × '
                                            '\$${(item['unit_price'] as num).toStringAsFixed(2)}',
                                          ),
                                        );
                                      },
                                    ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.payment),
                                    title: const Text('Método de pago'),
                                    subtitle: Text(_paymentMethodLabel(order)),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.receipt_long),
                                    title: const Text('Estado del pago'),
                                    subtitle: Text(
                                      _paymentStatusLabel(
                                        order['payment_status'] as String,
                                      ),
                                    ),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      isPickup
                                          ? Icons.storefront
                                          : Icons.delivery_dining,
                                    ),
                                    title: const Text('Modalidad'),
                                    subtitle: Text(
                                      isPickup
                                          ? 'Recoger en el local'
                                          : 'Entrega a domicilio · Gratis',
                                    ),
                                  ),
                                  if (!isPickup)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.location_on),
                                      title: const Text('Dirección de entrega'),
                                      subtitle: Text(
                                        order['delivery_address'] as String? ??
                                            'No se guardó una dirección.',
                                      ),
                                    ),
                                  if (isPendingCash)
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed:
                                            _confirmingCashOrderId == orderId
                                            ? null
                                            : () =>
                                                  _confirmCashPayment(orderId),
                                        icon: _confirmingCashOrderId == orderId
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.payments),
                                        label: const Text(
                                          'Confirmar efectivo recibido',
                                        ),
                                      ),
                                    ),
                                  if (isPaid)
                                    DropdownButtonFormField<String>(
                                      initialValue: fulfillmentStatus,
                                      decoration: InputDecoration(
                                        labelText: isPickup
                                            ? 'Estado de recogida'
                                            : 'Estado del envío',
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: _fulfillmentOptions(isPickup),
                                      onChanged: _updatingOrderId == orderId
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                _updateFulfillmentStatus(
                                                  orderId,
                                                  value,
                                                );
                                              }
                                            },
                                    )
                                  else if (!isPendingCash)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'La entrega se habilita cuando el '
                                        'pago esté aprobado.',
                                      ),
                                    ),
                                  if (_updatingOrderId == orderId ||
                                      _confirmingCashOrderId == orderId)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 16),
                                      child: CircularProgressIndicator(),
                                    ),
                                ],
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
