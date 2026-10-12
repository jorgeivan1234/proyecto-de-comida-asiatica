import 'dart:collection';

import 'package:ccomcercio_electronico/data/mock_products.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';

class ProductDetailsScreen extends StatelessWidget {

  final Product product;


  const ProductDetailsScreen({
    super.key, 
    required this.product, 
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles productos'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.network(
                product.image,
                width: 250,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace){
                  return const SizedBox(
                    height: 250,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 50),
                    ),
                  );
                },
              ),
              Padding(
                padding: EdgeInsetsGeometry.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold
                      ),
                    ),

                    const SizedBox(height: 8),
                    
                    Text(
                      '\$${product.price.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      product.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    
                    const SizedBox(height: 16),

                    Text(
                      'Categoria: ${product.category}',
                    ),
                    
                    const SizedBox(height: 8),

                    Text(
                      'Categoria: ${product.stock}',
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}