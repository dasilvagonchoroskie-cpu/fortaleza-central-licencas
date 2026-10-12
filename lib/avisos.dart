import 'package:flutter/services.dart';

/// Aviso de pedido novo no celular, mesmo com a Central fechada.
///
/// Quem faz o trabalho e o Android (AvisosWorker.kt): a cada 15 minutos,
/// com internet, ele pergunta ao servidor quantos pedidos estao esperando e
/// mostra uma notificacao quando chega um novo. Aqui so ligamos, desligamos
/// e passamos o endereco e a senha para ele.
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
}
