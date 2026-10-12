import 'package:fortaleza_licenca/fortaleza_licenca.dart';

import 'vetores.dart';

/// Servidor de mentira: devolve as respostas da fila de cada rota (a
/// ultima fica repetindo) e anota tudo o que o app pediu.
class ServidorFalso {
  final Map<String, List<Object>> _respostas = {};
  final List<(String, Map<String, dynamic>)> chamadas = [];

  /// Sem resposta na fila: como se estivesse sem internet.
  Object padrao = const SemInternet();

  void responder(String rota, Object resposta) => _respostas.putIfAbsent(rota, () => []).add(resposta);

  /// Troca tudo o que a rota responde daqui pra frente.
  void passarAResponder(String rota, Object resposta) => _respostas[rota] = [resposta];

  List<String> get rotas => chamadas.map((c) => c.$1).toList();

  Future<RespostaBruta> transporte(String rota, Map<String, dynamic> corpo) async {
    chamadas.add((rota, corpo));
    final fila = _respostas[rota];
    final Object r;
    if (fila == null || fila.isEmpty) {
      r = padrao;
    } else {
      r = fila.length > 1 ? fila.removeAt(0) : fila.first;
    }
    if (r is SemInternet) throw r;
    return r as RespostaBruta;
  }
}

const agoraServidor = '2026-10-12T12:00:00.000Z';
final relogioPadrao = DateTime.utc(2026, 10, 12, 12);

const configTeste = ConfiguracaoLicenca(
  appId: 'meufrete',
  nomeApp: 'Meu Frete',
  versaoApp: '2.1.0',
  chavePublica: chaveTeste,
);

Map<String, dynamic> _app({int testeDias = 0, String preco = ''}) =>
    {'id': 'meufrete', 'nome': 'Meu Frete', 'preco': preco, 'teste_dias': testeDias, 'link': ''};

RespostaBruta liberada(Liberacao l, {Map<String, dynamic>? pedido}) => RespostaBruta(200, {
      'ok': true,
      'servico': 'fortaleza-licencas',
      'agora': agoraServidor,
      'liberado': true,
      'situacao': 'liberada',
      'motivo': '',
      'licenca': l.paraJson(),
      'pedido': pedido,
      'contato': {'whatsapp': '5564996472794'},
      'app': _app(),
      'teste_disponivel': false,
    });

RespostaBruta negada({
  String situacao = 'sem_licenca',
  String motivo = 'Este aparelho ainda não está liberado.',
  Map<String, dynamic>? pedido,
  bool teste = false,
  int testeDias = 0,
  String preco = '',
}) =>
    RespostaBruta(200, {
      'ok': true,
      'servico': 'fortaleza-licencas',
      'agora': agoraServidor,
      'liberado': false,
      'situacao': situacao,
      'motivo': motivo,
      'licenca': null,
      'pedido': pedido,
      'contato': {'whatsapp': '5564996472794'},
      'app': _app(testeDias: testeDias, preco: preco),
      'teste_disponivel': teste,
    });

Map<String, dynamic> pedidoPendente([String codigo = '482913']) =>
    {'codigo': codigo, 'status': 'pendente', 'nome': 'Fulano', 'whatsapp': '5564999998888', 'criado_em': agoraServidor};

ControleLicenca novoControle(
  ServidorFalso s, {
  String id = 'aparelho-de-teste-a',
  DateTime? agora,
  ConfiguracaoLicenca config = configTeste,
}) =>
    ControleLicenca(
      config,
      servidor: ServidorLicenca(transporte: s.transporte),
      lerIdDoAparelho: () async => id,
      lerModelo: () async => 'motorola moto g35',
      relogio: () => agora ?? relogioPadrao,
    );

/// Deixa terminar o que ficou rodando em segundo plano (renovacao silenciosa).
Future<void> esperar() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
