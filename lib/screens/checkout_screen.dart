import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/cart_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deliveryAddressController = TextEditingController();

  String _fulfillmentMethod = 'pickup';
  String? _paymentMethod;
  bool _isSubmitting = false;
  bool _isLoadingWallet = true;
  bool _applyStoreCredit = false;
  double _walletBalance = 0;
  Object? _walletBalanceError;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final balance = await context.read<CartProvider>().loadWalletBalance();
      if (!mounted) return;
      setState(() {
        _walletBalance = balance;
        _walletBalanceError = null;
        _isLoadingWallet = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _walletBalanceError = error;
        _isLoadingWallet = false;
      });
    }
  }

  double _walletAmountFor(double total) {
    return _applyStoreCredit ? math.min(_walletBalance, total) : 0;
  }

  Future<void> _confirmPurchase(CartProvider cart) async {
    if (_isSubmitting) return;

    var orderCreated = false;
    final walletAmount = _walletAmountFor(cart.total);
    final amountDue = cart.total - walletAmount;

    if (amountDue > 0 && _paymentMethod == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Elige cómo vas a pagar.')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar pedido'),
        content: Text(
          'Modalidad: '
          '${_fulfillmentMethod == 'pickup' ? 'Recoger en el local' : 'Entrega a domicilio'}\n'
          '${_fulfillmentMethod == 'delivery' ? 'Dirección: ${_deliveryAddressController.text.trim()}\n' : ''}'
          '${walletAmount > 0 ? 'Saldo de tienda: -\$${walletAmount.toStringAsFixed(2)}\n' : ''}'
          'Pago: ${amountDue == 0
              ? 'Saldo de tienda'
              : _paymentMethod == 'cash'
              ? (_fulfillmentMethod == 'pickup' ? 'Efectivo en caja' : 'Efectivo al repartidor')
              : 'Mercado Pago'}\n'
          'Total: \$${amountDue.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              amountDue == 0
                  ? 'Confirmar pedido'
                  : _paymentMethod == 'cash'
                  ? 'Confirmar pedido'
                  : 'Continuar al pago',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final order = await cart.checkout(
        fulfillmentMethod: _fulfillmentMethod,
        deliveryAddress: _fulfillmentMethod == 'delivery'
            ? _deliveryAddressController.text.trim()
            : null,
        paymentMethod: amountDue == 0 ? 'wallet' : _paymentMethod!,
        walletAmount: walletAmount,
      );
      if (order == null || !mounted) return;
      orderCreated = true;

      if (amountDue == 0 || _paymentMethod == 'cash') {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              amountDue == 0
                  ? 'Pedido pagado con tu saldo de tienda.'
                  : _fulfillmentMethod == 'pickup'
                  ? 'Pedido registrado. Pagarás en caja al recogerlo.'
                  : 'Pedido registrado. Pagarás en efectivo al repartidor.',
            ),
          ),
        );
        context.go('/orders');
        return;
      }

      final checkoutUrl = await cart.createPaymentCheckout(order.id);
      final opened = await launchUrl(
        checkoutUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw StateError(
          'No se pudo abrir el pago. Puedes volver a intentarlo desde Mis pedidos.',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se abrió el pago seguro de Mercado Pago.'),
        ),
      );
      context.go('/orders');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el pedido: ${error.message}'),
        ),
      );
      if (orderCreated) context.go('/orders');
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
      if (orderCreated) context.go('/orders');
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      if (orderCreated) context.go('/orders');
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Respuesta inválida del servidor: ${error.message}'),
        ),
      );
      if (orderCreated) context.go('/orders');
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar la compra: $error')),
      );
      if (orderCreated) context.go('/orders');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final walletAmount = _walletAmountFor(cart.total);
    final amountDue = cart.total - walletAmount;

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppNavigationBar(),
            Expanded(
              child: cart.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Tu carrito está vacío.'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.go('/cart'),
                            child: const Text('Volver al carrito'),
                          ),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'Revisar pedido',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '¿Cómo quieres recibirlo?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RadioGroup<String>(
                            groupValue: _fulfillmentMethod,
                            onChanged: (value) {
                              if (value != null && !_isSubmitting) {
                                setState(() {
                                  _fulfillmentMethod = value;
                                });
                              }
                            },
                            child: Column(
                              children: [
                                Card(
                                  child: RadioListTile<String>(
                                    value: 'pickup',
                                    title: const Text('Recoger en el local'),
                                    secondary: const Icon(Icons.storefront),
                                    enabled: !_isSubmitting,
                                  ),
                                ),
                                Card(
                                  child: RadioListTile<String>(
                                    value: 'delivery',
                                    title: const Text('Entrega a domicilio'),
                                    secondary: const Icon(
                                      Icons.delivery_dining,
                                    ),
                                    enabled: !_isSubmitting,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_fulfillmentMethod == 'delivery') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _deliveryAddressController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Dirección de entrega',
                                hintText: 'Calle, número, colonia, código postal y referencias',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (_fulfillmentMethod == 'delivery' &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Escribe la dirección de entrega.';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (_isLoadingWallet)
                            const LinearProgressIndicator()
                          else if (_walletBalanceError != null)
                            Text(
                              'No se pudo consultar tu saldo de tienda: '
                              '$_walletBalanceError',
                              style: const TextStyle(color: Colors.red),
                            )
                          else if (_walletBalance > 0) ...[
                            Card(
                              child: CheckboxListTile(
                                value: _applyStoreCredit,
                                onChanged: _isSubmitting
                                    ? null
                                    : (value) => setState(
                                        () =>
                                            _applyStoreCredit = value ?? false,
                                      ),
                                title: Text(
                                  'Usar saldo de tienda '
                                  '(\$${_walletBalance.toStringAsFixed(2)} disponible)',
                                ),
                                subtitle: Text(
                                  'Se aplicarán \$${_walletAmountFor(cart.total).toStringAsFixed(2)} '
                                  'a este pedido. Puedes cubrir una parte o el total.',
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                          if (amountDue > 0) ...[
                            const SizedBox(height: 24),
                            const Text(
                              '¿Cómo quieres pagar?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RadioGroup<String>(
                              groupValue: _paymentMethod,
                              onChanged: (value) {
                                if (value != null && !_isSubmitting) {
                                  setState(() => _paymentMethod = value);
                                }
                              },
                              child: Column(
                                children: [
                                  Card(
                                    child: RadioListTile<String>(
                                      value: 'cash',
                                      title: Text(
                                        _fulfillmentMethod == 'pickup'
                                            ? 'Efectivo en caja al recoger'
                                            : 'Efectivo al repartidor',
                                      ),
                                      secondary: const Icon(Icons.payments),
                                      enabled: !_isSubmitting,
                                    ),
                                  ),
                                  Card(
                                    child: RadioListTile<String>(
                                      value: 'online',
                                      title: const Text(
                                        'Pagar ahora con tarjeta',
                                      ),
                                      subtitle: const Text(
                                        'Crédito o débito en Mercado Pago',
                                      ),
                                      secondary: const Icon(Icons.credit_card),
                                      enabled: !_isSubmitting,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Tu saldo de tienda cubre el pedido completo.',
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          const Text(
                            'Productos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: Column(
                              children: [
                                for (final item in cart.items)
                                  ListTile(
                                    title: Text(item.product.name),
                                    subtitle: Text(
                                      '${item.quantity} × '
                                      '\$${item.product.price.toStringAsFixed(2)}',
                                    ),
                                    trailing: Text(
                                      '\$${item.subtotal.toStringAsFixed(2)}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Total: \$${cart.total.toStringAsFixed(2)} MXN',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (walletAmount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Saldo aplicado: '
                                '-\$${walletAmount.toStringAsFixed(2)} · '
                                'Restante: \$${amountDue.toStringAsFixed(2)} MXN',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (_fulfillmentMethod == 'delivery')
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('Entrega: Gratis'),
                            ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _confirmPurchase(cart),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock),
                            label: Text(
                              _isSubmitting
                                  ? 'Preparando pedido...'
                                  : amountDue <= 0
                                  ? 'Confirmar pedido con saldo'
                                  : _paymentMethod == 'cash'
                                  ? 'Confirmar pedido'
                                  : 'Confirmar y pagar',
                            ),
                          ),
                          TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => context.go('/cart'),
                            child: const Text('Volver al carrito'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
