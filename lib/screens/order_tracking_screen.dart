import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  RealtimeChannel? _orderChannel;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToOrderChanges();
  }

  @override
  void dispose() {
    _orderChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', widget.orderId)
          .single();

      if (mounted) {
        setState(() {
          _order = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToOrderChanges() {
    _orderChannel = Supabase.instance.client
        .channel('public:orders:id=eq.${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _order = {...?_order, ...payload.newRecord};
              });
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seguimiento')),
        body: const Center(child: Text('No se encontró el pedido.')),
      );
    }

    final status = _order!['fulfillment_status'] as String? ?? 'pending';
    final driverName = _order!['driver_name'] as String? ?? 'Repartidor';
    final deliveryMethod = _order!['fulfillment_method'] as String? ?? 'delivery';

    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento Pedido #${widget.orderId}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Tarjeta de Estado Actual
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        deliveryMethod == 'pickup' ? Icons.storefront : Icons.delivery_dining,
                        color: Colors.deepOrange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          deliveryMethod == 'pickup' ? 'Modalidad: Recoger en local' : 'Entrega a domicilio',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    'Estado actual: ${_getStatusTitle(status)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.deepOrange),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusDescription(status, deliveryMethod),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Línea de tiempo visual
          const Text('Progreso del pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTimelineTile(
            title: 'Pedido Recibido',
            subtitle: 'Tu orden ha sido registrada con éxito.',
            isCompleted: true,
            isCurrent: status == 'pending',
          ),
          _buildTimelineTile(
            title: 'En Preparación',
            subtitle: 'Nuestros chefs están preparando tus platillos asiáticos.',
            isCompleted: status == 'preparing' || status == 'ready_for_pickup' || status == 'shipped' || status == 'delivered',
            isCurrent: status == 'preparing',
          ),
          if (deliveryMethod == 'delivery') ...[
            _buildTimelineTile(
              title: 'En Camino (Repartidor: $driverName)',
              subtitle: 'El repartidor va en camino a tu dirección.',
              isCompleted: status == 'shipped' || status == 'delivered',
              isCurrent: status == 'shipped',
            ),
            _buildTimelineTile(
              title: 'Entregado',
              subtitle: '¡Disfruta tu comida!',
              isCompleted: status == 'delivered',
              isCurrent: status == 'delivered',
              isLast: true,
            ),
          ] else ...[
            _buildTimelineTile(
              title: 'Listo para recoger',
              subtitle: 'Pasa por tu paquete al local.',
              isCompleted: status == 'ready_for_pickup' || status == 'picked_up',
              isCurrent: status == 'ready_for_pickup',
            ),
            _buildTimelineTile(
              title: 'Entregado / Recogido',
              subtitle: '¡Gracias por tu compra!',
              isCompleted: status == 'picked_up',
              isCurrent: status == 'picked_up',
              isLast: true,
            ),
          ],

          // Simulación visual de mapa o ubicación del repartidor
          if (status == 'shipped' && deliveryMethod == 'delivery') ...[
            const SizedBox(height: 24),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepOrange.shade200),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 48, color: Colors.deepOrange),
                    SizedBox(height: 8),
                    Text('Repartidor en ruta GPS en tiempo real', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Lat: 19.4326, Lon: -99.1332 (Simulado)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'pending': return 'Pendiente';
      case 'preparing': return 'En preparación';
      case 'ready_for_pickup': return 'Listo para recoger';
      case 'shipped': return 'En camino';
      case 'delivered': return 'Entregado';
      case 'picked_up': return 'Recogido';
      default: return status;
    }
  }

  String _getStatusDescription(String status, String method) {
    if (status == 'pending') return 'Esperando confirmación y pago.';
    if (status == 'preparing') return 'La cocina está elaborando tus platillos.';
    if (status == 'shipped') return 'Tu repartidor va rumbo a tu domicilio.';
    if (status == 'ready_for_pickup') return 'Tu pedido está listo en el mostrador.';
    return 'Pedido completado con éxito.';
  }

  Widget _buildTimelineTile({required String title, required String subtitle, required bool isCompleted, required bool isCurrent, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.deepOrange : Colors.grey[300],
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.fiber_manual_record,
                color: Colors.white,
                size: 16,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 45,
                color: isCompleted ? Colors.deepOrange : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCurrent ? Colors.deepOrange : Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}