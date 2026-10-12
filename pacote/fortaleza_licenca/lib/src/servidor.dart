import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'liberacao.dart';

/// Resposta crua do servidor: codigo HTTP e o JSON (se veio JSON).
class RespostaBruta {
  const RespostaBruta(this.status, this.dados);

  final int status;
  final Map<String, dynamic>? dados;
}

/// Quem leva o pedido ao servidor. Nos testes, entra um falso.
typedef Transporte = Future<RespostaBruta> Function(String rota, Map<String, dynamic> corpo);

/// Sem internet, servidor fora do ar ou demora demais.
class SemInternet implements Exception {
  const SemInternet();
}

/// Conversa com o servidor de licencas (rotas da versao 3).
class ServidorLicenca {
  ServidorLicenca({this.endereco = enderecoPadrao, Transporte? transporte}) : _transporte = transporte;

  static const String enderecoPadrao = 'https://fortaleza-licencas.fortalezadigitalsecurity.workers.dev';

  final String endereco;
  final Transporte? _transporte;

  /// Este aparelho e liberado? (tambem e o que traz a licenca de volta
  /// depois de atualizar ou reinstalar o app)
  Future<SituacaoServidor> status(Map<String, dynamic> corpo) => _chamar('/v2/status', corpo);

  /// Pedido de liberacao com nome e WhatsApp.
  Future<SituacaoServidor> pedir(Map<String, dynamic> corpo) => _chamar('/v2/pedir', corpo);

  /// Teste gratis (se o app tiver).
  Future<SituacaoServidor> teste(Map<String, dynamic> corpo) => _chamar('/v2/teste', corpo);

  /// Ativar com a chave curta.
  Future<SituacaoServidor> ativar(Map<String, dynamic> corpo) => _chamar('/v2/ativar', corpo);

  Future<SituacaoServidor> _chamar(String rota, Map<String, dynamic> corpo) async {
    try {
      final transporte = _transporte ?? _http;
      final r = await transporte(rota, corpo);
      return SituacaoServidor.deResposta(r.status, r.dados);
    } on SemInternet {
      return const SituacaoServidor.semInternet();
    } catch (_) {
      return const SituacaoServidor.semInternet();
    }
  }

  Future<RespostaBruta> _http(String rota, Map<String, dynamic> corpo) async {
    final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final pedido = await cliente.postUrl(Uri.parse('$endereco$rota'));
      pedido.headers.contentType = ContentType.json;
      pedido.write(jsonEncode(corpo));
      final resposta = await pedido.close().timeout(const Duration(seconds: 20));
      final texto = await resposta.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
      Map<String, dynamic>? dados;
      try {
        final valor = jsonDecode(texto);
        if (valor is Map<String, dynamic>) dados = valor;
      } catch (_) {
        dados = null;
      }
      return RespostaBruta(resposta.statusCode, dados);
    } on SocketException {
      throw const SemInternet();
    } on TimeoutException {
      throw const SemInternet();
    } on HandshakeException {
      throw const SemInternet();
    } on HttpException {
      throw const SemInternet();
    } finally {
      cliente.close(force: true);
    }
  }
}

/// Pedido de liberacao deste aparelho, como esta no servidor.
class PedidoLiberacao {
  const PedidoLiberacao({required this.codigo, required this.status, this.nome = '', this.whatsapp = ''});

  factory PedidoLiberacao.deJson(Map<String, dynamic> j) => PedidoLiberacao(
        codigo: (j['codigo'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        nome: (j['nome'] ?? '').toString(),
        whatsapp: (j['whatsapp'] ?? '').toString(),
      );

  final String codigo;
  final String status;
  final String nome;
  final String whatsapp;

  bool get pendente => status == 'pendente';
  bool get recusado => status == 'recusado';
  bool get aprovado => status == 'aprovado';

  Map<String, dynamic> paraJson() => {'codigo': codigo, 'status': status, 'nome': nome, 'whatsapp': whatsapp};
}

/// O que o servidor conta sobre o app (nome, preco e teste gratis).
class InfoApp {
  const InfoApp({this.nome = '', this.preco = '', this.testeDias = 0, this.link = ''});

  factory InfoApp.deJson(Map<String, dynamic> j) => InfoApp(
        nome: (j['nome'] ?? '').toString(),
        preco: (j['preco'] ?? '').toString(),
        testeDias: int.tryParse((j['teste_dias'] ?? '0').toString()) ?? 0,
        link: (j['link'] ?? '').toString(),
      );

  final String nome;
  final String preco;
  final int testeDias;
  final String link;

  Map<String, dynamic> paraJson() => {'nome': nome, 'preco': preco, 'teste_dias': testeDias, 'link': link};
}

/// Retrato da situacao deste aparelho, como o servidor respondeu.
class SituacaoServidor {
  const SituacaoServidor({
    required this.status,
    required this.ok,
    required this.doServidor,
    this.liberado = false,
    this.situacao = '',
    this.motivo = '',
    this.licenca,
    this.pedido,
    this.contatoWhatsapp = '',
    this.app,
    this.testeDisponivel = false,
    this.agoraServidor,
  }) : semInternet = false;

  const SituacaoServidor.semInternet()
      : semInternet = true,
        status = 0,
        ok = false,
        doServidor = false,
        liberado = false,
        situacao = '',
        motivo = '',
        licenca = null,
        pedido = null,
        contatoWhatsapp = '',
        app = null,
        testeDisponivel = false,
        agoraServidor = null;

  factory SituacaoServidor.deResposta(int status, Map<String, dynamic>? d) {
    if (d == null) {
      return SituacaoServidor(status: status, ok: false, doServidor: false, motivo: 'O servidor respondeu uma coisa estranha.');
    }
    Map<String, dynamic>? mapa(Object? v) => v is Map<String, dynamic> ? v : null;
    final licenca = mapa(d['licenca']);
    final pedido = mapa(d['pedido']);
    final contato = mapa(d['contato']);
    final app = mapa(d['app']);
    return SituacaoServidor(
      status: status,
      ok: d['ok'] == true,
      doServidor: d['servico'] == 'fortaleza-licencas',
      liberado: d['liberado'] == true,
      situacao: (d['situacao'] ?? '').toString(),
      motivo: (d['motivo'] ?? '').toString(),
      licenca: licenca == null ? null : Liberacao.deJson(licenca),
      pedido: pedido == null ? null : PedidoLiberacao.deJson(pedido),
      contatoWhatsapp: contato == null ? '' : (contato['whatsapp'] ?? '').toString(),
      app: app == null ? null : InfoApp.deJson(app),
      testeDisponivel: d['teste_disponivel'] == true,
      agoraServidor: DateTime.tryParse((d['agora'] ?? '').toString()),
    );
  }

  final bool semInternet;
  final int status;
  final bool ok;
  final bool doServidor;
  final bool liberado;
  final String situacao;
  final String motivo;
  final Liberacao? licenca;
  final PedidoLiberacao? pedido;
  final String contatoWhatsapp;
  final InfoApp? app;
  final bool testeDisponivel;
  final DateTime? agoraServidor;
}
