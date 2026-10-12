import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'estado.dart';
import 'telas/entrada.dart';
import 'telas/inicio.dart';
import 'tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider<Central>(
      create: (_) => Central()..carregar(),
      child: const CentralApp(),
    ),
  );
}

class CentralApp extends StatelessWidget {
  const CentralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Central de Licenças',
      debugShowCheckedModeBanner: false,
      theme: temaCentral(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Raiz(),
    );
  }
}

class Raiz extends StatelessWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    if (!c.pronto) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return c.temSenha ? const TelaInicio() : const TelaEntrada();
  }
}
