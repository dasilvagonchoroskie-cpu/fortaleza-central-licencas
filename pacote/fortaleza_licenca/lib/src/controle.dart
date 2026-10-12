import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chave_publica.dart';
import 'liberacao.dart';
import 'servidor.dart';
import 'textos.dart';

/// Em que pe esta a licenca deste aparelho.
enum EstadoLicenca { carregando, liberado, bloqueado }

/// O que muda de um aplicativo para outro.
class ConfiguracaoLicenca {
  const ConfiguracaoLicenca({
    required this.appId,
    required this.nomeApp,
    this.versaoApp = '',
    this.enderecoServidor = ServidorLicenca.enderecoPadrao,
    this.chavePublica = ChavePublica.fortaleza,
    this.prefixoLegado,
    this.canal = canalPadrao,
  });

  /// Canal do MainActivity que entrega o ANDROID_ID e o modelo do celular.
  static const String canalPadrao = 'fortaleza/licenca';

  /// Apelido do app no servidor (o mesmo cadastrado na Central).
  final String appId;

  /// Nome que aparece para o cliente.
  final String nomeApp;

  /// Versao do app (aparece na Central, ao lado da licenca).
  final String versaoApp;

  final String enderecoServidor;
  final ChavePublica chavePublica;

  /// Prefixo das preferencias da licenca antiga do app (ex.: 'taxi.licenca'
  /// no taximetro 3.1). Com ele, quem ja usa o app continua liberado e a
  /// liberacao antiga vira licenca nova sozinha, sem o cliente perceber.
  final String? prefixoLegado;

  final String canal;
}

/// Cuida da licenca: confere a liberacao guardada (sem internet), renova
/// em silencio, pede liberacao, comeca o teste gratis e ativa com chave.
class ControleLicenca extends ChangeNotifier {
  ControleLicenca(
    this.config, {
    ServidorLicenca? servidor,
    Future<String?> Function()? lerIdDoAparelho,
    Future<String?> Function()? lerModelo,
    DateTime Function()? relogio,
  })  : servidor = servidor ?? ServidorLicenca(endereco: config.enderecoServidor),
        _lerId = lerIdDoAparelho,
        _lerModelo = lerModelo,
        _relogio = relogio ?? DateTime.now;

  /// Com internet, confere no servidor no maximo a cada 6 horas.
  static const Duration intervaloConferencia = Duration(hours: 6);

  /// Relogio do celular atrasado mais que isto = alguem mexeu na data.
  static const Duration toleranciaRelogio = Duration(days: 2);

  final ConfiguracaoLicenca config;
  final ServidorLicenca servidor;
  final Future<String?> Function()? _lerId;
  final Future<String?> Function()? _lerModelo;
  final DateTime Function() _relogio;

  EstadoLicenca estado = EstadoLicenca.carregando;
  String? codigoAparelho;
  String modelo = '';
  Liberacao? liberacao;

  /// sem_licenca, vencida, teste_acabou, bloqueada, confirmar, relogio...
  String situacao = '';
  String motivo = '';
  PedidoLiberacao? pedido;
  String contatoWhatsapp = '';
  InfoApp infoApp = const InfoApp();
  bool testeDisponivel = false;
  bool semInternet = false;

  /// Pedido, teste ou chave em andamento.
  bool ocupado = false;

  /// Conferencia com o servidor em andamento.
  bool conferindo = false;
  String? erro;
  String nomeGuardado = '';
  String whatsappGuardado = '';
  String chaveGuardada = '';

  /// O servidor disse que nao e mais liberado enquanto o app estava em
  /// uso: nao derruba a tela no meio do trabalho, trava na proxima abertura.
  bool bloqueioPendente = false;

  bool _avisoLiberado = false;
  SharedPreferences? _prefs;
  Future<void>? _iniciando;
  DateTime? _maiorData;
  DateTime? _conferidoEm;
  bool _relogioAtrasado = false;
  bool _tinhaLiberacao = false;
  Map<String, String>? _legado;

  String get _k => 'fds_licenca.${config.appId}';

  /// Comeca (uma vez so). Pode chamar quantas vezes quiser.
  Future<void> iniciar() => _iniciando ??= _iniciar();

  Future<void> _iniciar() async {
    _prefs = await SharedPreferences.getInstance();
    _carregarGuardados();
    codigoAparelho = await _obterCodigo();
    modelo = await _obterModelo();
    if (codigoAparelho == null) {
      _bloquear('sem_aparelho', 'Não consegui identificar este aparelho. Feche e abra o aplicativo de novo.');
      notifyListeners();
      return;
    }

    final agora = _relogio();
    _relogioAtrasado = _maiorData != null && agora.isBefore(_maiorData!.subtract(toleranciaRelogio));
    if (!_relogioAtrasado) await _anotarData(agora);

    // 1) Liberacao nova guardada e dentro da janela: abre sem internet.
    final local = _liberacaoLocal(agora);
    if (local != null) {
      liberacao = local;
      estado = EstadoLicenca.liberado;
      notifyListeners();
      if (_precisaConferir(agora)) unawaited(conferirAgora(silencioso: true));
      return;
    }

    // 2) Liberacao antiga do app (ex.: taximetro 3.1): continua valendo e
    // vira licenca nova na primeira conferencia com internet.
    _legado = _lerLegado();
    if (_legado != null && _legadoDentroDoPrazo(agora)) {
      estado = EstadoLicenca.liberado;
      notifyListeners();
      unawaited(conferirAgora(silencioso: true));
      return;
    }

    // 3) Nada valido aqui: pergunta ao servidor antes de mostrar a tela de
    // pedido. Reinstalou ou perdeu os dados? Ele devolve a liberacao.
    await conferirAgora();
  }

  /// Pergunta ao servidor como esta este aparelho.
  Future<void> conferirAgora({bool silencioso = false}) async {
    if (codigoAparelho == null || _prefs == null || conferindo) return;
    conferindo = true;
    if (!silencioso) notifyListeners();
    try {
      final r = await servidor.status(_corpo());
      await _aplicar(r, silencioso: silencioso);
    } finally {
      conferindo = false;
      notifyListeners();
    }
  }

  /// O app voltou para a frente: renova se ja passou da hora.
  Future<void> aoVoltarParaOApp() async {
    if (codigoAparelho == null || _prefs == null) return;
    if (estado == EstadoLicenca.liberado) {
      if (_precisaConferir(_relogio())) await conferirAgora(silencioso: true);
    } else if (estado == EstadoLicenca.bloqueado) {
      await conferirAgora(silencioso: true);
    }
  }

  /// Pedido de liberacao: o servidor devolve o codigo de verificacao.
  Future<bool> pedirLiberacao({required String nome, required String whatsapp}) async {
    final n = nome.trim();
    final w = whatsappNormalizado(whatsapp);
    if (n.length < 2) return _falhar('Escreva o seu nome.');
    if (w == null) return _falhar('Escreva o WhatsApp com DDD, ex.: 64 99999-8888.');
    nomeGuardado = n;
    whatsappGuardado = whatsapp.trim();
    await _prefs?.setString('$_k.nome', nomeGuardado);
    await _prefs?.setString('$_k.whatsapp', whatsappGuardado);
    return _acao(() => servidor.pedir(_corpo({'nome': n, 'whatsapp': w})));
  }

  /// Teste gratis (so aparece quando o app tem e o aparelho nunca usou).
  Future<bool> comecarTeste() {
    final w = whatsappNormalizado(whatsappGuardado);
    return _acao(() => servidor.teste(_corpo({
          if (nomeGuardado.isNotEmpty) 'nome': nomeGuardado,
          if (w != null) 'whatsapp': w,
        })));
  }

  /// Ativa com a chave curta (ou, nos apps antigos, a chave comprida).
  /// Aceita a mensagem inteira do WhatsApp: a chave e achada no texto.
  Future<bool> ativarComChave(String texto) async {
    final codigo = codigoAparelho;
    if (codigo == null) return _falhar('Não consegui identificar este aparelho.');
    final achada = extrairChave(texto, ignorar: codigo);
    if (achada != null && achada.length >= 80) {
      final prefixo = config.prefixoLegado;
      if (prefixo == null ||
          !confereLegado(config.chavePublica,
              appId: config.appId, aparelho: codigo, assinatura: achada, validade: 'sempre')) {
        return _falhar('Essa chave não serve neste aparelho.');
      }
      await _prefs?.setString('$prefixo.assinatura', achada);
      await _prefs?.setString('$prefixo.validade', 'sempre');
      _legado = {'assinatura': achada, 'validade': 'sempre'};
      erro = null;
      estado = EstadoLicenca.liberado;
      _avisoLiberado = true;
      notifyListeners();
      unawaited(conferirAgora(silencioso: true));
      return true;
    }
    final curta = chaveCurta(achada ?? texto);
    if (curta == null) return _falhar('A chave tem 16 letras e números, em quatro grupos de quatro.');
    chaveGuardada = curta;
    await _prefs?.setString('$_k.chave', curta);
    return _acao(() => servidor.ativar(_corpo({'chave': curta})));
  }

  /// Acabou de liberar (pedido aprovado, teste ou chave)? Le uma vez so.
  bool consumirAvisoLiberado() {
    final v = _avisoLiberado;
    _avisoLiberado = false;
    return v;
  }

  /// Dias ate a licenca vencer (null na vitalicia).
  int? get diasRestantes {
    final fim = liberacao?.venceData;
    if (fim == null) return null;
    final horas = fim.difference(_relogio()).inHours;
    return horas <= 0 ? 0 : (horas / 24).ceil();
  }

  /// Mensagem pronta para o WhatsApp de quem vende.
  String get mensagemParaVendedor {
    final p = pedido;
    return [
      'Olá! Quero liberar o aplicativo ${config.nomeApp}.',
      if (p != null && p.codigo.isNotEmpty && !p.aprovado) 'Código do pedido: ${codigoPedidoLegivel(p.codigo)}',
      if (nomeGuardado.isNotEmpty) 'Nome: $nomeGuardado',
      if (codigoAparelho != null) 'Aparelho: $codigoAparelho',
    ].join('\n');
  }

  /// Abre a conversa com quem vende, com a mensagem escrita.
  Uri get linkWhatsApp {
    final numero = contatoWhatsapp.replaceAll(RegExp(r'\D'), '');
    return Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensagemParaVendedor)}');
  }

  // ============================== por dentro ==============================

  Map<String, dynamic> _corpo([Map<String, dynamic> extra = const {}]) => {
        'app_id': config.appId,
        'aparelho': codigoAparelho,
        'versao': config.versaoApp,
        'modelo': modelo,
        if (_legado != null) 'legado': _legado,
        ...extra,
      };

  Future<bool> _falhar(String texto) async {
    erro = texto;
    notifyListeners();
    return false;
  }

  Future<bool> _acao(Future<SituacaoServidor> Function() chamada) async {
    if (ocupado || codigoAparelho == null || _prefs == null) return false;
    ocupado = true;
    erro = null;
    notifyListeners();
    try {
      final r = await chamada();
      if (r.semInternet) {
        semInternet = true;
        erro = 'Sem internet. Ligue os dados do celular e tente de novo.';
        return false;
      }
      await _aplicar(r, silencioso: false);
      return r.ok && r.doServidor;
    } finally {
      ocupado = false;
      notifyListeners();
    }
  }

  /// Aplica a resposta do servidor no estado e no que fica guardado.
  Future<void> _aplicar(SituacaoServidor r, {required bool silencioso}) async {
    final prefs = _prefs!;
    if (r.semInternet) {
      semInternet = true;
      if (estado == EstadoLicenca.carregando) _bloquearSemConferir();
      return;
    }
    semInternet = false;

    // Resposta que nao e do servidor de licencas, ou erro (dado invalido,
    // limite de pedidos, servidor com problema): avisa, mas nunca trava
    // quem ja estava liberado por causa disso.
    if (!r.doServidor || !r.ok) {
      if (!silencioso || estado != EstadoLicenca.liberado) {
        erro = r.motivo.isNotEmpty
            ? r.motivo
            : 'O servidor de licenças não respondeu direito. Tente de novo daqui a pouco.';
      }
      if (estado == EstadoLicenca.carregando) _bloquearSemConferir();
      return;
    }

    final agoraServidor = r.agoraServidor;
    if (agoraServidor != null) await _anotarData(agoraServidor);
    contatoWhatsapp = r.contatoWhatsapp;
    final app = r.app;
    if (app != null) infoApp = app;
    testeDisponivel = r.testeDisponivel;
    pedido = r.pedido;
    await prefs.setString('$_k.contato', contatoWhatsapp);
    await prefs.setString('$_k.app', jsonEncode(infoApp.paraJson()));
    final p = pedido;
    if (p == null) {
      await prefs.remove('$_k.pedido');
    } else {
      await prefs.setString('$_k.pedido', jsonEncode(p.paraJson()));
    }

    final nova = r.licenca;
    if (r.liberado && nova != null && nova.confere(config.chavePublica, appId: config.appId, aparelho: codigoAparelho!)) {
      final antes = estado;
      liberacao = nova;
      _conferidoEm = _relogio();
      _relogioAtrasado = false;
      await prefs.setString('$_k.liberacao', jsonEncode(nova.paraJson()));
      await prefs.setString('$_k.conferido_em', _conferidoEm!.toIso8601String());
      await prefs.remove('$_k.situacao');
      await prefs.remove('$_k.motivo');
      await _apagarLegado();
      erro = null;
      bloqueioPendente = false;
      situacao = 'liberada';
      motivo = '';
      if (antes != EstadoLicenca.liberado) {
        estado = EstadoLicenca.liberado;
        if (antes == EstadoLicenca.bloqueado) _avisoLiberado = true;
      }
      return;
    }
    if (r.liberado) {
      erro = 'A liberação veio com a assinatura errada. Fale com quem vendeu o aplicativo.';
      if (estado == EstadoLicenca.carregando) _bloquearSemConferir();
      return;
    }

    // O servidor disse, com todas as letras, que este aparelho NAO e
    // liberado (sem licenca, vencida, bloqueada, teste acabou).
    liberacao = null;
    await prefs.remove('$_k.liberacao');
    await _apagarLegado();
    final sit = r.situacao.isEmpty ? 'sem_licenca' : r.situacao;
    final mot = r.motivo.isEmpty ? 'Este aparelho ainda não está liberado.' : r.motivo;
    await prefs.setString('$_k.situacao', sit);
    await prefs.setString('$_k.motivo', mot);
    if (estado == EstadoLicenca.liberado && silencioso) {
      bloqueioPendente = true;
    } else {
      _bloquear(sit, mot);
    }
  }

  void _bloquear(String sit, String mot) {
    estado = EstadoLicenca.bloqueado;
    situacao = sit;
    motivo = mot;
  }

  /// Sem conseguir falar com o servidor e sem liberacao valida aqui.
  void _bloquearSemConferir() {
    if (_relogioAtrasado) {
      _bloquear('relogio',
          'A data do celular parece errada. Acerte a data e a hora, ou ligue a internet para conferir a licença.');
    } else if (_tinhaLiberacao) {
      _bloquear('confirmar',
          'Ligue a internet para confirmar a licença deste aparelho. É rapidinho e o aplicativo volta a abrir.');
    } else {
      _bloquear(situacao.isEmpty || situacao == 'liberada' ? 'sem_licenca' : situacao,
          motivo.isEmpty ? 'Este aparelho ainda não está liberado.' : motivo);
    }
  }

  bool _precisaConferir(DateTime agora) {
    final ultima = _conferidoEm;
    return ultima == null || agora.difference(ultima).abs() > intervaloConferencia;
  }

  Liberacao? _liberacaoLocal(DateTime agora) {
    final guardada = _lerJson('$_k.liberacao', Liberacao.deJson);
    if (guardada == null) return null;
    if (!guardada.confere(config.chavePublica, appId: config.appId, aparelho: codigoAparelho!)) return null;
    _tinhaLiberacao = true;
    final ate = guardada.ateData;
    if (ate == null || _relogioAtrasado || !agora.isBefore(ate)) return null;
    return guardada;
  }

  Map<String, String>? _lerLegado() {
    final prefixo = config.prefixoLegado;
    final prefs = _prefs;
    if (prefixo == null || prefs == null) return null;
    final assinatura = prefs.getString('$prefixo.assinatura') ?? '';
    if (assinatura.isEmpty) return null;
    var validade = prefs.getString('$prefixo.validade') ?? 'sempre';
    if (validade.isEmpty) validade = 'sempre';
    final ok = confereLegado(config.chavePublica,
        appId: config.appId, aparelho: codigoAparelho!, assinatura: assinatura, validade: validade);
    if (!ok) return null;
    _tinhaLiberacao = true;
    return {'assinatura': assinatura, 'validade': validade};
  }

  bool _legadoDentroDoPrazo(DateTime agora) {
    final validade = _legado?['validade'] ?? '';
    if (validade == 'sempre') return true;
    final fim = DateTime.tryParse(validade);
    return fim != null && !_relogioAtrasado && agora.isBefore(fim);
  }

  /// Depois que a licenca nova chegou (ou o servidor negou), a antiga nao
  /// vale mais aqui. A chave curta antiga fica, so para mostrar.
  Future<void> _apagarLegado() async {
    _legado = null;
    final prefixo = config.prefixoLegado;
    if (prefixo == null) return;
    await _prefs?.remove('$prefixo.assinatura');
    await _prefs?.remove('$prefixo.validade');
  }

  Future<void> _anotarData(DateTime d) async {
    final atual = _maiorData;
    if (atual != null && !d.isAfter(atual)) return;
    _maiorData = d;
    await _prefs?.setString('$_k.maior_data', '${d.millisecondsSinceEpoch}');
  }

  void _carregarGuardados() {
    final p = _prefs!;
    nomeGuardado = p.getString('$_k.nome') ?? '';
    whatsappGuardado = p.getString('$_k.whatsapp') ?? '';
    contatoWhatsapp = p.getString('$_k.contato') ?? '';
    final prefixo = config.prefixoLegado;
    chaveGuardada = p.getString('$_k.chave') ?? (prefixo == null ? '' : (p.getString('$prefixo.chave') ?? ''));
    situacao = p.getString('$_k.situacao') ?? '';
    motivo = p.getString('$_k.motivo') ?? '';
    var maior = int.tryParse(p.getString('$_k.maior_data') ?? '');
    if (prefixo != null) {
      // O taximetro 3.1 guardava a maior data vista no mesmo formato.
      final antiga = int.tryParse(p.getString('$prefixo.dataVista') ?? '');
      if (antiga != null && (maior == null || antiga > maior)) maior = antiga;
    }
    _maiorData = maior == null ? null : DateTime.fromMillisecondsSinceEpoch(maior);
    _conferidoEm = DateTime.tryParse(p.getString('$_k.conferido_em') ?? '');
    infoApp = _lerJson('$_k.app', InfoApp.deJson) ?? const InfoApp();
    pedido = _lerJson('$_k.pedido', PedidoLiberacao.deJson);
  }

  T? _lerJson<T>(String chave, T Function(Map<String, dynamic>) criar) {
    final texto = _prefs?.getString(chave);
    if (texto == null || texto.isEmpty) return null;
    try {
      final valor = jsonDecode(texto);
      return valor is Map<String, dynamic> ? criar(valor) : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _obterCodigo() async {
    String bruto;
    try {
      final ler = _lerId;
      bruto = (ler != null ? await ler() : await MethodChannel(config.canal).invokeMethod<String>('idDoAparelho')) ?? '';
    } catch (_) {
      bruto = '';
    }
    return bruto.trim().isEmpty ? null : codigoDoAparelho(config.appId, bruto);
  }

  Future<String> _obterModelo() async {
    try {
      final ler = _lerModelo;
      final m = ler != null ? await ler() : await MethodChannel(config.canal).invokeMethod<String>('modelo');
      return (m ?? '').trim();
    } catch (_) {
      return '';
    }
  }
}
