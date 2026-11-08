import 'package:ccomcercio_electronico/config/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/cart_provider.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main () async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || publishableKey.isEmpty){
    throw StateError('Faltan SUPABASE_URL o SUPABASE_PUBLISHABLE_KEY');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: publishableKey
  );

    runApp(const MainApp());

}

class MainApp extends StatelessWidget {

  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Comida asiatica',
        routerConfig: appRouter,
      ),
    );
  }
}
