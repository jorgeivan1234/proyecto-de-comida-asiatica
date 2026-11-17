import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<Product>> _productsFuture;
  late Future <Map<String, num>> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _loadProducts();
    _metricsFuture = _loadMetrics();
  }

  Future<List<Product>> _loadProducts() async {
    final rows = await Supabase.instance.client
      .from('products')
      .select('id, name, description, price, category, image, stock')
      .order('name');

    return rows.map<Product>((row){
      return Product(
        id: row['id'] as int, 
        name: row['name']as String, 
        description: row['description'] as String, 
        price:( row['price'] as num).toDouble(), 
        category: row['category'] as String, 
        image: row['image'] as String, 
        stock: row['stock']as int,
      );
    }).toList();
  }
  

  Future<void> _openProductForm({Product? product}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductFormDialog(product: product),
    );

    if (saved == true && mounted) {
      setState((){
        _productsFuture = _loadProducts();
      });
    }
  }

  Future<Map<String, num>> _loadMetrics() async {
    final response = await Supabase.instance.client.rpc(
      'get_admin_sales_metrics',
    );

    if (response is! Map) {
      throw const FormatException('Respuesta invalida al cargar metricas.');
    } 

    final data = Map<String, dynamic>.from(response);
    final totalSales = data['total_sales'];
    final averageTicket = data['average_ticket'];

    if (totalSales is! num || averageTicket is! num) {
      throw const FormatException('Faltan datos de venta en la respuesta.');
    }

    return {
      'total_sales': totalSales,
      'average_ticket': averageTicket,
    };
  }

  Widget _buildMetrics() {
    return FutureBuilder<Map<String, num>>(
      future: _metricsFuture, 
      builder: (context, snapshot) {
        if(snapshot.connectionState == ConnectionState.waiting){
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
      
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'No se pudieron cargar las metricas: ${snapshot.error}',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState((){
                      _metricsFuture = _loadMetrics();
                    });
                  },
                  child: const Text('Reintentar'),
                )
              ],
            ),
          );
        }

        final metrics = snapshot.data!;
        final totalSales = metrics['total_sales']!.toDouble();
        final averageTicket = metrics['average_ticket']!.toDouble();

        final cards = [
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Ventas acumuladas'),
              subtitle: Text('\$${totalSales.toStringAsFixed(2)} MXN'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Ticket_promedio'),
              subtitle: Text('\$${averageTicket.toStringAsFixed(2)} MXN'),
            ),
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 520) {
                return Column(children: cards);
              }
              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              );
            },
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(),
        icon: const Icon(Icons.add), 
        label: const Text('Nuevo producto'),
      ),
      body: SafeArea(
        child: Column(
          
          children: [
            
            const AppNavigationBar(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Administrar productos',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),

            _buildMetrics(),
            
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Error al cargar productos: ${snapshot.error}'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _productsFuture = _loadProducts();
                              });
                            }, 
                            child: const Text('Volver a internar'),
                          ),
                        ],
                      ),
                    );
                  }

                  final products = snapshot.data ?? [];

                  if (products.isEmpty) {
                    return const Center(
                      child: Text('Todavia no hay producto.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];

                      return Card(
                        child: ListTile(
                          leading: Image.asset(
                            product.image,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _,) => const Icon(Icons.image_not_supported),

                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.category} . '
                            '\$${product.price.toStringAsFixed(2)} .'
                            'Existencias: ${product.stock}\n'
                            '${product.description}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            onPressed: () => _openProductForm(product: product),
                            icon: const Icon(Icons.edit)
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Gestionar pedidos.'),
              onTap: () => context.push('/admin/orders'),
            )
          ],
        ),
      ),
    );
  }
}


class ProductFormDialog extends StatefulWidget {

  final Product? product;

  const ProductFormDialog({
    super.key,
    this.product, 
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _imageController;
  late final TextEditingController _stockController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descripcionController = TextEditingController(text: product?.description ?? '');
    _priceController = TextEditingController(text: product?.price.toString() ?? '');
    _categoryController = TextEditingController(text: product?.category ?? '');
    _imageController = TextEditingController(text: product?.image ?? '');
    _stockController = TextEditingController(text: product?.stock.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descripcionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _imageController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }
    return null;
  }

  String? _validPrice(String? value) {
    final price = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (price == null || price < 0) {
      return 'Ingresa existencia enteras, iguales o mayores a 0.';
    }
    return null;
  }

  String? _validStock(String? value) {
    final stock = int.tryParse((value ?? '').trim());
    if (stock == null || stock < 0) {
      return 'Ingresa existencia enteras, iguales o mayores a 0.';
    }
    return null;
  }


  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final values = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descripcionController.text.trim(),
      'price':double.parse(_priceController.text.trim().replaceAll(',', '.')),
      'category': _categoryController.text.trim(),
      'image': _imageController.text.trim(),
      'stock': int.parse(_stockController.text.trim()),
    };

    try {
      final product = Supabase.instance.client.from('products');

      if (widget.product == null) {
        await product.insert(values);
      } else {
        await product.update(values).eq('id', widget.product!.id);
      }

      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${error.message}'))
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocurrio un error: ${error}'))
      );    
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar producto' : 'Nuevo producto'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombres'),
                  validator: _requiredText,
                ),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                  maxLines: 3,
                  validator: _requiredText,
                ),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validPrice,
                ),
                TextFormField(
                  controller: _imageController,
                  decoration: const InputDecoration(
                    labelText: 'Ruta de imagen (asset)',
                    hintText: 'assets/images/ramen_miso.jpg'
                  ),
                  validator: _requiredText,
                ),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(labelText: 'Existencia'),
                  keyboardType: TextInputType.number,
                  validator: _validStock,
                ),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Categorias'),
                  validator: _requiredText,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false), 
          child: const Text('cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save, 
          child: Text(_isSaving ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}