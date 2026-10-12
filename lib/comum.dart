import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================ TEXTOS ============================

String _dois(int n) => n.toString().padLeft(2, '0');

/// "2026-10-31T18:05:29.926Z" -> "31/10/2026" (hora do celular).
String dataCurta(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final l = d.toLocal();
  return '${_dois(l.day)}/${_dois(l.month)}/${l.year}';
}

/// "2026-10-31T18:05:29.926Z" -> "31/10/2026 15:05".
String dataHora(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final l = d.toLocal();
  return '${dataCurta(iso)} ${_dois(l.hour)}:${_dois(l.minute)}';
}

/// "agora", "há 5 min", "há 3 h", "há 2 dias", ou a data.
String haQuanto(String iso, DateTime agora) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final s = agora.difference(d).inSeconds;
  if (s < 60) return 'agora';
  if (s < 3600) return 'há ${s ~/ 60} min';
  if (s < 86400) return 'há ${s ~/ 3600} h';
  final dias = s ~/ 86400;
  if (dias < 30) return dias == 1 ? 'há 1 dia' : 'há $dias dias';
  return 'em ${dataCurta(iso)}';
}

/// So numeros, com 55 na frente. Vazio = sem numero. Null = estranho.
String? whatsappNormalizado(String texto) {
  final d = texto.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return '';
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

/// "482913" -> "482 913".
String codigoLegivel(String c) => c.length == 6 ? '${c.substring(0, 3)} ${c.substring(3)}' : c;

String primeiroNome(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  return partes.isEmpty ? '' : partes.first;
}

String planoLegivel(String plano) {
  switch (plano) {
    case 'vitalicia':
      return 'Vitalícia';
    case 'teste':
      return 'Teste grátis';
    case 'prazo':
      return 'Com prazo';
  }
  return plano;
}

// ============================ RECADOS ============================

/// Recado para mandar o aplicativo: o cliente instala e pede a liberacao
/// pelo proprio app (caminho principal, sem chave).
String recadoEnviarApp({required String nomeApp, required String link, String cliente = ''}) {
  final ola = primeiroNome(cliente).isEmpty ? 'Olá!' : 'Olá, ${primeiroNome(cliente)}!';
  final baixar = link.isEmpty
      ? '1) Instale o arquivo do aplicativo que mandei junto.'
      : '1) Baixe e instale o aplicativo por este link:\n$link';
  return '$ola Segue o aplicativo $nomeApp.\n\n'
      '$baixar\n\n'
      '2) Abra o aplicativo, escreva seu nome e WhatsApp e toque em "Pedir liberação".\n\n'
      '3) Me mande o código de 6 números que aparecer. Assim que eu liberar, o aplicativo abre sozinho.\n\n'
      'Fortaleza Digital Security';
}

/// Recado com a chave (caminho alternativo).
String recadoChave({
  required String nomeApp,
  required String chave,
  String link = '',
  String cliente = '',
  String validade = '',
}) {
  final ola = primeiroNome(cliente).isEmpty ? 'Olá!' : 'Olá, ${primeiroNome(cliente)}!';
  final baixar = link.isEmpty
      ? '1) Instale o arquivo do aplicativo que mandei junto.'
      : '1) Baixe e instale o aplicativo por este link:\n$link';
  final prazo = validade.isEmpty
      ? ''
      : 'Seu acesso está liberado até ${dataCurta(validade)}. Mantendo o pagamento em dia, ele renova sozinho.\n';
  return '$ola Segue o aplicativo $nomeApp.\n\n'
      '$baixar\n\n'
      '2) Toque e segure nesta mensagem e toque em Copiar.\n\n'
      '3) Abra o aplicativo, toque em "Tenho uma chave de ativação" e depois em Colar e Ativar, com a internet ligada.\n\n'
      'Sua chave de ativação:\n$chave\n\n'
      'A chave vale num celular só.\n$prazo\n'
      'Fortaleza Digital Security';
}

/// Recado de "liberado" depois de aprovar o pedido.
String recadoLiberado({required String nomeApp, String cliente = '', String validade = ''}) {
  final ola = primeiroNome(cliente).isEmpty ? 'Olá!' : 'Olá, ${primeiroNome(cliente)}!';
  final prazo = validade.isEmpty
      ? 'A licença é vitalícia neste celular.'
      : 'Está liberado até ${dataCurta(validade)}. Mantendo o pagamento em dia, eu renovo e ele continua sozinho.';
  return '$ola Seu aplicativo $nomeApp foi liberado. Se ele ainda estiver aberto na tela do pedido, '
      'em alguns segundos ele abre sozinho; se não, é só abrir de novo.\n\n'
      '$prazo\n\n'
      'Obrigado! Fortaleza Digital Security';
}

// ============================ ACOES ============================

/// Abre o WhatsApp (na conversa do numero, se tiver) com o texto escrito.
Future<void> abrirWhatsApp(BuildContext context, {String numero = '', String texto = ''}) async {
  final n = (whatsappNormalizado(numero) ?? '');
  final uri = Uri.parse('https://wa.me/$n${texto.isEmpty ? '' : '?text=${Uri.encodeComponent(texto)}'}');
  var abriu = false;
  try {
    abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    abriu = false;
  }
  if (!abriu && context.mounted) avisar(context, 'Não consegui abrir o WhatsApp neste celular.', erro: true);
}

Future<void> copiar(BuildContext context, String texto, {String aviso = 'Copiado.'}) async {
  await Clipboard.setData(ClipboardData(text: texto));
  if (context.mounted) avisar(context, aviso);
}

void avisar(BuildContext context, String texto, {bool erro = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(texto),
    backgroundColor: erro ? Theme.of(context).colorScheme.error : null,
    duration: Duration(seconds: erro ? 6 : 3),
  ));
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String sim = 'Confirmar', bool perigo = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
        FilledButton(
          style: perigo ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(sim),
        ),
      ],
    ),
  );
  return r == true;
}

// ============================ PECAS DE TELA ============================

InputDecoration campo(String rotulo, {String? dica, Widget? sufixo, String? ajuda}) => InputDecoration(
      labelText: rotulo,
      hintText: dica,
      helperText: ajuda,
      helperMaxLines: 3,
      suffixIcon: sufixo,
      border: const OutlineInputBorder(),
    );

/// Cartao com borda, no padrao da Central.
class Cartao extends StatelessWidget {
  const Cartao({super.key, required this.child, this.destaque = false, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final bool destaque;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cores.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: destaque ? cores.primary : cores.outlineVariant, width: destaque ? 1.5 : 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Etiqueta colorida (EM USO, LIVRE, BLOQUEADA...).
class Selo extends StatelessWidget {
  const Selo(this.texto, {super.key, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
      child: Text(texto, style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    );
  }
}

/// Lista vazia ou com erro, com o botao de tentar de novo.
class Vazio extends StatelessWidget {
  const Vazio({super.key, required this.icone, required this.texto, this.aoTentar});

  final IconData icone;
  final String texto;
  final VoidCallback? aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icone, size: 44, color: cores.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: TextStyle(color: cores.onSurfaceVariant)),
          if (aoTentar != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: aoTentar, icon: const Icon(Icons.refresh), label: const Text('Tentar de novo')),
          ],
        ],
      ),
    );
  }
}

/// Linha de informacao: rotulo apagado + valor.
class Info extends StatelessWidget {
  const Info(this.rotulo, this.valor, {super.key});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$rotulo: ', style: TextStyle(color: cores.onSurfaceVariant)),
        TextSpan(text: valor),
      ])),
    );
  }
}
