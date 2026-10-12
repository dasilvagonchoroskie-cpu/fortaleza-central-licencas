/// O que vem do servidor de licencas, em objetos faceis de usar na tela.
library;

String _t(Object? v) => v == null ? '' : v.toString();
int _n(Object? v) => v is int ? v : int.tryParse(_t(v)) ?? 0;

/// Aplicativo cadastrado na Central (aba Apps).
class AppCadastrado {
  const AppCadastrado({
    required this.id,
    required this.nome,
    this.link = '',
    this.whatsapp = '',
    this.preco = '',
    this.testeDias = 0,
    this.chaves = 0,
    this.pendentes = 0,
  });

  factory AppCadastrado.deJson(Map<String, dynamic> j) => AppCadastrado(
        id: _t(j['id']),
        nome: _t(j['nome']),
        link: _t(j['link']),
        whatsapp: _t(j['whatsapp']),
        preco: _t(j['preco']),
        testeDias: _n(j['teste_dias']),
        chaves: _n(j['chaves']),
        pendentes: _n(j['pendentes']),
      );

  final String id;
  final String nome;
  final String link;
  final String whatsapp;
  final String preco;
  final int testeDias;
  final int chaves;
  final int pendentes;
}

/// Licenca (uma chave), com o aparelho em que esta presa.
class LicencaAdmin {
  const LicencaAdmin({
    required this.chave,
    required this.appId,
    this.cliente = '',
    this.observacao = '',
    this.aparelho = '',
    this.ativadaEm = '',
    this.criadaEm = '',
    this.bloqueada = false,
    this.validade = '',
    this.whatsapp = '',
    this.plano = '',
    this.ultimoContato = '',
    this.versaoApp = '',
    this.modelo = '',
  });

  factory LicencaAdmin.deJson(Map<String, dynamic> j) => LicencaAdmin(
        chave: _t(j['chave']),
        appId: _t(j['app_id']),
        cliente: _t(j['cliente']),
        observacao: _t(j['observacao']),
        aparelho: _t(j['aparelho']),
        ativadaEm: _t(j['ativada_em']),
        criadaEm: _t(j['criada_em']),
        bloqueada: _n(j['bloqueada']) != 0 || j['bloqueada'] == true,
        validade: _t(j['validade']),
        whatsapp: _t(j['whatsapp']),
        plano: _t(j['plano']),
        ultimoContato: _t(j['ultimo_contato']),
        versaoApp: _t(j['versao_app']),
        modelo: _t(j['modelo']),
      );

  final String chave;
  final String appId;
  final String cliente;
  final String observacao;
  final String aparelho;
  final String ativadaEm;
  final String criadaEm;
  final bool bloqueada;
  final String validade;
  final String whatsapp;
  final String plano;
  final String ultimoContato;
  final String versaoApp;
  final String modelo;

  bool get vitalicia => validade.isEmpty;

  bool vencidaEm(DateTime agora) {
    final fim = DateTime.tryParse(validade);
    return fim != null && !fim.isAfter(agora);
  }

  /// vitalicia | prazo | teste
  String get planoReal => plano.isNotEmpty ? plano : (validade.isEmpty ? 'vitalicia' : 'prazo');

  /// bloqueada | vencida | em_uso | livre
  String situacaoEm(DateTime agora) {
    if (bloqueada) return 'bloqueada';
    if (vencidaEm(agora)) return 'vencida';
    if (aparelho.isNotEmpty) return 'em_uso';
    return 'livre';
  }
}

/// Pedido de liberacao feito pelo app do cliente.
class Pedido {
  const Pedido({
    required this.id,
    required this.appId,
    required this.appNome,
    required this.aparelho,
    required this.codigo,
    required this.status,
    this.nome = '',
    this.whatsapp = '',
    this.modelo = '',
    this.versao = '',
    this.criadoEm = '',
    this.atualizadoEm = '',
    this.licenca = '',
    this.nesteAparelho,
    this.outras = const [],
  });

  factory Pedido.deJson(Map<String, dynamic> j) {
    final neste = j['neste_aparelho'];
    final outras = j['outras'];
    return Pedido(
      id: _t(j['id']),
      appId: _t(j['app_id']),
      appNome: _t(j['app_nome']).isEmpty ? _t(j['app_id']) : _t(j['app_nome']),
      aparelho: _t(j['aparelho']),
      codigo: _t(j['codigo']),
      status: _t(j['status']),
      nome: _t(j['nome']),
      whatsapp: _t(j['whatsapp']),
      modelo: _t(j['modelo']),
      versao: _t(j['versao']),
      criadoEm: _t(j['criado_em']),
      atualizadoEm: _t(j['atualizado_em']),
      licenca: _t(j['licenca']),
      nesteAparelho: neste is Map<String, dynamic> ? LicencaAdmin.deJson(neste) : null,
      outras: outras is List ? outras.whereType<Map<String, dynamic>>().map(LicencaAdmin.deJson).toList() : const [],
    );
  }

  final String id;
  final String appId;
  final String appNome;
  final String aparelho;
  final String codigo;
  final String status;
  final String nome;
  final String whatsapp;
  final String modelo;
  final String versao;
  final String criadoEm;
  final String atualizadoEm;
  final String licenca;
  final LicencaAdmin? nesteAparelho;

  /// Licencas do MESMO cliente (mesmo WhatsApp) em outros aparelhos.
  final List<LicencaAdmin> outras;

  bool get pendente => status == 'pendente';
  bool get aprovado => status == 'aprovado';
  bool get recusado => status == 'recusado';
}
