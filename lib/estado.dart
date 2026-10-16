import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'avisos.dart';
import 'modelos.dart';

/// Tudo o que a Central sabe e faz. As telas so leem daqui e chamam os
/// metodos; a conversa com o servidor fica toda neste arquivo.
class Central extends ChangeNotifier {
  Central({ServidorAdmin? servidor, DateTime Function()? relogio, this.usarAvisos = true})
      : servidor = servidor ?? ServidorAdmin(),
        _relogio = relogio ?? DateTime.now;

  static const _kServidor = 'central.servidor';
  static const _kSenha = 'central.senha';
  static const _kAvisos = 'central.avisos';

  final ServidorAdmin servidor;
  final DateTime Function() _relogio;

  /// Desligado nos testes (o canal do Android nao existe la).
  final bool usarAvisos;

  bool pronto = false;
  bool temSenha = false;
  bool avisosLigados = true;

  /// null = ainda nao conferiu; true = conversou com o servidor.
  bool? conectado;
  String mensagemConexao = '';

  List<AppCadastrado> apps = [];
  List<Pedido> pedidos = [];
  bool pedidosTodos = false;
  List<LicencaAdmin> licencas = [];
  String filtroApp = '';
  int pendentes = 0;
  String whatsappPadrao = '';

  bool carregandoPedidos = false;
  bool carregandoLicencas = false;
  String? erroPedidos;
  String? erroLicencas;
  String? erroApps;

  SharedPreferences? _prefs;

  DateTime get agora => _relogio();

  Future<void> carregar() async {
    _prefs = await SharedPreferences.getInstance();
    servidor.endereco = _prefs!.getString(_kServidor) ?? ServidorAdmin.enderecoPadrao;
    servidor.senha = _prefs!.getString(_kSenha) ?? '';
    avisosLigados = _prefs!.getBool(_kAvisos) ?? true;
    temSenha = servidor.senha.isNotEmpty;
    pronto = true;
    notifyListeners();
    if (temSenha) {
      await _configurarAvisos();
      await atualizarTudo();
    }
  }

  // ============================== ENTRADA ==============================

  /// Confere a senha no servidor e, se valer, guarda neste celular.
  Future<String?> entrar(String senha, {String? endereco}) async {
    final s = senha.trim();
    if (s.length < 10) return 'A senha de administrador tem pelo menos 10 caracteres.';
    final antes = (servidor.endereco, servidor.senha);
    if (endereco != null && endereco.trim().isNotEmpty) servidor.endereco = endereco.trim();
    servidor.senha = s;
    final r = await servidor.get('/admin/resumo');
    if (!r.ok) {
      servidor.endereco = antes.$1;
      servidor.senha = antes.$2;
      return r.semInternet ? r.motivo : (r.senhaRecusada ? 'Senha errada. Confira e tente de novo.' : r.motivo);
    }
    await _prefs?.setString(_kSenha, s);
    await _prefs?.setString(_kServidor, servidor.endereco);
    temSenha = true;
    _aplicarResumo(r);
    notifyListeners();
    await _configurarAvisos(pedirPermissao: true);
    await atualizarTudo();
    return null;
  }

  /// Apaga a senha deste celular (o servidor continua igual).
  Future<void> sair() async {
    await _prefs?.remove(_kSenha);
    servidor.senha = '';
    temSenha = false;
    apps = [];
    pedidos = [];
    licencas = [];
    pendentes = 0;
    conectado = null;
    await Avisos.configurar(servidor: servidor.endereco, senha: '', ligado: false, ativo: usarAvisos);
    notifyListeners();
  }

  Future<void> trocarEndereco(String endereco) async {
    servidor.endereco = endereco.trim().isEmpty ? ServidorAdmin.enderecoPadrao : endereco.trim();
    await _prefs?.setString(_kServidor, servidor.endereco);
    await _configurarAvisos();
    notifyListeners();
  }

  // ============================== GERAL ==============================

  Future<void> atualizarTudo() async {
    await Future.wait([atualizarResumo(), carregarApps(), carregarPedidos(), carregarLicencas()]);
  }

  Future<void> atualizarResumo() async {
    final r = await servidor.get('/admin/resumo');
    _aplicarResumo(r);
    notifyListeners();
  }

  void _aplicarResumo(Resposta r) {
    conectado = r.ok;
    mensagemConexao = r.ok ? '' : r.motivo;
    if (r.ok) pendentes = (r.dados['pedidos_pendentes'] is int) ? r.dados['pedidos_pendentes'] as int : 0;
  }

  Future<void> ligarAvisos(bool ligar) async {
    avisosLigados = ligar;
    await _prefs?.setBool(_kAvisos, ligar);
    await _configurarAvisos(pedirPermissao: ligar);
    // Ao ligar, pede tambem para o Android nao segurar o monitor (bateria).
    if (ligar) await Avisos.pedirIsencaoBateria(ativo: usarAvisos);
    notifyListeners();
  }

  /// Mostra uma notificacao de teste. false = permissao de notificacao negada.
  Future<bool> testarAviso() => Avisos.testar(ativo: usarAvisos);

  /// Abre a tela do Android para liberar o monitor da economia de bateria.
  Future<void> pedirIsencaoBateria() => Avisos.pedirIsencaoBateria(ativo: usarAvisos);

  Future<void> _configurarAvisos({bool pedirPermissao = false}) async {
    await Avisos.configurar(
      servidor: servidor.endereco,
      senha: servidor.senha,
      ligado: avisosLigados && temSenha,
      ativo: usarAvisos,
    );
    if (pedirPermissao && avisosLigados) await Avisos.pedirPermissao(ativo: usarAvisos);
  }

  String nomeDoApp(String id) {
    for (final a in apps) {
      if (a.id == id) return a.nome;
    }
    return id;
  }

  AppCadastrado? appPorId(String id) {
    for (final a in apps) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ============================== PEDIDOS ==============================

  Future<void> carregarPedidos({bool? todos}) async {
    if (todos != null) pedidosTodos = todos;
    carregandoPedidos = true;
    notifyListeners();
    final r = await servidor.get('/admin/pedidos${pedidosTodos ? '?status=todos' : ''}');
    carregandoPedidos = false;
    if (r.ok) {
      pedidos = r.lista('pedidos').map(Pedido.deJson).toList();
      erroPedidos = null;
      if (!pedidosTodos) pendentes = pedidos.length;
      conectado = true;
      await Avisos.marcarVisto(pedidos.isEmpty ? '' : pedidos.first.atualizadoEm, ativo: usarAvisos);
    } else {
      erroPedidos = r.motivo;
      if (r.semInternet || r.senhaRecusada) conectado = false;
    }
    notifyListeners();
  }

  /// Libera o aparelho do pedido. [dias] 0 = vitalicia. [transferir] =
  /// chave de outra licenca do mesmo cliente, que muda para este aparelho.
  Future<Resposta> aprovar(Pedido p, {int dias = 0, String? transferir}) async {
    final r = await servidor.post('/admin/pedidos/aprovar', {
      'id': p.id,
      'dias': dias,
      if (transferir != null) 'transferir': transferir,
    });
    if (r.ok) await Future.wait([carregarPedidos(), carregarLicencas(), carregarApps()]);
    return r;
  }

  Future<Resposta> recusar(Pedido p) async {
    final r = await servidor.post('/admin/pedidos/recusar', {'id': p.id});
    if (r.ok) await carregarPedidos();
    return r;
  }

  Future<Resposta> excluirPedido(Pedido p) async {
    final r = await servidor.post('/admin/pedidos/excluir', {'id': p.id});
    if (r.ok) await carregarPedidos();
    return r;
  }

  // ============================== APPS ==============================

  Future<void> carregarApps() async {
    final r = await servidor.get('/admin/apps');
    if (r.ok) {
      apps = r.lista('apps').map(AppCadastrado.deJson).toList();
      erroApps = null;
    } else {
      erroApps = r.motivo;
    }
    notifyListeners();
  }

  Future<Resposta> salvarApp({
    required String id,
    required String nome,
    String link = '',
    String whatsapp = '',
    String preco = '',
    int testeDias = 0,
  }) async {
    final r = await servidor.post('/admin/apps', {
      'id': id,
      'nome': nome,
      'link': link,
      'whatsapp': whatsapp,
      'preco': preco,
      'teste_dias': testeDias,
    });
    if (r.ok) await carregarApps();
    return r;
  }

  Future<Resposta> apagarApp(String id) async {
    final r = await servidor.post('/admin/apps/excluir', {'id': id});
    if (r.ok) await carregarApps();
    return r;
  }

  // ============================== LICENCAS ==============================

  Future<void> carregarLicencas({String? appId}) async {
    if (appId != null) filtroApp = appId;
    carregandoLicencas = true;
    notifyListeners();
    final rota = '/admin/licencas${filtroApp.isEmpty ? '' : '?app_id=${Uri.encodeQueryComponent(filtroApp)}'}';
    final r = await servidor.get(rota);
    carregandoLicencas = false;
    if (r.ok) {
      licencas = r.lista('licencas').map(LicencaAdmin.deJson).toList();
      erroLicencas = null;
    } else {
      erroLicencas = r.motivo;
    }
    notifyListeners();
  }

  Future<Resposta> gerar({
    required String appId,
    String cliente = '',
    String whatsapp = '',
    String observacao = '',
    int dias = 0,
  }) async {
    final r = await servidor.post('/admin/gerar', {
      'app_id': appId,
      'cliente': cliente,
      'whatsapp': whatsapp,
      'observacao': observacao,
      'dias': dias,
    });
    if (r.ok) await Future.wait([carregarLicencas(), carregarApps()]);
    return r;
  }

  Future<Resposta> _acaoLicenca(String rota, Map<String, dynamic> corpo) async {
    final r = await servidor.post(rota, corpo);
    if (r.ok) await carregarLicencas();
    return r;
  }

  Future<Resposta> prazo(String chave, int dias) => _acaoLicenca('/admin/prazo', {'chave': chave, 'dias': dias});
  Future<Resposta> revogar(String chave) => _acaoLicenca('/admin/prazo', {'chave': chave, 'vencer': true});
  Future<Resposta> soltar(String chave) => _acaoLicenca('/admin/soltar', {'chave': chave});
  Future<Resposta> bloquear(String chave, bool bloquear) =>
      _acaoLicenca('/admin/bloquear', {'chave': chave, 'bloquear': bloquear});
  Future<Resposta> excluirLicenca(String chave) async {
    final r = await _acaoLicenca('/admin/excluir', {'chave': chave});
    if (r.ok) await carregarApps();
    return r;
  }

  Future<Resposta> editarLicenca(String chave, {String cliente = '', String whatsapp = '', String observacao = ''}) =>
      _acaoLicenca('/admin/licencas/editar', {
        'chave': chave,
        'cliente': cliente,
        'whatsapp': whatsapp,
        'observacao': observacao,
      });

  // ============================== MAIS ==============================

  Future<Resposta> buscarCopia() => servidor.get('/admin/backup');

  Future<Resposta> carregarAjustes() async {
    final r = await servidor.get('/admin/ajustes');
    if (r.ok) {
      whatsappPadrao = (r.dados['whatsapp_padrao'] ?? '').toString();
      notifyListeners();
    }
    return r;
  }

  Future<Resposta> salvarWhatsappPadrao(String numero) async {
    final r = await servidor.post('/admin/ajustes', {'whatsapp_padrao': numero});
    if (r.ok) {
      whatsappPadrao = (r.dados['whatsapp_padrao'] ?? '').toString();
      notifyListeners();
    }
    return r;
  }

  /// Troca a senha (ja logado). A nova vale na hora; a antiga para.
  Future<Resposta> trocarSenha(String nova) async {
    final r = await servidor.post('/admin/trocar-senha', {'nova_senha': nova});
    if (r.ok) await _passarAUsar(nova);
    return r;
  }

  /// "Esqueci minha senha": com o codigo de recuperacao. Devolve o codigo
  /// NOVO (o antigo para de valer) ou o motivo da recusa.
  Future<Resposta> recuperarSenha(String codigo, String nova, {String? endereco}) async {
    if (endereco != null && endereco.trim().isNotEmpty) servidor.endereco = endereco.trim();
    final r = await servidor.post('/recuperar-senha', {'codigo': codigo, 'nova_senha': nova});
    if (r.ok) {
      await _prefs?.setString(_kServidor, servidor.endereco);
      await _passarAUsar(nova);
    }
    return r;
  }

  Future<void> _passarAUsar(String nova) async {
    servidor.senha = nova;
    await _prefs?.setString(_kSenha, nova);
    temSenha = true;
    await _configurarAvisos();
    notifyListeners();
  }
}
