import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortaleza_licenca/fortaleza_licenca.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';
import 'vetores.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> guardada(Liberacao l, {DateTime? conferidoEm}) => {
        'fds_licenca.meufrete.liberacao': jsonEncode(l.paraJson()),
        'fds_licenca.meufrete.conferido_em': (conferidoEm ?? relogioPadrao.subtract(const Duration(hours: 1))).toIso8601String(),
      };

  test('aparelho novo: pergunta ao servidor e fica na tela de pedido', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()..responder('/v2/status', negada());
    final c = novoControle(s);
    await c.iniciar();
    expect(c.estado, EstadoLicenca.bloqueado);
    expect(c.situacao, 'sem_licenca');
    expect(c.codigoAparelho, codigoA);
    expect(c.contatoWhatsapp, '5564996472794');
    expect(s.rotas, ['/v2/status']);
    final corpo = s.chamadas.single.$2;
    expect(corpo['app_id'], 'meufrete');
    expect(corpo['aparelho'], codigoA);
    expect(corpo['versao'], '2.1.0');
    expect(corpo['modelo'], 'motorola moto g35');
    expect(corpo.containsKey('legado'), isFalse);
  });

  test('pedido -> codigo de verificacao -> Central libera -> app abre sozinho', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()
      ..responder('/v2/status', negada())
      ..responder('/v2/pedir', negada(pedido: pedidoPendente()));
    final c = novoControle(s);
    await c.iniciar();

    expect(await c.pedirLiberacao(nome: ' Fulano ', whatsapp: '(64) 99999-8888'), isTrue);
    expect(c.pedido?.codigo, '482913');
    expect(c.pedido?.pendente, isTrue);
    expect(c.estado, EstadoLicenca.bloqueado);
    final corpo = s.chamadas.last.$2;
    expect(corpo['nome'], 'Fulano');
    expect(corpo['whatsapp'], '5564999998888');
    expect(c.mensagemParaVendedor, contains('Meu Frete'));
    expect(c.mensagemParaVendedor, contains('482 913'));
    expect(c.linkWhatsApp.toString(), startsWith('https://wa.me/5564996472794?text='));

    // A Central liberou: na proxima pergunta o app abre.
    s.passarAResponder('/v2/status', liberada(vitaliciaA));
    await c.conferirAgora(silencioso: true);
    expect(c.estado, EstadoLicenca.liberado);
    expect(c.consumirAvisoLiberado(), isTrue);
    expect(c.consumirAvisoLiberado(), isFalse);
    expect(c.diasRestantes, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fds_licenca.meufrete.liberacao'), isNotNull);
    expect(prefs.getString('fds_licenca.meufrete.nome'), 'Fulano');
  });

  test('pedido com nome ou WhatsApp ruim nem vai ao servidor', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()..responder('/v2/status', negada());
    final c = novoControle(s);
    await c.iniciar();
    expect(await c.pedirLiberacao(nome: 'F', whatsapp: '64999998888'), isFalse);
    expect(c.erro, contains('nome'));
    expect(await c.pedirLiberacao(nome: 'Fulano', whatsapp: '999'), isFalse);
    expect(c.erro, contains('DDD'));
    expect(s.rotas, ['/v2/status']);
  });

  test('liberado abre SEM internet e nao pergunta de novo antes de 6 horas', () async {
    SharedPreferences.setMockInitialValues(guardada(vitaliciaA));
    final s = ServidorFalso();
    final c = novoControle(s);
    await c.iniciar();
    await esperar();
    expect(c.estado, EstadoLicenca.liberado);
    expect(s.chamadas, isEmpty);
  });

  test('depois de 6 horas, renova em silencio (sem atrapalhar)', () async {
    SharedPreferences.setMockInitialValues(guardada(vitaliciaA, conferidoEm: relogioPadrao.subtract(const Duration(hours: 7))));
    final s = ServidorFalso()..responder('/v2/status', liberada(vitaliciaA));
    final c = novoControle(s);
    await c.iniciar();
    expect(c.estado, EstadoLicenca.liberado);
    await esperar();
    expect(s.rotas, ['/v2/status']);
    expect(c.estado, EstadoLicenca.liberado);
    expect(c.consumirAvisoLiberado(), isFalse);
  });

  test('sem internet na renovacao: continua liberado', () async {
    SharedPreferences.setMockInitialValues(guardada(vitaliciaA, conferidoEm: relogioPadrao.subtract(const Duration(days: 30))));
    final s = ServidorFalso();
    final c = novoControle(s);
    await c.iniciar();
    await esperar();
    expect(c.estado, EstadoLicenca.liberado);
    expect(s.rotas, ['/v2/status']);
  });

  test('erro do servidor nunca trava quem esta liberado', () async {
    SharedPreferences.setMockInitialValues(guardada(vitaliciaA, conferidoEm: relogioPadrao.subtract(const Duration(days: 1))));
    final s = ServidorFalso()
      ..responder('/v2/status', const RespostaBruta(500, {'ok': false, 'motivo': 'Erro no servidor: banco fora'}));
    final c = novoControle(s);
    await c.iniciar();
    await esperar();
    expect(c.estado, EstadoLicenca.liberado);
    expect(c.bloqueioPendente, isFalse);
  });

  test('reinstalou ou perdeu os dados: o servidor devolve a liberacao sozinho', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()..responder('/v2/status', liberada(vitaliciaA));
    final c = novoControle(s);
    await c.iniciar();
    expect(c.estado, EstadoLicenca.liberado);
    expect(c.consumirAvisoLiberado(), isFalse);
  });

  test('liberacao copiada para OUTRO celular nao abre', () async {
    SharedPreferences.setMockInitialValues(guardada(vitaliciaA));
    final s = ServidorFalso()..responder('/v2/status', negada());
    final c = novoControle(s, id: 'aparelho-de-teste-b');
    await c.iniciar();
    expect(c.codigoAparelho, codigoB);
    expect(c.estado, EstadoLicenca.bloqueado);
    expect(c.situacao, 'sem_licenca');
  });

  test('liberacao adulterada (prazo esticado) nao abre', () async {
    final mexida = Liberacao(
      appId: 'meufrete',
      aparelho: codigoA,
      ate: '2099-01-01T00:00:00.000Z',
      plano: prazoA.plano,
      vence: '2099-01-01T00:00:00.000Z',
      assinatura: prazoA.assinatura,
    );
    SharedPreferences.setMockInitialValues(guardada(mexida));
    final s = ServidorFalso();
    final c = novoControle(s);
    await c.iniciar();
    expect(c.estado, EstadoLicenca.bloqueado);
  });

  test('90 dias sem internet: pede para ligar a internet uma vez', () async {
    SharedPreferences.setMockInitialValues(guardada(vitaliciaA));
    final s = ServidorFalso();
    final c = novoControle(s, agora: DateTime.utc(2027, 1, 11));
    await c.iniciar();
    expect(c.estado, EstadoLicenca.bloqueado);
    expect(c.situacao, 'confirmar');
    expect(c.semInternet, isTrue);
    // Ligou a internet: volta na hora.
    s.passarAResponder('/v2/status', liberada(vitaliciaA));
    await c.conferirAgora();
    expect(c.estado, EstadoLicenca.liberado);
  });

  test('relogio do celular voltado para tras: nao vale sem internet', () async {
    SharedPreferences.setMockInitialValues({
      ...guardada(vitaliciaA),
      'fds_licenca.meufrete.maior_data': '${relogioPadrao.add(const Duration(days: 10)).millisecondsSinceEpoch}',
    });
    final s = ServidorFalso();
    final c = novoControle(s);
    await c.iniciar();
    expect(c.estado, EstadoLicenca.bloqueado);
    expect(c.situacao, 'relogio');
  });

  test('servidor bloqueia com o app em uso: nao derruba a tela, trava na proxima abertura', () async {
    SharedPreferences.setMockInitialValues(guardada(vitaliciaA, conferidoEm: relogioPadrao.subtract(const Duration(days: 1))));
    final s = ServidorFalso()
      ..responder('/v2/status', negada(situacao: 'bloqueada', motivo: 'A licença deste aparelho foi bloqueada.'));
    final c = novoControle(s);
    await c.iniciar();
    await esperar();
    expect(c.estado, EstadoLicenca.liberado);
    expect(c.bloqueioPendente, isTrue);

    final depois = novoControle(ServidorFalso());
    await depois.iniciar();
    expect(depois.estado, EstadoLicenca.bloqueado);
    expect(depois.situacao, 'bloqueada');
    expect(depois.motivo, contains('bloqueada'));
  });

  test('teste gratis: libera na hora e avisa quantos dias faltam', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()
      ..responder('/v2/status', negada(teste: true, testeDias: 7))
      ..responder('/v2/teste', liberada(testeA));
    final c = novoControle(s);
    await c.iniciar();
    expect(c.testeDisponivel, isTrue);
    expect(c.infoApp.testeDias, 7);
    expect(await c.comecarTeste(), isTrue);
    expect(c.estado, EstadoLicenca.liberado);
    expect(c.liberacao?.teste, isTrue);
    expect(c.diasRestantes, 8);
  });

  test('teste acabou: a tela explica', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()
      ..responder('/v2/status', negada(situacao: 'teste_acabou', motivo: 'O seu teste grátis terminou.'));
    final c = novoControle(s);
    await c.iniciar();
    expect(c.situacao, 'teste_acabou');
    expect(c.motivo, contains('teste'));
  });

  test('chave curta achada na mensagem inteira do WhatsApp', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()
      ..responder('/v2/status', negada())
      ..responder('/v2/ativar', liberada(prazoA));
    final c = novoControle(s);
    await c.iniciar();
    expect(await c.ativarComChave('Sua chave de ativação:\nyjj4-3gvy-ymth-7l6p\nobrigado'), isTrue);
    expect(s.chamadas.last.$2['chave'], 'YJJ4-3GVY-YMTH-7L6P');
    expect(c.estado, EstadoLicenca.liberado);
    expect(c.diasRestantes, 20);
  });

  test('chave recusada pelo servidor mostra o motivo', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso()
      ..responder('/v2/status', negada())
      ..responder('/v2/ativar', const RespostaBruta(409, {
        'ok': false,
        'servico': 'fortaleza-licencas',
        'motivo': 'Esta chave já está em uso em outro celular.',
      }));
    final c = novoControle(s);
    await c.iniciar();
    expect(await c.ativarComChave('YJJ4-3GVY-YMTH-7L6P'), isFalse);
    expect(c.erro, contains('outro celular'));
    expect(c.estado, EstadoLicenca.bloqueado);
    expect(await c.ativarComChave('abc'), isFalse);
    expect(c.erro, contains('16'));
  });

  test('sem conseguir ler o aparelho: avisa e nao inventa codigo', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ServidorFalso();
    final c = novoControle(s, id: '');
    await c.iniciar();
    expect(c.estado, EstadoLicenca.bloqueado);
    expect(c.situacao, 'sem_aparelho');
    expect(s.chamadas, isEmpty);
  });

  group('taximetro 3.1 (liberacao antiga)', () {
    const configTaxi = ConfiguracaoLicenca(appId: 'taximetro', nomeApp: 'Taxímetro', prefixoLegado: 'taxi.licenca');
    const idTaxi = 'teste-automatico-nao-e-um-aparelho';

    test('quem ja usa continua liberado sem internet', () async {
      SharedPreferences.setMockInitialValues({
        'taxi.licenca.assinatura': chaveComprida,
        'taxi.licenca.validade': 'sempre',
        'taxi.licenca.chave': 'YJJ4-3GVY-YMTH-7L6P',
      });
      final s = ServidorFalso();
      final c = novoControle(s, id: idTaxi, config: configTaxi);
      await c.iniciar();
      await esperar();
      expect(c.codigoAparelho, codigoTaximetroTeste);
      expect(c.estado, EstadoLicenca.liberado);
      expect(c.chaveGuardada, 'YJJ4-3GVY-YMTH-7L6P');
      // Com internet, leva a liberacao antiga para virar licenca nova.
      expect(s.rotas, ['/v2/status']);
      final legado = s.chamadas.single.$2['legado'] as Map;
      expect(legado['assinatura'], chaveComprida);
      expect(legado['validade'], 'sempre');
    });

    test('liberacao antiga com prazo vale ate o prazo', () async {
      SharedPreferences.setMockInitialValues({
        'taxi.licenca.assinatura': liberacaoComPrazo,
        'taxi.licenca.validade': '2026-12-31',
      });
      final dentro = novoControle(ServidorFalso(), id: idTaxi, config: configTaxi);
      await dentro.iniciar();
      expect(dentro.estado, EstadoLicenca.liberado);
    });

    test('liberacao antiga com prazo vencido nao abre sem internet', () async {
      SharedPreferences.setMockInitialValues({
        'taxi.licenca.assinatura': liberacaoComPrazo,
        'taxi.licenca.validade': '2026-12-31',
      });
      final fora = novoControle(ServidorFalso(), id: idTaxi, config: configTaxi, agora: DateTime.utc(2027, 1, 5));
      await fora.iniciar();
      expect(fora.estado, EstadoLicenca.bloqueado);
      expect(fora.situacao, 'confirmar');
    });

    test('bloqueio da Central vale mesmo para quem tinha a liberacao antiga', () async {
      SharedPreferences.setMockInitialValues({'taxi.licenca.assinatura': chaveComprida, 'taxi.licenca.validade': 'sempre'});
      final s = ServidorFalso()..responder('/v2/status', negada(situacao: 'bloqueada', motivo: 'Bloqueada.'));
      final c = novoControle(s, id: idTaxi, config: configTaxi);
      await c.iniciar();
      await esperar();
      expect(c.bloqueioPendente, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('taxi.licenca.assinatura'), isNull);
      final depois = novoControle(ServidorFalso(), id: idTaxi, config: configTaxi);
      await depois.iniciar();
      expect(depois.estado, EstadoLicenca.bloqueado);
      expect(depois.situacao, 'bloqueada');
    });

    test('chave comprida do gerador de reserva ativa sem internet', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ServidorFalso();
      final c = novoControle(s, id: idTaxi, config: configTaxi);
      await c.iniciar();
      expect(c.estado, EstadoLicenca.bloqueado);
      expect(await c.ativarComChave('Sua chave:\n$chaveComprida\n'), isTrue);
      expect(c.estado, EstadoLicenca.liberado);
    });

    test('chave comprida de outro aparelho e recusada', () async {
      SharedPreferences.setMockInitialValues({});
      final c = novoControle(ServidorFalso(), id: 'outro-celular', config: configTaxi);
      await c.iniciar();
      expect(await c.ativarComChave(chaveComprida), isFalse);
      expect(c.erro, contains('não serve'));
    });
  });
}
