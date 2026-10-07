import 'package:flutter/material.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: Colors.blue[200],
      child: Row(
        children: [
          IconButton(onPressed: () {
            Scaffold.of(context).openDrawer();
          },
          icon: const Icon(Icons.menu),
        ),
        const Expanded(
          child: Text(
            'Chucherias',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
         ),
        ],
      ),
    );
  }
}