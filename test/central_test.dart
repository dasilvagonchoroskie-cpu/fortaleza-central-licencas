import 'package:central_licencas/api.dart';
import 'package:central_licencas/comum.dart';
import 'package:central_licencas/estado.dart';
import 'package:central_licencas/modelos.dart';
import 'package:central_licencas/telas/pedidos.dart';
import 'package:central_licencas/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor de mentira: responde por rota e anota o que a Central mandou.
class Falso {
  final Map<String, Resposta> respostas = {};
  final List<(String, String, Map<String, dynamic>?)> chamadas = [];
  String senhaCerta = 'senha-de-teste-123';

  Future<Resposta> transporte(String metodo, String endereco, String rota, String senha, Map<String, dynamic>? corpo) async {
    chamadas.add((metodo, rota, corpo));
    if (rota.startsWith('/admin') && senha != senhaCerta) return const Resposta(401, {'ok': false, 'motivo': 'Sem permissão.'});
    final semConsulta = rota.split('?').first;
    return respostas[rota] ?? respostas[semConsulta] ?? const Resposta(200, {'ok': true});
  }
}

const _pedidoJson = {
  'id': 'PEDIDO1',
  'app_id': 'meufrete',
  'app_nome': 'Meu Frete',
  'aparelho': 'N5CP-VDJC-2QUV-QPFS',
  'nome': 'Fulano de Tal',
  'whatsapp': '5564999998888',
  'modelo': 'motorola moto g35',
  'versao': '2.1.0',
  'codigo': '482913',
  'status': 'pendente',
  'criado_em': '2026-10-12T11:58:00.000Z',
  'atualizado_em': '2026-10-12T11:58:00.000Z',
  'neste_aparelho': null,
  'outras': [],
};

Falso _falsoPadrao() {
  final f = Falso();
  f.respostas['/admin/resumo'] = const Resposta(200, {'ok': true, 'pedidos_pendentes': 1, 'pedidos_recentes': []});
  f.respostas['/admin/apps'] = const Resposta(200, {
    'ok': true,
    'apps': [
      {'id': 'meufrete', 'nome': 'Meu Frete', 'link': '', 'chaves': 0, 'pendentes': 1, 'teste_dias': 7},
      {'id': 'taximetro', 'nome': 'Taximetro', 'link': 'https://x/taximetro.apk', 'chaves': 3, 'pendentes': 0, 'teste_dias': 0},
    ],
  });
  f.respostas['/admin/pedidos'] = const Resposta(200, {
    'ok': true,
    'pedidos': [_pedidoJson],
  });
  f.respostas['/admin/licencas'] = const Resposta(200, {'ok': true, 'licencas': []});
  f.respostas['/admin/pedidos/aprovar'] = const Resposta(200, {
    'ok': true,
    'chave': 'ABCD-EFGH-JKLM-NPQR',
    'validade': '2026-11-11T12:00:00.000Z',
    'plano': 'prazo',
    'app_nome': 'Meu Frete',
  });
  return f;
}

Central _central(Falso f) => Central(
      servidor: ServidorAdmin(transporte: f.transporte),
      usarAvisos: false,
      relogio: () => DateTime.utc(2026, 10, 12, 12),
    );

void main() {
  group('textos', () {
    test('WhatsApp', () {
      expect(whatsappNormalizado('(64) 99999-8888'), '5564999998888');
      expect(whatsappNormalizado(''), '');
      expect(whatsappNormalizado('12'), isNull);
      expect(whatsappLegivel('5564999998888'), '(64) 99999-8888');
    });

    test('codigo e tempo', () {
      expect(codigoLegivel('482913'), '482 913');
      final agora = DateTime.utc(2026, 10, 12, 12);
      expect(haQuanto('2026-10-12T11:59:30.000Z', agora), 'agora');
      expect(haQuanto('2026-10-12T11:55:00.000Z', agora), 'há 5 min');
      expect(haQuanto('2026-10-12T09:00:00.000Z', agora), 'há 3 h');
      expect(haQuanto('2026-10-10T12:00:00.000Z', agora), 'há 2 dias');
    });

    test('recado de enviar o app leva o link e explica o pedido', () {
      final r = recadoEnviarApp(nomeApp: 'Meu Frete', link: 'https://x/meufrete.apk', cliente: 'Fulano de Tal');
      expect(r, startsWith('Olá, Fulano!'));
      expect(r, contains('https://x/meufrete.apk'));
      expect(r, contains('Pedir liberação'));
    });

    test('recado da chave leva a chave numa linha so e o prazo', () {
      final r = recadoChave(nomeApp: 'Taximetro', chave: 'YJJ4-3GVY-YMTH-7L6P', validade: '2026-11-11T12:00:00.000Z');
      expect(r, contains('\nYJJ4-3GVY-YMTH-7L6P\n'));
      expect(r, contains('Tenho uma chave de ativação'));
      expect(r, contains('/11/2026'));
    });

    test('licenca: situacao e plano', () {
      final agora = DateTime.utc(2026, 10, 12);
      const livre = LicencaAdmin(chave: 'A', appId: 'x');
      expect(livre.situacaoEm(agora), 'livre');
      expect(livre.planoReal, 'vitalicia');
      const vencida = LicencaAdmin(chave: 'B', appId: 'x', aparelho: 'C', validade: '2026-10-01T00:00:00.000Z', plano: 'teste');
      expect(vencida.situacaoEm(agora), 'vencida');
      expect(planoLegivel(vencida.planoReal), 'Teste grátis');
      const bloqueada = LicencaAdmin(chave: 'D', appId: 'x', aparelho: 'C', bloqueada: true);
      expect(bloqueada.situacaoEm(agora), 'bloqueada');
    });
  });

  group('Central', () {
    test('senha errada nao entra; certa entra e carrega tudo', () async {
      SharedPreferences.setMockInitialValues({});
      final f = _falsoPadrao();
      final c = _central(f);
      await c.carregar();
      expect(c.temSenha, isFalse);
      expect(await c.entrar('curta'), contains('10 caracteres'));
      expect(await c.entrar('senha-errada-123'), contains('Senha errada'));
      expect(c.temSenha, isFalse);
      expect(await c.entrar('senha-de-teste-123'), isNull);
      expect(c.temSenha, isTrue);
      expect(c.apps.length, 2);
      expect(c.pedidos.single.codigo, '482913');
      expect(c.pendentes, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('central.senha'), 'senha-de-teste-123');
    });

    test('liberar manda o pedido, o prazo e a transferencia', () async {
      SharedPreferences.setMockInitialValues({'central.senha': 'senha-de-teste-123'});
      final f = _falsoPadrao();
      final c = _central(f);
      await c.carregar();
      final p = c.pedidos.single;
      final r = await c.aprovar(p, dias: 30);
      expect(r.ok, isTrue);
      final envio = f.chamadas.firstWhere((x) => x.$2 == '/admin/pedidos/aprovar');
      expect(envio.$3, {'id': 'PEDIDO1', 'dias': 30});
      await c.aprovar(p, transferir: 'WXYZ-WXYZ-WXYZ-WXYZ');
      final envio2 = f.chamadas.lastWhere((x) => x.$2 == '/admin/pedidos/aprovar');
      expect(envio2.$3?['transferir'], 'WXYZ-WXYZ-WXYZ-WXYZ');
    });

    test('sem internet avisa sem quebrar', () async {
      SharedPreferences.setMockInitialValues({'central.senha': 'senha-de-teste-123'});
      final c = Central(
        servidor: ServidorAdmin(transporte: (a, b, c, d, e) async => throw Exception('sem rede')),
        usarAvisos: false,
      );
      await c.carregar();
      expect(c.conectado, isFalse);
      expect(c.erroPedidos, contains('Sem internet'));
    });
  });

  testWidgets('tela de pedidos: ve o codigo, escolhe 30 dias e libera', (t) async {
    SharedPreferences.setMockInitialValues({'central.senha': 'senha-de-teste-123'});
    final f = _falsoPadrao();
    final c = _central(f);
    await c.carregar();
    await t.pumpWidget(ChangeNotifierProvider<Central>.value(
      value: c,
      child: MaterialApp(theme: temaCentral(), home: const Scaffold(body: TelaPedidos())),
    ));
    await t.pump();

    expect(find.text('Fulano de Tal'), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('Meu Frete'), findsOneWidget);

    await t.tap(find.text('Liberar'));
    await t.pumpAndSettle();
    expect(find.text('Liberar Fulano de Tal'), findsOneWidget);
    await t.tap(find.text('30 dias'));
    await t.pump();
    await t.tap(find.text('Liberar agora'));
    await t.pumpAndSettle();

    final envio = f.chamadas.firstWhere((x) => x.$2 == '/admin/pedidos/aprovar');
    expect(envio.$3, {'id': 'PEDIDO1', 'dias': 30});
    expect(find.text('Liberado!'), findsOneWidget);
    expect(find.text('Avisar no WhatsApp'), findsOneWidget);
  });
}
