import 'package:flutter/material.dart';
import '../data/mock_products.dart';
import '../widgets/product_card.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/hero_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'Todos';
  
  @override
  Widget build(BuildContext context) {
    final categories = [
    'Todos',
    ...products.map((product) => product.category).toSet(),
  ];

  final visibleProducts = selectedCategory == 'Todos'
    ? products
    : products
      .where((product) => product.category == selectedCategory)
      .toList();

    return Scaffold(
      backgroundColor: Colors.blue[200],
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppNavigationBar(),

              const SizedBox(height: 16),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HeroBanner(),

                    const SizedBox(height: 24),

                    const Text(
                      'Productos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return ChoiceChip(
                            label: Text(category),
                            selected: selectedCategory == category,
                            onSelected: (_) {
                              setState(() => selectedCategory = category);
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 340,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        separatorBuilder: (_, __) => const SizedBox(width: 12), 
                        itemCount: visibleProducts.length,
                        itemBuilder: (context, index){
                          return SizedBox(
                            width: 250,
                            child: ProductCard(product: visibleProducts[index]),
                          );
                        }
                      ),
                    ),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleProducts.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2,
                      ), 
                      itemBuilder: (context, index){
                        return ProductCard(
                          product: visibleProducts[index]
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}