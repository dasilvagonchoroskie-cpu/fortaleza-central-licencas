import 'chave_publica.dart';

/// Liberacao assinada pelo servidor (formato FDS2).
///
/// O servidor assina `FDS2|app|aparelho|ate|plano|vence`:
/// * [ate]: ate quando o app pode ficar sem falar com o servidor;
/// * [plano]: `vitalicia`, `prazo` ou `teste`;
/// * [vence]: data real da licenca (`sempre` na vitalicia).
///
/// Os textos sao guardados exatamente como vieram do servidor, porque a
/// assinatura e conferida sobre eles.
class Liberacao {
  const Liberacao({
    required this.appId,
    required this.aparelho,
    required this.ate,
    required this.plano,
    required this.vence,
    required this.assinatura,
    this.cliente = '',
  });

  factory Liberacao.deJson(Map<String, dynamic> j) => Liberacao(
        appId: _texto(j['app_id']),
        aparelho: _texto(j['aparelho']),
        ate: _texto(j['ate']),
        plano: _texto(j['plano']),
        vence: _texto(j['vence']),
        assinatura: _texto(j['assinatura']),
        cliente: _texto(j['cliente']),
      );

  final String appId;
  final String aparelho;
  final String ate;
  final String plano;
  final String vence;
  final String assinatura;
  final String cliente;

  Map<String, dynamic> paraJson() => {
        'app_id': appId,
        'aparelho': aparelho,
        'ate': ate,
        'plano': plano,
        'vence': vence,
        'assinatura': assinatura,
        'cliente': cliente,
      };

  /// O texto que o servidor assinou.
  String get textoAssinado => ['FDS2', appId, aparelho, ate, plano, vence].join('|');

  bool get vitalicia => vence == 'sempre';
  bool get teste => plano == 'teste';

  DateTime? get ateData => DateTime.tryParse(ate);
  DateTime? get venceData => vitalicia ? null : DateTime.tryParse(vence);

  /// A assinatura confere e a liberacao e deste app e deste aparelho?
  bool confere(ChavePublica chave, {required String appId, required String aparelho}) =>
      this.appId == appId && this.aparelho == aparelho && chave.confere(textoAssinado, assinatura);
}

/// Liberacao do formato antigo (servidor 1 e 2, taximetro ate a 3.1):
/// "app:codigo:validade" ou, na chave comprida do gerador de reserva,
/// "app:codigo".
bool confereLegado(
  ChavePublica chave, {
  required String appId,
  required String aparelho,
  required String assinatura,
  required String validade,
}) {
  final v = validade.isEmpty ? 'sempre' : validade;
  if (chave.confere('$appId:$aparelho:$v', assinatura)) return true;
  return v == 'sempre' && chave.confere('$appId:$aparelho', assinatura);
}

String _texto(Object? valor) => valor == null ? '' : valor.toString();
