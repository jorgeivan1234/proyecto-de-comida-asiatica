import 'package:ccomcercio_electronico/widgets/app_drawer.dart';
import 'package:ccomcercio_electronico/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppNavigationBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Aviso de Privacidad',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Última actualización: Noviembre de 2026',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'En Asiatic - Bite, protegemos tus datos personales. '
                    'Este Aviso de Privacidad describe cómo recopilamos, utilizamos y protegemos la información '
                    'que nos proporcionas al utilizar nuestra aplicación y portal comercial.',
                    style: TextStyle(height: 1.5),
                  ),

                  SizedBox(height: 16),

                  Text(
                    '1. Datos que recopilamos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Recopilamos tu correo electrónico, nombre y teléfono de contacto. '
                    'Si solicitas entrega a domicilio, guardamos la dirección y las referencias que '
                    'proporcionas para poder entregar tu pedido. La dirección se comparte solo con '
                    'el personal autorizado que gestiona el pedido. Nunca almacenamos datos bancarios '
                    'ni números de tarjetas de crédito en nuestra base de datos.',
                    style: TextStyle(height: 1.5),
                  ),

                  SizedBox(height: 16),

                  Text(
                    '2. Finalidad del tratamiento de datos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Tus datos son utilizados para la gestión de cuentas, procesamiento, '
                    'seguimiento y entrega de tus pedidos de comida asiática.',
                    style: TextStyle(height: 1.5),
                  ),

                  SizedBox(height: 16),

                  Text(
                    '3. Datos de ubicación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'La aplicación no solicita ni recopila la ubicación GPS de tu dispositivo. '
                    'Para entregas usamos la dirección que escribes al hacer el pedido. La pantalla '
                    'de seguimiento muestra actualmente una ubicación de demostración y no la posición '
                    'real de un repartidor.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const AppNavigationBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Términos y condiciones',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Última actualización: Noviembre de 2026',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Bienvenido a Asiatic - Bite. Al realizar un pedido en nuestra plataforma, '
                    'aceptas los siguientes términos y condiciones de servicio.',
                    style: TextStyle(height: 1.5),
                  ),

                  SizedBox(height: 16),

                  Text(
                    '1. Envíos y entregas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Ofrecemos dos modalidades: Recoger en el local (sin costo) y entrega a domicilio '
                    '(gratis por lanzamiento). Los tiempos estimados de preparación y entrega se muestran '
                    'al confirmar tu pedido.',
                    style: TextStyle(height: 1.5),
                  ),

                  SizedBox(height: 16),

                  Text(
                    '2. Cancelaciones y reembolsos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Puedes cancelar mientras el pedido esté pendiente de preparación. Cuando la cocina '
                    'comience a prepararlo, solo se aceptará la cancelación si todos los productos del '
                    'pedido fueron marcados como recuperables por el negocio. No se puede cancelar cuando '
                    'el pedido está listo para recoger, ya fue recogido, entregado o salió con el repartidor. '
                    'La disponibilidad del botón se valida al confirmar la cancelación.',
                    style: TextStyle(height: 1.5),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Si un pedido pagado en línea es cancelado, puedes solicitar el reembolso al medio '
                    'de pago original o elegir saldo de tienda. El reembolso al medio original depende '
                    'de los tiempos de procesamiento de Mercado Pago. El saldo de tienda se acredita a '
                    'tu cuenta para futuras compras; no es transferible ni retirable en efectivo. '
                    'Si se pagó en efectivo, la devolución la gestiona manualmente el dueño del negocio.',
                    style: TextStyle(height: 1.5),
                  ),

                  SizedBox(height: 16),

                  Text(
                    '3. Dirección y seguimiento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Usamos la dirección proporcionada únicamente para preparar y entregar el pedido. '
                    'La aplicación no obtiene la ubicación GPS del cliente ni muestra actualmente la '
                    'ubicación GPS real del repartidor; cualquier mapa de seguimiento es ilustrativo.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
