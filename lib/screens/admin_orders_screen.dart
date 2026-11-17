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
        'id, user_is, status, payment_status, fulfillment_status, '
        'total, created_at, '
        'order_items(product_name, quantity, unit_price)',
      )
      .order('created_at', ascending: false);

    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Gestion de pedidos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Actualizar pedidos',
                    onPressed: () {
                      setState(() {
                        _ordersFuture = _loadOrders();
                      });
                    },
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
                              onPressed: () {
                                setState(() {
                                  _ordersFuture = _loadOrders();
                                });
                              },
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

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final orderId = order['id'] as int;
                      final isPaid = order['status'] == 'paid' && order['payment_status'] == 'approved';
                      final items = order['order_items'] as List;
                      
                      final createdAt = DateTime.parse(order['created_at'] as String).toLocal();


                      return Card(
                        child: ExpansionTile(
                          title: Text('Pedido #$orderId'),
                          subtitle: Text(
                            '${createdAt.day}/${createdAt.month}/'
                            '${createdAt.year} . '
                            '\$${(order['total'] as num).toStringAsFixed(2)}',
                          ),
                          children: [
                            for (final rawItem in items)
                              Builder(
                                builder: (context) {
                                  final item = Map<String, dynamic>.from(rawItem as Map);

                                  return ListTile(
                                    title: Text(item['product_name'] as String),
                                    subtitle: Text(
                                      '${item['quantity']} x '
                                      '\$${(item['unit_price'] as num).toStringAsFixed(2)}',
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                title: const Text('Estado del pago'),
                                subtitle: Text(
                                  '${order['payment_status']}',
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