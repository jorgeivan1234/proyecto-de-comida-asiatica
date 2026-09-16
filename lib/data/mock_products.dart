import '../models/product.dart';

final List<Product> products = [
  Product(
    id: 1, 
    name: 'ongiri', 
    description: 'onigiri relleno de camaron', 
    price: 45.0, 
    category: 'onigiri', 
    image: 'https://bonviveur.com/es/recetas/onigiri', 
    stock: 20
  ),

  Product(
    id: 2, 
    name: 'ongiri de pollo', 
    description: 'onigiri relleno de polo con salsa tariyaki', 
    price: 40.0, 
    category: 'onigiri', 
    image: 'https://www.momentosfriko.com/recetas/onigris-de-pollo', 
    stock: 15
  ),

  Product(
    id: 3, 
    name: 'Mochi', 
    description: 'Dulce japones de textura suave.', 
    price: 35.0, 
    category: 'Postres', 
    image: 'https://www.myamericanshop.es/blogs/blog-de-mi-tienda-americana/mochi-c-est-quoi-et-quel-gout-ca-a', 
    stock: 25
  ),
];