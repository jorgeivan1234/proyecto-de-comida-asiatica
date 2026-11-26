import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: const Color(0xFF6F4E37),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            icon: const Icon(
              Icons.menu,
              color: Color(0xFFF3E5AB),
            ),
          ),
          const Expanded(
            child: Text(
              'Chucherias',
              style: TextStyle(
                fontSize: 15, 
                fontWeight: FontWeight.bold,
                color: Color(0xFFF3E5AB)
              ),
            ),
          ),
          IconButton(
            tooltip: 'carrito',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              context.push('/cart');
            },
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: Color(0xFFF3E5AB),
            ),
          ),

          IconButton(
            tooltip: 'Mis pedidos',
            onPressed: () => context.push('/orders'),
            icon: const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFFF3E5AB),
            ),
          ),
        ],
      ),
    );
  }
}
