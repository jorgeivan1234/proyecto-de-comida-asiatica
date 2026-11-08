import 'package:ccomcercio_electronico/models/models.dart';
import 'package:flutter/material.dart';
import '../widgets/product_card.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/hero_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key
  });

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

  @override
  Widget build(BuildContext context) { 

  return FutureBuilder<List<Product>>(
    future: _productsFuture,
    builder: (context, snapshot) {
      if(snapshot.connectionState == ConnectionState.waiting) {
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

      if(!snapshot.hasData){
        return const Scaffold(
          body: Center(child: Text('No se pudieron cargar los prodcutos.')),
        );
      }

      final dbProducts = snapshot.data!;

    final query = searchQuery.trim().toLowerCase();

    final searchResults = dbProducts.where((products){
      return products.name.toLowerCase().contains(query);
    }).toList();

    final featuresProducts = searchResults.take(3).toList();

    final visibleProducts = dbProducts.where((product) {
      final matchesCategory = selectedCategory == 'Todos' ||
        product.category == selectedCategory;
      final matchesName = product.name.toLowerCase().contains(query);
      
      return  matchesCategory && matchesName;
    }).toList();

    final categories = [
      'Todos',
      ...dbProducts.map((product) => product.category).toSet(),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 900 ? 4 : width > 600 ? 3 : 2;

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

                      TextField(
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                        },

                        decoration: const InputDecoration(
                          hintText: 'Buscar productos...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          filled: true, 
                          fillColor: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      const Text(
                        'Categorias',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold
                        ),
                      ),

                      const SizedBox(height: 8),

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

                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Descrubre sabores de Asia',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            const Text(
                              'Explorar nuestros almuerzos y dulces tradicionales',
                              style: TextStyle(
                                color: Colors.white
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                if (categories.contains('Almuezo')){
                                  setState(() => selectedCategory = 'Almuerzo');
                                }
                              },
                              child: const Text(
                                'Ver almuerzos',
                                style: TextStyle(
                                  color: Colors.white
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Destacados',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (featuresProducts.isEmpty)
                        const Text('No hay productos para mostrar.')
                      else
                        SizedBox(
                          height: 340,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: featuresProducts.length,
                            separatorBuilder: (_, __) => const SizedBox( width: 12),
                            itemBuilder: (context, index) {
                              return SizedBox(
                                width: 250,
                                child: ProductCard(product: featuresProducts[index]),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 24),

                      Text(
                        selectedCategory == 'Todos'
                          ? 'Todos los productos'
                          : selectedCategory,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (visibleProducts.isEmpty)
                        Padding(
                          padding: const EdgeInsetsGeometry.all(24),
                          child: Center(child: Text('No se encontraron productos.')),
                        )
                      else 
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(), 
                          itemCount: visibleProducts.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 320,
                          ),
                          itemBuilder: (context, index) {
                            return ProductCard(product: visibleProducts[index]);
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
    });
  }
}