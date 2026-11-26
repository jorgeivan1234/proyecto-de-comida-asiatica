import 'package:ccomcercio_electronico/models/product.dart';
import 'package:ccomcercio_electronico/screens/product_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('product details content is laid out within the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(762, 870);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsScreen(
          product: Product(
            id: 1,
            name: 'Ramen de prueba',
            description: 'Descripción de prueba',
            price: 99,
            category: 'Almuerzos',
            image: 'assets/icon/logo.png',
            stock: 5,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ramen de prueba'), findsOneWidget);
    expect(find.text('Descripción de prueba'), findsOneWidget);
    expect(find.text('5 disponibles'), findsOneWidget);

    final cardRect = tester.getRect(find.byType(Card).first);
    expect(cardRect.width, 722);
    expect(cardRect.height, greaterThan(0));
    expect(cardRect.left, 20);
  });
}
