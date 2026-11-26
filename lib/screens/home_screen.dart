import 'package:ccomcercio_electronico/models/models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/product_card.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/hero_banner.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchQuery = '';
  String selectedCategory = 'Todos';
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _loadProducts();
  }

  Future<List<Product>> _loadProducts() async {
    final rows = await Supabase.instance.client
        .from('products_available')
        .select('id, name, description, price, category, image, stock')
        .order('name');

    return rows.map<Product>((row) {
      return Product(
        id: row['id'] as int,
        name: row['name'] as String,
        description: row['description'] as String,
        price: (row['price'] as num).toDouble(),
        category: row['category'] as String,
        image: row['image'] as String,
        stock: row['stock'] as int,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error al cargar prodcutos: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('No se pudieron cargar los prodcutos.')),
          );
        }

        final dbProducts = snapshot.data!;

        final query = searchQuery.trim().toLowerCase();

        final searchResults = dbProducts.where((products) {
          return products.name.toLowerCase().contains(query);
        }).toList();

        final featuresProducts = searchResults.take(3).toList();

        final visibleProducts = dbProducts.where((product) {
          final productCategory = product.category.trim().toLowerCase();
          final matchesCategory =
              selectedCategory == 'Todos' ||
              (selectedCategory == 'Almuerzos' &&
                  productCategory.contains('almuerzo')) ||
              (selectedCategory == 'Dulces' &&
                  productCategory.contains('dulce')) ||
              (selectedCategory == 'Descuentos' &&
                  productCategory.contains('descuento'));

          final matchesName = product.name.toLowerCase().contains(query);

          return matchesCategory && matchesName;
        }).toList();

        final categories = ['Todos', 'Almuerzos', 'Dulces', 'Descuentos'];

        final width = MediaQuery.sizeOf(context).width;
        final columns = width > 900
            ? 4
            : width > 600
            ? 3
            : 2;

        return Scaffold(
          backgroundColor: const Color(0xFFF3E5AB),
          drawer: const AppDrawer(),
          body: SafeArea(
            child: Column(
              children: [
                const AppNavigationBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const HeroBanner(),
                              const SizedBox(height: 28),
                              const Text(
                                '¿Qué se te antoja hoy?',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF30231F),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Encuentra tus favoritos de la cocina asiática.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.brown.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                onChanged: (value) {
                                  setState(() => searchQuery = value);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Buscar productos...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.deepOrange,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.brown.shade100,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Colors.deepOrange,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              const Text(
                                'Explora por categoría',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF30231F),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 44,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: categories.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final category = categories[index];
                                    final selected =
                                        selectedCategory == category;

                                    return ChoiceChip(
                                      label: Text(category),
                                      selected: selected,
                                      showCheckmark: false,
                                      selectedColor: Colors.deepOrange,
                                      backgroundColor: Colors.white,
                                      side: BorderSide(
                                        color: selected
                                            ? Colors.deepOrange
                                            : Colors.brown.shade100,
                                      ),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.brown.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      onSelected: (_) {
                                        setState(
                                          () => selectedCategory = category,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF9D3E22),
                                      Color(0xFFD66A36),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepOrange.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Descubre sabores de Asia',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Platillos, dulces y ofertas para disfrutar.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _categoryButton(
                                          context,
                                          '/almuerzos',
                                          Icons.rice_bowl,
                                          'Almuerzos',
                                        ),
                                        _categoryButton(
                                          context,
                                          '/dulces',
                                          Icons.cake_outlined,
                                          'Dulces',
                                        ),
                                        _categoryButton(
                                          context,
                                          '/descuentos',
                                          Icons.local_offer_outlined,
                                          'Ofertas',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Destacados',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF30231F),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${featuresProducts.length} productos',
                                    style: TextStyle(
                                      color: Colors.brown.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (featuresProducts.isEmpty)
                                const Text('No hay productos para mostrar.')
                              else
                                SizedBox(
                                  height: 390,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: featuresProducts.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 14),
                                    itemBuilder: (context, index) {
                                      return SizedBox(
                                        width: 250,
                                        child: ProductCard(
                                          product: featuresProducts[index],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 30),
                              Text(
                                selectedCategory == 'Todos'
                                    ? 'Todos los productos'
                                    : selectedCategory,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF30231F),
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (visibleProducts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: Text('No se encontraron productos.'),
                                  ),
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: visibleProducts.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                        mainAxisExtent: 380,
                                      ),
                                  itemBuilder: (context, index) {
                                    return ProductCard(
                                      product: visibleProducts[index],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _categoryButton(
    BuildContext context,
    String route,
    IconData icon,
    String label,
  ) {
    return FilledButton.tonalIcon(
      onPressed: () => context.push(route),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
