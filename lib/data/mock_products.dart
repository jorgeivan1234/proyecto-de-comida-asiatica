import '../models/product.dart';

final List<Product> products = [
  Product(
    id: 1, 
    name: 'ongiri', 
    description: 'bola de Arroz con un toque de sal', 
    price: 35.0, 
    category: 'Almuerzo', 
    image: 'https://bonviveur.com/es/recetas/onigiri', 
    stock: 20
  ),

  Product(
    id: 2, 
    name: 'ongiri de pollo', 
    description: 'bola de arroz rellena de pollo Marinado en salsa Teriyaki', 
    price: 40.0, 
    category: 'Almuerzo', 
    image: 'https://www.momentosfriko.com/recetas/onigris-de-pollo', 
    stock: 15
  ),

  Product(
    id: 3, 
    name: 'Mochi', 
    description: 'dulce japones elaborado a base de arroz glutinoso de grano corto (conocido como mochigome) o su harina (mochiko), agua y un poco de azúcar.', 
    price: 35.0, 
    category: 'Dulce Tradicional', 
    image: 'https://www.myamericanshop.es/blogs/blog-de-mi-tienda-americana/mochi-c-est-quoi-et-quel-gout-ca-a', 
    stock: 25
  ),
  Product(
    id: 4, 
    name: 'ongiri de Tempura', 
    description: 'bola de Arroz rellena de Camaron Empanizado y con una porcion de aderezo hecho a base de mayonesa y salsa teriyaki', 
    price: 45.0, 
    category: 'Almuerzo', 
    image: 'https://www.snapcalorie.com/nutrition/es/shrimp_tempura_onigiri_nutrition.html', 
    stock: 20
  ),
  Product(
    id: 5,
    name: 'Tayaki de pasta de judias Rojos',
    description: 'pastel con forma de pez relleno de una pasta dulce hecha a base de judias rojas',
    price: 50.0,
    category: 'Dulce Tradicional',
    image: 'https://www.muyjapones.com/wp-content/uploads/2020/04/Taiyaki-1.jpg',
    stock: 20
  ),
 Product(id:6, 
        name: 'Monaka (最中)', 
        description: 'La monaka consiste en una oblea rellena de pasta de judías dulces. Las obleas vienen en diferentes formas y tamaños, desde sencillas y redondas hasta otras con diseños más elaborados. Una variante moderna muy popular de la monaka se rellena con helado', 
        price: 42, 
        category: 'Dulce Tradicional', 
        image: 'https://www.japan-guide.com/g9/2312_monaka.jpg', 
        stock: 30
        )
];