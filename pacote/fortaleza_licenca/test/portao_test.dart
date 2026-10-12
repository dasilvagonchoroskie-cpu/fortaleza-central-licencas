import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortaleza_licenca/fortaleza_licenca.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';
import 'vetores.dart';

Future<void> tocar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
}

Future<void> assentar(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}

Widget app(ControleLicenca c, {bool ativo = true}) => MaterialApp(
      home: PortaoLicenca(
        controle: c,
        ativo: ativo,
        icone: Icons.local_shipping,
        child: const Scaffold(body: Center(child: Text('APP ABERTO'))),
      ),
    );

void main() {
  testWidgets('cliente pede liberacao, ve o codigo e o app abre quando a Central libera', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()
      ..responder('/v2/status', negada(preco: 'R\$ 150 à vista'))
      ..responder('/v2/pedir', negada(pedido: pedidoPendente(), preco: 'R\$ 150 à vista'));
    final c = novoControle(s);
    await t.pumpWidget(app(c));
    await assentar(t);

    expect(find.text('APP ABERTO'), findsNothing);
    expect(find.text('Meu Frete'), findsOneWidget);
    expect(find.text('Valor: R\$ 150 à vista'), findsOneWidget);
    expect(find.text(codigoA), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'Seu nome'), 'Fulano');
    await t.enterText(find.widgetWithText(TextField, 'Seu WhatsApp com DDD'), '64 99999-8888');
    await tocar(t, find.text('Pedir liberação').last);
    await assentar(t);

    expect(find.text('Pedido enviado'), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('Falar no WhatsApp'), findsOneWidget);

    // A Central liberou.
    s.passarAResponder('/v2/status', liberada(vitaliciaA));
    await tocar(t, find.text('Já paguei — conferir agora'));
    await assentar(t);

    expect(find.text('APP ABERTO'), findsOneWidget);
    expect(find.text('Pronto! Meu Frete liberado neste aparelho.'), findsOneWidget);
  });

  testWidgets('aparelho liberado abre direto no app', (t) async {
    SharedPreferences.setMockInitialValues({
      'fds_licenca.meufrete.liberacao': jsonEncode(vitaliciaA.paraJson()),
      'fds_licenca.meufrete.conferido_em': relogioPadrao.toIso8601String(),
    });
    final c = novoControle(ServidorFalso());
    await t.pumpWidget(app(c));
    await assentar(t);
    expect(find.text('APP ABERTO'), findsOneWidget);
  });

  testWidgets('portao desligado (versao da Play Store) abre direto', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso();
    final c = novoControle(s);
    await t.pumpWidget(app(c, ativo: false));
    await t.pump();
    expect(find.text('APP ABERTO'), findsOneWidget);
    expect(s.chamadas, isEmpty);
  });

  testWidgets('teste gratis aparece e libera na hora', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()
      ..responder('/v2/status', negada(teste: true, testeDias: 7))
      ..responder('/v2/teste', liberada(testeA));
    final c = novoControle(s);
    await t.pumpWidget(app(c));
    await assentar(t);
    expect(find.text('Começar teste grátis de 7 dias'), findsOneWidget);
    await tocar(t, find.text('Começar teste grátis de 7 dias'));
    await assentar(t);
    expect(find.text('APP ABERTO'), findsOneWidget);
  });

  testWidgets('sem internet mostra o aviso', (t) async {
    SharedPreferences.setMockInitialValues({});
    final c = novoControle(ServidorFalso());
    await t.pumpWidget(app(c));
    await assentar(t);
    expect(find.textContaining('Sem internet'), findsOneWidget);
    expect(find.text('Pedir liberação'), findsNWidgets(2));
  });
}
