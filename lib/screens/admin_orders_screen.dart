import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  int? _updatingOrderId;
  int? _confirmingCashOrderId;
  int? _recordingCashRefundOrderId;

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
          'payment_provider, payment_status, refund_destination, wallet_amount, '
          'delivery_address, total, created_at, driver_name, '
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

  Future<void> _updateFulfillmentStatus(
    int orderId,
    String newStatus, {
    String? driverName,
  }) async {
    setState(() => _updatingOrderId = orderId);

    try {
      final updateData = <String, dynamic>{'fulfillment_status': newStatus};
      if (driverName != null) {
        updateData['driver_name'] = driverName;
      }

      // Ejecutamos el update directamente sin .maybeSingle() ni .select()
      await Supabase.instance.client
          .from('orders')
          .update(updateData)
          .eq('id', orderId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado de envío actualizado correctamente.'),
        ),
      );
      _refreshOrders();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: ${error.message}')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ocurrió un error: $error')));
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  Future<void> _promptAssignDriverAndShip(int orderId) async {
    final controller = TextEditingController(text: 'Carlos Repartidor');
    final driver = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asignar Repartidor y Enviar'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre del repartidor',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Marcar En Camino'),
          ),
        ],
      ),
    );

    if (driver != null && driver.isNotEmpty && mounted) {
      await _updateFulfillmentStatus(orderId, 'shipped', driverName: driver);
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
        const SnackBar(content: Text('Pago en efectivo confirmado con éxito.')),
      );
      _refreshOrders();
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

  Future<void> _recordManualCashRefund(int orderId) async {
    setState(() => _recordingCashRefundOrderId = orderId);

    try {
      await Supabase.instance.client.rpc(
        'confirm_manual_cash_refund',
        params: {'p_order_id': orderId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reembolso en efectivo registrado.')),
      );
      _refreshOrders();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar: ${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _recordingCashRefundOrderId = null);
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
      DropdownMenuItem(value: 'shipped', child: Text('En camino (Repartidor)')),
      DropdownMenuItem(value: 'delivered', child: Text('Entregado')),
    ];
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
                          'Gestión de Pedidos y Envíos',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Supervisa entregas, pagos y asigna repartidores.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar lista',
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
                            Text('Error al cargar pedidos: ${snapshot.error}'),
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
                    return const Center(
                      child: Text('Todavía no hay pedidos registrados.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final orderId = order['id'] as int;
                      final isPaid =
                          order['status'] == 'paid' ||
                          order['payment_status'] == 'approved';
                      final isPickup =
                          (order['fulfillment_method'] as String? ??
                              'pickup') ==
                          'pickup';
                      final fulfillmentStatus =
                          order['fulfillment_status'] as String? ?? 'pending';
                      final driverName =
                          order['driver_name'] as String? ?? 'No asignado';
                      final createdAt = DateTime.parse(
                        order['created_at'] as String,
                      ).toLocal();
                      final items = order['order_items'] as List? ?? [];
                      final paymentStatus =
                          order['payment_status'] as String? ?? 'pending';
                      final paymentProvider =
                          order['payment_provider'] as String? ?? '';
                      final walletAmount = (order['wallet_amount'] as num? ?? 0)
                          .toDouble();

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
                            'Pedido #$orderId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '${createdAt.day}/${createdAt.month}/${createdAt.year} · \$${(order['total'] as num).toStringAsFixed(2)} MXN',
                          ),
                          children: [
                            const Divider(),
                            for (final rawItem in items)
                              Builder(
                                builder: (context) {
                                  final item = Map<String, dynamic>.from(
                                    rawItem as Map,
                                  );
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(item['product_name'] as String),
                                    subtitle: Text(
                                      '${item['quantity']} × \$${(item['unit_price'] as num).toStringAsFixed(2)}',
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Pago: ${isPaid ? 'Confirmado' : paymentStatus}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (paymentStatus == 'refund_pending' ||
                                paymentStatus == 'refund_requested')
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  paymentProvider == 'cash'
                                      ? 'Reembolso en efectivo pendiente: '
                                            '\$${((order['total'] as num).toDouble() - walletAmount).toStringAsFixed(2)}'
                                      : paymentStatus == 'refund_requested'
                                      ? 'Reembolso solicitado a Mercado Pago; pendiente de confirmación.'
                                      : 'Reembolso a Mercado Pago pendiente: '
                                            '\$${((order['total'] as num).toDouble() - walletAmount).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Icon(
                                  isPickup
                                      ? Icons.storefront
                                      : Icons.delivery_dining,
                                  size: 20,
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isPickup
                                      ? 'Modalidad: Recoger en local'
                                      : 'Modalidad: A domicilio',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (!isPickup) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Repartidor: $driverName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),

                            if (fulfillmentStatus == 'cancelled') ...[
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Pedido cancelado por el cliente.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (paymentStatus == 'refund_pending' &&
                                  paymentProvider == 'cash') ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _recordingCashRefundOrderId == orderId
                                        ? null
                                        : () =>
                                              _recordManualCashRefund(orderId),
                                    icon: _recordingCashRefundOrderId == orderId
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.payments_outlined),
                                    label: const Text(
                                      'Registrar reembolso manual en efectivo',
                                    ),
                                  ),
                                ),
                              ],
                            ],

                            // Botón rápido de acción para envío a domicilio
                            if (fulfillmentStatus != 'cancelled' &&
                                !isPickup &&
                                fulfillmentStatus == 'preparing')
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                  ),
                                  onPressed: () =>
                                      _promptAssignDriverAndShip(orderId),
                                  icon: const Icon(Icons.local_shipping),
                                  label: const Text(
                                    'Asignar Repartidor y Marcar "En Camino"',
                                  ),
                                ),
                              ),

                            if (fulfillmentStatus != 'cancelled') ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: fulfillmentStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Actualizar Estado de Entrega',
                                  border: OutlineInputBorder(),
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
                              ),
                            ],
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
