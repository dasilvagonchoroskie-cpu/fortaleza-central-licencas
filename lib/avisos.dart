import 'package:flutter/services.dart';

/// Aviso de pedido novo no celular, mesmo com a Central fechada.
///
/// Quem faz o trabalho e o Android: um monitor em primeiro plano
/// (MonitorService) que, a cada ~45 segundos, pergunta ao servidor se chegou
/// pedido novo e mostra a notificacao na hora. O agendador de 15 em 15 min
/// (AvisosJob) fica de reserva. Aqui so ligamos, desligamos, passamos o
/// endereco e a senha, testamos e pedimos a isencao de bateria.
class Avisos {
  const Avisos._();

  static const MethodChannel _canal = MethodChannel('central/avisos');

  static Future<void> configurar({
    required String servidor,
    required String senha,
    required bool ligado,
    bool ativo = true,
  }) async {
    if (!ativo) return;
    try {
      await _canal.invokeMethod<void>('configurar', {'servidor': servidor, 'senha': senha, 'ligado': ligado});
    } catch (_) {
      // Sem o lado Android (ex.: testes): segue sem aviso.
    }
  }

  /// Android 13 em diante pergunta se pode mostrar notificacao.
  static Future<void> pedirPermissao({bool ativo = true}) async {
    if (!ativo) return;
    try {
      await _canal.invokeMethod<void>('pedirPermissao');
    } catch (_) {}
  }

  /// Os pedidos ate este momento ja foram vistos: nao avisa de novo.
  static Future<void> marcarVisto(String ultimo, {bool ativo = true}) async {
    if (!ativo) return;
    try {
      await _canal.invokeMethod<void>('marcarVisto', {'ultimo': ultimo});
    } catch (_) {}
  }

  /// Mostra uma notificacao de teste. Devolve false se a permissao de
  /// notificacao estiver negada (ai o dono precisa liberar nas configuracoes).
  static Future<bool> testar({bool ativo = true}) async {
    if (!ativo) return true;
    try {
      return (await _canal.invokeMethod<bool>('testar')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pede para o Android nao "economizar" o monitor (entrega mais firme).
  static Future<void> pedirIsencaoBateria({bool ativo = true}) async {
    if (!ativo) return;
    try {
      await _canal.invokeMethod<void>('pedirIsencaoBateria');
    } catch (_) {}
  }
}
