import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart'
    show ECCurve_secp256r1, ECDSASigner, ECPublicKey, ECSignature, PublicKeyParameter, SHA256Digest;

/// Chave PUBLICA do servidor de licencas (ECDSA P-256).
///
/// So confere assinaturas. Quem assina e o servidor, com a chave privada
/// que nunca sai de la: por isso ninguem fabrica uma liberacao nem estica
/// o prazo mexendo no celular.
class ChavePublica {
  const ChavePublica(this.x, this.y);

  /// A chave do servidor da Fortaleza Digital Security (a mesma que o
  /// taximetro usa desde 14/09/2026).
  static const ChavePublica fortaleza = ChavePublica(
    'yBHKjFLZZJzoY1l490yRD3ru9ROE03gS9C3XH0Gb0v4',
    '-sa1VYlT3Fvxhh9fJEaav3VO69vM5qiiJ3yE5io-AJw',
  );

  /// Coordenadas da chave, em base64url (formato JWK).
  final String x;
  final String y;

  /// A assinatura (base64url, 64 bytes r||s) confere com o [texto]?
  bool confere(String texto, String assinaturaBase64url) {
    final assinatura = base64urlParaBytes(assinaturaBase64url);
    if (assinatura == null || assinatura.length != 64) return false;
    final bx = base64urlParaBytes(x);
    final by = base64urlParaBytes(y);
    if (bx == null || by == null) return false;
    try {
      final dominio = ECCurve_secp256r1();
      final publica = ECPublicKey(dominio.curve.createPoint(_inteiro(bx), _inteiro(by)), dominio);
      final verificador = ECDSASigner(SHA256Digest())..init(false, PublicKeyParameter<ECPublicKey>(publica));
      return verificador.verifySignature(
        Uint8List.fromList(utf8.encode(texto)),
        ECSignature(_inteiro(assinatura.sublist(0, 32)), _inteiro(assinatura.sublist(32))),
      );
    } catch (_) {
      return false;
    }
  }
}

/// base64url (com ou sem "=" no fim) para bytes. Null se nao for valido.
Uint8List? base64urlParaBytes(String texto) {
  final limpo = texto.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  if (limpo.isEmpty) return null;
  try {
    return base64Url.decode(base64Url.normalize(limpo));
  } catch (_) {
    return null;
  }
}

BigInt _inteiro(List<int> bytes) => bytes.fold(BigInt.zero, (a, b) => (a << 8) | BigInt.from(b));
