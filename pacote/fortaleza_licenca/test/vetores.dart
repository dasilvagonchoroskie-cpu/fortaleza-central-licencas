import 'package:fortaleza_licenca/fortaleza_licenca.dart';

/// Vetores de teste.
///
/// * Taximetro: liberacoes DE VERDADE, assinadas com a chave privada do
///   servidor para um aparelho de TESTE (ANDROID_ID ficticio). A chave
///   privada nunca entra no repositorio.
/// * Meu Frete (FDS2): assinadas com uma chave de TESTE gerada so para isto
///   (no mesmo formato e com o mesmo codigo do servidor, worker.js).

const codigoTaximetroTeste = 'YJPJ-P7EA-DG7B-5BEJ'; // taximetro + 'teste-automatico-nao-e-um-aparelho'
const chaveComprida = 'pbtr-ntvfbTgHkfKlrjc5ou39W2dx6i9ah-14orjNDjpTXkx51DybEZQbXZ3Fij6dehrYisnFWWiR99tnwpSlw';
const liberacaoComPrazo = 'eoZAicpEBqb4Z-FNbg9b7YFNLWaex7hzojPgpALKiRAukm0vbrjz1a_4_4fkTNOx5yNKIYcqKNvHt6bPY12rUA';

const chaveTeste = ChavePublica('dNsnHNo-ffUAj0d0P5tf-x8iHw5Z9j6wO0rU4oY8IPQ', 'BcsfJOhGfO3eqb6S2MP9oAq9vJCxnPLgM5gRdBrJV-A');
const codigoA = 'N5CP-VDJC-2QUV-QPFS'; // meufrete + 'aparelho-de-teste-a'
const codigoB = 'LZM2-3FFN-H3TQ-KUTE'; // meufrete + 'aparelho-de-teste-b'

const vitaliciaA = Liberacao(
  appId: 'meufrete',
  aparelho: codigoA,
  ate: '2027-01-10T00:00:00.000Z',
  plano: 'vitalicia',
  vence: 'sempre',
  assinatura: 'ExMH2qxp7KBMDZ0yy0uflNG1a09bq7mSPXFw_YK2dJ9Mic2MbC3yUrC5fuyd2OYtQmjobI-AWqTI8WiQn121Qw',
);

const prazoA = Liberacao(
  appId: 'meufrete',
  aparelho: codigoA,
  ate: '2026-11-01T00:00:00.000Z',
  plano: 'prazo',
  vence: '2026-11-01T00:00:00.000Z',
  assinatura: 'h_Y78QOaiphXdFnzQdcrMNwqUklXsWxAfocAu46WyElO3Y41q5zaUmbqCIcOPZHRC4pl17OmJouHK1sbDOWbYg',
);

const testeA = Liberacao(
  appId: 'meufrete',
  aparelho: codigoA,
  ate: '2026-10-20T00:00:00.000Z',
  plano: 'teste',
  vence: '2026-10-20T00:00:00.000Z',
  assinatura: 'Lj571twFGxnolvs0arOwaPSHA6uvVxyM4clzQt6n0lhbdSNLU4KinF0gELEWASAbVPXtSBVfCU9K08CTeckD5w',
);
