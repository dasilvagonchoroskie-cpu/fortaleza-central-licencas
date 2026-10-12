import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// Letras usadas nos codigos e chaves: sem I, O, 0 e 1 (que confundem).
const String alfabetoLicenca = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// "ABCDEFGH" -> "ABCD-EFGH".
String emGrupos(String s) => s.replaceAllMapped(RegExp(r'(.{4})(?=.)'), (m) => '${m[1]}-');

/// Codigo do aparelho: SHA-256("app|ANDROID_ID"), 10 primeiros bytes em
/// grupos de 5 bits, no formato XXXX-XXXX-XXXX-XXXX.
///
/// E a MESMA conta do taximetro desde a versao 1: o codigo de quem ja usa
/// o app nao muda. O ANDROID_ID depende da chave que assina o APK, entao
/// toda versao de um app tem que sair assinada com a mesma chave.
String codigoDoAparelho(String appId, String idBruto) {
  final hash = crypto.sha256.convert(utf8.encode('$appId|$idBruto')).bytes.sublist(0, 10);
  final bits = hash.map((b) => b.toRadixString(2).padLeft(8, '0')).join();
  final texto = StringBuffer();
  for (var i = 0; i + 5 <= bits.length; i += 5) {
    texto.write(alfabetoLicenca[int.parse(bits.substring(i, i + 5), radix: 2)]);
  }
  return emGrupos(texto.toString());
}

/// Chave curta no formato XXXX-XXXX-XXXX-XXXX, ou null se nao tiver 16.
String? chaveCurta(String digitada) {
  final limpa = digitada.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return limpa.length == 16 ? emGrupos(limpa) : null;
}

/// Acha a chave dentro de qualquer texto copiado (a mensagem inteira do
/// WhatsApp, por exemplo). Devolve a chave curta XXXX-XXXX-XXXX-XXXX, a
/// comprida do gerador de reserva antigo, ou null. Ignora o codigo deste
/// aparelho, que tem o mesmo formato e pode estar copiado.
String? extrairChave(String texto, {String? ignorar}) {
  final proprio = (ignorar ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  bool doAlfabeto(String s) => s.split('').every(alfabetoLicenca.contains);

  // 1) Chave curta com tracos, no meio do texto.
  final curta = RegExp(
    r'(?:^|[^A-Za-z0-9_-])([A-Za-z0-9]{4})-([A-Za-z0-9]{4})-([A-Za-z0-9]{4})-([A-Za-z0-9]{4})(?=$|[^A-Za-z0-9_-])',
  );
  for (final m in curta.allMatches(texto)) {
    final limpa = '${m[1]}${m[2]}${m[3]}${m[4]}'.toUpperCase();
    if (limpa == proprio || !doAlfabeto(limpa)) continue;
    return emGrupos(limpa);
  }

  // 2) Chave comprida do gerador de reserva (80+ caracteres seguidos).
  final comprida = RegExp(r'[A-Za-z0-9_-]{80,}').firstMatch(texto);
  if (comprida != null) return comprida[0];

  // 3) So a chave, sem tracos ou com espacos (o texto inteiro e a chave).
  final sozinha = texto.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (sozinha.length == 16 && sozinha != proprio && doAlfabeto(sozinha)) {
    return emGrupos(sozinha);
  }
  return null;
}

/// Formata enquanto o cliente digita. A chave comprida passa como esta.
String formatarChaveDigitada(String valor) {
  final semEspaco = valor.replaceAll(RegExp(r'\s'), '');
  if (semEspaco.length > 19) return semEspaco;
  final limpa = semEspaco.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return emGrupos(limpa.length > 16 ? limpa.substring(0, 16) : limpa);
}

/// WhatsApp no formato do servidor: so numeros, com 55 na frente.
/// Null se nao parecer telefone brasileiro com DDD.
String? whatsappNormalizado(String texto) {
  final d = texto.replaceAll(RegExp(r'\D'), '');
  if (d.length >= 12 && d.length <= 13 && d.startsWith('55')) return d;
  if (d.length == 10 || d.length == 11) return '55$d';
  return null;
}

/// "5564999998888" -> "(64) 99999-8888".
String whatsappLegivel(String numero) {
  var d = numero.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('55') && d.length >= 12) d = d.substring(2);
  if (d.length == 11) return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  if (d.length == 10) return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  return numero;
}

/// "482913" -> "482 913" (mais facil de ler e de ditar).
String codigoPedidoLegivel(String codigo) =>
    codigo.length == 6 ? '${codigo.substring(0, 3)} ${codigo.substring(3)}' : codigo;

/// Data local dd/mm/aaaa.
String dataCurta(DateTime d) {
  final l = d.toLocal();
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(l.day)}/${dois(l.month)}/${l.year}';
}
