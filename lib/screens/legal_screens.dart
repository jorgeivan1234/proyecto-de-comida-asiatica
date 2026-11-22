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
                    'Ulitma actualizacion: Noviembre de 2026',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.grey),

                  ),
                  
                  SizedBox(height: 16),

                  Text(
                    'En Asiatic - Bite, protegemos tus datos personales.'
                    'Este Aviso de Privacidad describe como recopilamos, utilizamos y protegemos la informacion '
                    'que nos proporcionas al utilizar nuestra aplicacion y portal comercial.',
                    style: TextStyle(height: 1.5),
                  ),
                  
                  SizedBox(height: 16),

                  Text(
                    '1. Datos que recopilamos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  
                  SizedBox(height: 8),

                  Text(
                    'Recopilamos tu correo electronico al registrate, asi como la informaicon necesaria '
                    'Para procesar tus pedidos (nombre, direccion de entrega y telefono de contacto). '
                    'Nunca almacenamos datos bancarios ni numeros de tarjetas de credito en nuestra base de datos.',
                    style: TextStyle(height: 1.5),
                  ), 

                  SizedBox(height: 16),

                  Text(
                    '2. Finalidad del tratamiento de datos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  
                  SizedBox(height: 8),

                  Text(
                    'Tus datos son utilizados exclusivamente para la gestion de cuentas, procesamiento, '
                    'seguimiento y entrega de tus pedidos de comida asiatica.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              )
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
                    'Terminos y condiciones',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Ulitma actualizacion: Noviembre de 2026',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.grey),

                  ),
                  
                  SizedBox(height: 16),

                  Text(
                    'Binevenido a Asiatic - Bite. Al realizar un pedido en nuestra plataforma, '
                    'aceptas los siguientes terminos y condiciones de servicio.',
                    style: TextStyle(height: 1.5),
                  ),
                  
                  SizedBox(height: 16),

                  Text(
                    '1. Envio y Entregas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  
                  SizedBox(height: 8),

                  Text(
                    'Ofrecemos dos modalidades: Recoger en el local (sin costo) y entrega a domicilio '
                    '(gratis por lanzamiento). Los tiempos estimados de preparacion y entrega se muestran '
                    'al confirmar tu pedido.',
                    style: TextStyle(height: 1.5),
                  ), 

                  SizedBox(height: 16),

                  Text(
                    '2. cancelaciones y Devoluciones',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  
                  SizedBox(height: 8),

                  Text(
                    'las cancelaciones solo se permiten antes de que el pedido cambie al estado de "En peparacion". '
                    'Debido a la naturaleza de los alimentos preparados, no se aceptan devoluciones una vezz encargado el producto, '
                    'salvo por errores comprobables en el contenido del pedido.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              )
            ),
          ],
        ),
      ),
    );
  }
}