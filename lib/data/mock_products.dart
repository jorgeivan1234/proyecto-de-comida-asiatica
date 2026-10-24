import '../models/product.dart';

final List<Product> products = [
  Product(
    id: 1, 
    name: 'onigiri', 
    description: 'bola de Arroz con un toque de sal', 
    price: 30.0, 
    category: 'Almuerzo', 
    image: 'assets/images/onigiri.jpg', 
    stock: 20
  ),

  Product(
    id: 2, 
    name: 'ongiri de pollo', 
    description: 'bola de arroz rellena de pollo Marinado en salsa Teriyaki', 
    price: 40.0, 
    category: 'Almuerzo', 
    image: 'assets/images/onigiri_pollo.jpg', 
    stock: 15
  ),

  Product(
    id: 3, 
    name: 'Mochi', 
    description: 'dulce japones elaborado a base de arroz glutinoso de grano corto (conocido como mochigome) o su harina (mochiko), agua y un poco de azúcar.', 
    price: 35.0, 
    category: 'Dulce Tradicional', 
    image: 'assets/images/Mochi.jpg', 
    stock: 25
  ),
  Product(
    id: 4, 
    name: 'ongiri de Tempura', 
    description: 'bola de Arroz rellena de Camaron Empanizado y con una porcion de aderezo hecho a base de mayonesa y salsa teriyaki', 
    price: 45.0, 
    category: 'Almuerzo', 
    image: 'assets/images/ongiri_Tempura.jpg', 
    stock: 20
  ),
  Product(
    id: 5,
    name: 'Tayaki de pasta de judias Rojos',
    description: 'pastel con forma de pez relleno de una pasta dulce hecha a base de judias rojas',
    price: 50.0,
    category: 'Dulce Tradicional',
    image: 'assets/images/Tayaki_pasta_judias_Rojos.jpg',
    stock: 20
  ),
 Product(id:6, 
        name: 'Monaka', 
        description: 'La monaka consiste en una oblea rellena de pasta de judías dulces. Las obleas vienen en diferentes formas y tamaños, desde sencillas y redondas hasta otras con diseños más elaborados. Una variante moderna muy popular de la monaka se rellena con helado', 
        price: 42, 
        category: 'Dulce Tradicional', 
        image: 'assets/images/Monaka.jpg', 
        stock: 30
        )
];