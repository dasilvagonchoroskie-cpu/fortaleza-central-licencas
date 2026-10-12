/// Licenca dos aplicativos da Fortaleza Digital Security.
///
/// Cada app vendido embrulha a tela inicial no [PortaoLicenca]. O app so
/// abre no aparelho liberado pela Central de Licencas; nos outros, aparece
/// a tela de pedir liberacao (sem chave), o teste gratis e a chave curta.
library;

export 'src/chave_publica.dart';
export 'src/controle.dart';
export 'src/liberacao.dart';
export 'src/portao.dart';
export 'src/servidor.dart';
export 'src/tela_liberacao.dart';
export 'src/textos.dart';
