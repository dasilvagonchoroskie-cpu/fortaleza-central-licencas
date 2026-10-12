import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Resposta do servidor de licencas. [status] 0 = sem internet.
class Resposta {
  const Resposta(this.status, this.dados);

  const Resposta.semInternet()
      : status = 0,
        dados = const {'ok': false, 'motivo': 'Sem internet, ou o servidor não respondeu. Ligue os dados e tente de novo.'};

  final int status;
  final Map<String, dynamic> dados;

  bool get ok => dados['ok'] == true;
  bool get semInternet => status == 0;
  bool get senhaRecusada => status == 401 || status == 403;

  String get motivo {
    if (senhaRecusada) return 'O servidor recusou a senha. Confira a senha de administrador em Mais.';
    final m = (dados['motivo'] ?? '').toString();
    return m.isEmpty ? 'O servidor não respondeu direito. Tente de novo.' : m;
  }

  List<Map<String, dynamic>> lista(String chave) {
    final v = dados[chave];
    return v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
  }
}

/// Quem leva o pedido ao servidor. Nos testes, entra um falso.
typedef TransporteAdmin = Future<Resposta> Function(
    String metodo, String endereco, String rota, String senha, Map<String, dynamic>? corpo);

/// Conversa com o servidor de licencas, com a senha de administrador.
class ServidorAdmin {
  ServidorAdmin({TransporteAdmin? transporte}) : _transporte = transporte;

  static const String enderecoPadrao = 'https://fortaleza-licencas.fortalezadigitalsecurity.workers.dev';

  final TransporteAdmin? _transporte;
  String endereco = enderecoPadrao;
  String senha = '';

  Future<Resposta> get(String rota) => _chamar('GET', rota, null);
  Future<Resposta> post(String rota, Map<String, dynamic> corpo) => _chamar('POST', rota, corpo);

  Future<Resposta> _chamar(String metodo, String rota, Map<String, dynamic>? corpo) async {
    final base = endereco.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final transporte = _transporte ?? _http;
      return await transporte(metodo, base, rota, senha, corpo);
    } catch (_) {
      return const Resposta.semInternet();
    }
  }

  static Future<Resposta> _http(
      String metodo, String endereco, String rota, String senha, Map<String, dynamic>? corpo) async {
    final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('$endereco$rota');
      final pedido = metodo == 'POST' ? await cliente.postUrl(uri) : await cliente.getUrl(uri);
      pedido.headers.set(HttpHeaders.authorizationHeader, 'Bearer $senha');
      pedido.headers.contentType = ContentType.json;
      if (corpo != null) pedido.write(jsonEncode(corpo));
      final resposta = await pedido.close().timeout(const Duration(seconds: 25));
      final texto = await resposta.transform(utf8.decoder).join().timeout(const Duration(seconds: 25));
      Map<String, dynamic> dados;
      try {
        final v = jsonDecode(texto);
        dados = v is Map<String, dynamic> ? v : {'ok': false, 'motivo': 'O servidor respondeu uma coisa estranha.'};
      } catch (_) {
        dados = {'ok': false, 'motivo': 'O servidor respondeu uma coisa estranha.'};
      }
      return Resposta(resposta.statusCode, dados);
    } on SocketException {
      return const Resposta.semInternet();
    } on TimeoutException {
      return const Resposta.semInternet();
    } on HandshakeException {
      return const Resposta.semInternet();
    } on HttpException {
      return const Resposta.semInternet();
    } finally {
      cliente.close(force: true);
    }
  }
}
