import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/mock_products.dart';
import '../models/product.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/product_card.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Todos';
  String _sortBy = 'name';
  bool _onlyInStock = false;

  late Future<List<Product>> _productsFuture;

    @override
  void initState() {
    super.initState();
    _productsFuture = _loadProducts();
  }


  Future<List<Product>> _loadProducts() async {
    final rows = await Supabase.instance.client
      .from('products')
      .select('id, name, description, price, category, image, stock')
      .order('name');

    return rows.map<Product>((row){
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

  void _retryLoadingProducts(){
    setState((){
      _productsFuture = _loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: Colors.blue[200],
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppNavigationBar(),
            Expanded(
              child: FutureBuilder(
                future: _productsFuture, 
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting){
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ni se pudieron cargar los productos: '
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 12),

                            FilledButton(
                              onPressed: _retryLoadingProducts,
                              child: const Text('Volver a intentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final dbProducts = snapshot.data ?? [];

                  if (dbProducts.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay produtos registrados en la base de datos.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final categories = [
                    'Todos',
                    ...dbProducts.map((product) => product.category).toSet(),
                  ];

                  final filteredProducts = dbProducts.where((product) {
                    final matchesCategory =
                        _selectedCategory == 'Todos' ||
                        product.category == _selectedCategory;

                    final matchesQuery =
                        query.isEmpty ||
                        product.name.toLowerCase().contains(query) ||
                        product.description.toLowerCase().contains(query) ||
                        product.category.toLowerCase().contains(query);

                    final matchesStock =
                        !_onlyInStock || product.stock > 0;


                    return matchesCategory && matchesQuery && matchesStock;
                  }).toList();

                  filteredProducts.sort((a, b) {
                    switch (_sortBy) {
                      case 'priceAsc':
                        return a.price.compareTo(b.price);
                      case 'priceDesc':
                        return b.price.compareTo(a.price);
                      default:
                        return a.name.compareTo(b.name);
                    }
                  });
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Catálogo de productos',
                              style: TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Buscar productos',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Limpiar búsqueda',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: categories.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final category = categories[index];

                                  return ChoiceChip(
                                    label: Text(category),
                                    selected: _selectedCategory == category,
                                    onSelected: (_) {
                                      setState(() => _selectedCategory = category);
                                    },
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 8),
                      
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                DropdownButton<String>(
                                  value: _sortBy,
                                  items: const [
                                    DropdownMenuItem(value: 'name', child: Text('Nombre')),
                                    DropdownMenuItem(value: 'priceAsc', child: Text('Menor precio.')),
                                    DropdownMenuItem(value: 'priceDesc', child: Text('Mayor precio.'))
                                  ], 
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _sortBy = value);
                                    }
                                  },
                                ),
                                FilterChip(
                                  label: const Text('Solo disponibles'), 
                                  selected: _onlyInStock,
                                  onSelected: (selected) {
                                    setState(() => _onlyInStock = selected);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${filteredProducts.length} '
                              '${filteredProducts.length == 1 ? 'producto' : 'productos'}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: filteredProducts.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'No se encontraron productos.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredProducts.length,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 260,
                                      mainAxisExtent: 360,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                itemBuilder: (context, index) {
                                  return ProductCard(
                                    product: filteredProducts[index]
                                  );
                                },
                              ),
                      )
                    ],
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
