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

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    final rows = await Supabase.instance.client
      .from('orders')
      .select(
        'id, user_id, status, payment_status, fulfillment_status, '
        'fulfillment_method, delivery_address, total, created_at, '
        'order_items(product_name, quantity, unit_price)',
      )
      .order('created_at', ascending: false);

    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _loadOrders();
    });
  }

  Future<void> _updateFulfillmentStatus( 
    int orderId,
    String newStatus,
  ) async {
    setState(() => _updatingOrderId = orderId);

    try {
      final update = await Supabase.instance.client
        .from('orders')
        .update({'fulfillment_status': newStatus})
        .eq('id', orderId)
        .eq('status', 'paid')
        .eq('payment_status', 'approved')
        .select('id')
        .maybeSingle();

      if (update == null) {
        throw StateError(
          'No se actualizo el pedido. Confirma que siga pagado.'
        );
      }

      if (!mounted) return;
      setState(() {
        _ordersFuture = _loadOrders();
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede actualizar: ${error.message}')),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingOrderId = null);
      }
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
              padding: const EdgeInsetsGeometry.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedidos y envios',
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
                    icon: const Icon(Icons.refresh)
                  )
                ],
              ),
            ),
            Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _ordersFuture, 
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting){
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
                              child: const Text('volver a intentar')
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final orders = snapshot.data ?? [];

                  if (orders.isEmpty) {
                    return const Center(
                      child: Text('Todavia no hay pedidos.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final orderId = order['id'] as int;
                      final isPaid = order['status'] == 'paid' && order['payment_status'] == 'approved';
                      final method = order['fulfillment_method'] as String? ?? 'pickup';
                      final isPickup = method == 'pickup';
                      final fulfillmentStatus = order['fulfillment status'] as String ? ?? 'pending';                      
                      final createdAt = DateTime.parse(order['created_at'] as String).toLocal();
                      final items = order['order_items'] as List? ?? [];
                      final fulfillmentOptions = isPickup 
                          ? const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pendiente'),
                          ),
                          DropdownMenuItem(
                            value: 'preparing',
                            child: Text('En preparacion'),
                          ),
                          DropdownMenuItem(
                            value: 'ready_for_pickup',
                            child: Text('Listo para recoger'),
                          ),
                          DropdownMenuItem(
                            value: 'picked_uo',
                            child: Text('Recogido'),
                          ),
                        ]
                      : const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pendiente'),
                          ),
                          DropdownMenuItem(
                            value: 'preparing',
                            child: Text('En preparacion'),
                          ),
                          DropdownMenuItem(
                            value: 'ready_for_pickup',
                            child: Text('Listo para recoger'),
                          ),
                          DropdownMenuItem(
                            value: 'picked_uo',
                            child: Text('Recogido'),
                          ),
                        ];
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${createdAt.day}/${createdAt.month}/'
                            '${createdAt.year} . '
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
                                        final item = Map<String, dynamic>.from(rawItem as Map);

                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            item['product_name'] as String,
                                          ),
                                          subtitle: Text(
                                            '${item['quantity']} x '
                                            '\$${(item['unit_price'] as num).toStringAsFixed(2)}',
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.payment),
                                      title: const Text('Estado del pago'),
                                      subtitle: Text(
                                        order['payment_status'] as String,
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
                                            : 'Entregar a domicilio',
                                      ),
                                    ),

                                    if (!isPickup)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.location_on),
                                        title: const Text('Direccion de entrega'),
                                        subtitle: Text(
                                          order['delivery_address'] as String? ?? 
                                                'No se guardo una direccion.',
                                        ),
                                      ),
                                      
                                    if (isPaid)
                                      DropdownButtonFormField<String>(
                                        initialValue: fulfillmentStatus,
                                        decoration: InputDecoration(
                                          labelText: isPickup 
                                              ? 'Estadi de recogida'
                                              : 'Estado del envio',
                                           contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 14,
                                           ),
                                           border: const OutlineInputBorder(),
                                        ),
                                        items: fulfillmentOptions,
                                        onChanged: _updatingOrderId == orderId
                                            ? null
                                            : (value){
                                              if (value != null) {
                                                _updateFulfillmentStatus(
                                                  orderId, 
                                                  value
                                                );
                                              }
                                            },
                                      )
                                    else 
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          'La entrega se habilita cuando el pago este aprobado.'
                                        ),
                                      ),
                                    if (_updatingOrderId == orderId)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 16),
                                        child: CircularProgressIndicator(),
                                      ),
                                ],
                              ),
                            ),
                          

                              if (isPaid)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 8,
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    initialValue: order['fulfillment_status'] as String,
                                    decoration: const InputDecoration(
                                      labelText: 'Estado del envio',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'pending',
                                        child: Text('Pendiente'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'preparing',
                                        child: Text('En preparacion'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'shipped',
                                        child: Text('Enviado'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'delivered',
                                        child: Text('Entregado'),
                                      ),
                                    ], 
                                    onChanged: _updatingOrderId == orderId
                                      ? null 
                                      : (value) {
                                        if (value != null) {
                                          _updateFulfillmentStatus(
                                            orderId, 
                                            value,
                                          );
                                        }
                                      }
                                  ),
                                )
                                else 
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('El envio se habilita cuando el pago este aprobado.'),
                                  ),
                                  if (_updatingOrderId == orderId)
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(), 
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