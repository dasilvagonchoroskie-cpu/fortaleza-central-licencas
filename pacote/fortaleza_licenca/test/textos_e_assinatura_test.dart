import 'package:flutter_test/flutter_test.dart';
import 'package:fortaleza_licenca/fortaleza_licenca.dart';

import 'vetores.dart';

void main() {
  group('codigo do aparelho (igual ao taximetro desde a versao 1)', () {
    test('mesma conta do taximetro: o codigo de quem ja usa nao muda', () {
      expect(codigoDoAparelho('taximetro', '9774d56d682e549c'), '8EBJ-B4B4-MBE5-LY9Q');
      expect(codigoDoAparelho('taximetro', 'a1b2c3d4e5f60718'), 'TL8B-SHFZ-DAFW-CW2K');
      expect(codigoDoAparelho('taximetro', 'teste-automatico-nao-e-um-aparelho'), codigoTaximetroTeste);
    });

    test('cada app tem o seu codigo no mesmo celular', () {
      expect(codigoDoAparelho('meufrete', 'aparelho-de-teste-a'), codigoA);
      expect(codigoDoAparelho('meufrete', 'aparelho-de-teste-b'), codigoB);
      expect(codigoDoAparelho('meufrete', 'aparelho-de-teste-a'), isNot(codigoDoAparelho('taximetro', 'aparelho-de-teste-a')));
    });
  });

  group('chave digitada ou colada', () {
    const recado = 'Olá, Fabiano! Segue o aplicativo Taximetro.\n\n'
        '1) Baixe e instale o aplicativo por este link:\n'
        'https://github.com/dasilvagonchoroskie-cpu/taximetro/releases/download/apk-mais-recente/taximetro.apk\n\n'
        'Sua chave de ativação:\nYJJ4-3GVY-YMTH-7L6P\n\n'
        'A chave vale num celular só.\nFortaleza Digital Security';

    test('acha a chave no meio da mensagem do WhatsApp', () {
      expect(extrairChave(recado), 'YJJ4-3GVY-YMTH-7L6P');
    });

    test('chave sozinha, minuscula, sem tracos ou com espacos', () {
      expect(extrairChave('yjj4-3gvy-ymth-7l6p'), 'YJJ4-3GVY-YMTH-7L6P');
      expect(extrairChave(' yjj43gvyymth7l6p \n'), 'YJJ4-3GVY-YMTH-7L6P');
      expect(extrairChave('YJJ4 3GVY YMTH 7L6P'), 'YJJ4-3GVY-YMTH-7L6P');
    });

    test('ignora o codigo do proprio aparelho', () {
      expect(extrairChave(codigoTaximetroTeste, ignorar: codigoTaximetroTeste), isNull);
      expect(extrairChave('codigo $codigoTaximetroTeste e chave YJJ4-3GVY-YMTH-7L6P', ignorar: codigoTaximetroTeste),
          'YJJ4-3GVY-YMTH-7L6P');
    });

    test('nao inventa chave em texto comum nem em link', () {
      expect(extrairChave('para isso fica mais facil'), isNull);
      expect(extrairChave('responsabilidade'), isNull);
      expect(extrairChave('https://github.com/dasilvagonchoroskie-cpu/taximetro/releases/download/apk-mais-recente/taximetro.apk'),
          isNull);
      expect(extrairChave(''), isNull);
    });

    test('chave comprida antiga passa inteira', () {
      expect(extrairChave('Sua chave:\n$chaveComprida\nobrigado'), chaveComprida);
      expect(formatarChaveDigitada(' $chaveComprida \n'), chaveComprida);
    });

    test('formata enquanto digita', () {
      expect(formatarChaveDigitada('abcdefghjklmnpqr'), 'ABCD-EFGH-JKLM-NPQR');
      expect(chaveCurta('abcd efgh jklm npqr'), 'ABCD-EFGH-JKLM-NPQR');
      expect(chaveCurta('abc'), isNull);
    });
  });

  group('WhatsApp e textos', () {
    test('normaliza o numero como o servidor', () {
      expect(whatsappNormalizado('(64) 99999-8888'), '5564999998888');
      expect(whatsappNormalizado('64 3333-4444'), '556433334444');
      expect(whatsappNormalizado('+55 64 99999-8888'), '5564999998888');
      expect(whatsappNormalizado('123'), isNull);
      expect(whatsappNormalizado(''), isNull);
    });

    test('mostra bonito', () {
      expect(whatsappLegivel('5564999998888'), '(64) 99999-8888');
      expect(codigoPedidoLegivel('482913'), '482 913');
      expect(dataCurta(DateTime(2026, 11, 1, 10)), '01/11/2026');
    });
  });

  group('assinatura', () {
    test('liberacao antiga de VERDADE (chave do servidor) confere', () {
      expect(
        confereLegado(ChavePublica.fortaleza,
            appId: 'taximetro', aparelho: codigoTaximetroTeste, assinatura: chaveComprida, validade: 'sempre'),
        isTrue,
      );
      expect(
        confereLegado(ChavePublica.fortaleza,
            appId: 'taximetro', aparelho: codigoTaximetroTeste, assinatura: liberacaoComPrazo, validade: '2026-12-31'),
        isTrue,
      );
    });

    test('liberacao antiga nao serve em outro aparelho nem com outro prazo', () {
      expect(
        confereLegado(ChavePublica.fortaleza,
            appId: 'taximetro', aparelho: 'ZZZZ-ZZZZ-ZZZZ-ZZZZ', assinatura: chaveComprida, validade: 'sempre'),
        isFalse,
      );
      expect(
        confereLegado(ChavePublica.fortaleza,
            appId: 'taximetro', aparelho: codigoTaximetroTeste, assinatura: liberacaoComPrazo, validade: '2027-12-31'),
        isFalse,
      );
      expect(
        confereLegado(ChavePublica.fortaleza,
            appId: 'meufrete', aparelho: codigoTaximetroTeste, assinatura: chaveComprida, validade: 'sempre'),
        isFalse,
      );
    });

    test('liberacao nova (FDS2) confere com a chave do servidor que assinou', () {
      expect(vitaliciaA.confere(chaveTeste, appId: 'meufrete', aparelho: codigoA), isTrue);
      expect(prazoA.confere(chaveTeste, appId: 'meufrete', aparelho: codigoA), isTrue);
      expect(testeA.confere(chaveTeste, appId: 'meufrete', aparelho: codigoA), isTrue);
    });

    test('liberacao nova nao vale em outro aparelho, outro app ou adulterada', () {
      expect(vitaliciaA.confere(chaveTeste, appId: 'meufrete', aparelho: codigoB), isFalse);
      expect(vitaliciaA.confere(chaveTeste, appId: 'taximetro', aparelho: codigoA), isFalse);
      Liberacao mexida({String? ate, String? plano, String? vence, String? aparelho}) => Liberacao(
            appId: 'meufrete',
            aparelho: aparelho ?? codigoA,
            ate: ate ?? vitaliciaA.ate,
            plano: plano ?? vitaliciaA.plano,
            vence: vence ?? vitaliciaA.vence,
            assinatura: vitaliciaA.assinatura,
          );
      expect(mexida(ate: '2099-01-01T00:00:00.000Z').confere(chaveTeste, appId: 'meufrete', aparelho: codigoA), isFalse);
      expect(mexida(aparelho: codigoB).confere(chaveTeste, appId: 'meufrete', aparelho: codigoB), isFalse);
      final prazoVirandoVitalicia = Liberacao(
        appId: 'meufrete',
        aparelho: codigoA,
        ate: prazoA.ate,
        plano: 'vitalicia',
        vence: 'sempre',
        assinatura: prazoA.assinatura,
      );
      expect(prazoVirandoVitalicia.confere(chaveTeste, appId: 'meufrete', aparelho: codigoA), isFalse);
    });

    test('assinatura de outra chave (ex.: um servidor falso) nao vale', () {
      expect(vitaliciaA.confere(ChavePublica.fortaleza, appId: 'meufrete', aparelho: codigoA), isFalse);
    });

    test('lixo no lugar da assinatura nao quebra', () {
      expect(chaveTeste.confere('qualquer', ''), isFalse);
      expect(chaveTeste.confere('qualquer', 'abc'), isFalse);
      expect(chaveTeste.confere('qualquer', '!!!!'), isFalse);
    });

    test('guarda e le de volta igualzinho', () {
      final volta = Liberacao.deJson(vitaliciaA.paraJson());
      expect(volta.textoAssinado, vitaliciaA.textoAssinado);
      expect(volta.confere(chaveTeste, appId: 'meufrete', aparelho: codigoA), isTrue);
      expect(volta.vitalicia, isTrue);
      expect(prazoA.venceData, DateTime.utc(2026, 11, 1));
    });
  });
}
