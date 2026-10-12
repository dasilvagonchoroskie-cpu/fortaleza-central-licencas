import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'controle.dart';
import 'servidor.dart';
import 'textos.dart';

/// Tela que o cliente ve enquanto o aparelho nao esta liberado.
///
/// Caminho principal, sem chave: nome + WhatsApp -> Pedir liberacao ->
/// aparece o codigo de verificacao e o botao do WhatsApp de quem vende.
/// Quando a Central libera, o app abre sozinho (a tela fica perguntando).
class TelaLiberacao extends StatefulWidget {
  const TelaLiberacao({super.key, required this.controle, required this.icone});

  final ControleLicenca controle;
  final IconData icone;

  @override
  State<TelaLiberacao> createState() => _TelaLiberacaoState();
}

class _TelaLiberacaoState extends State<TelaLiberacao> with WidgetsBindingObserver {
  late final TextEditingController _nome;
  late final TextEditingController _whatsapp;
  late final TextEditingController _chave;
  Timer? _relogio;
  bool _emPrimeiroPlano = true;
  bool _editando = false;

  ControleLicenca get c => widget.controle;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: c.nomeGuardado);
    _whatsapp = TextEditingController(text: c.whatsappGuardado);
    _chave = TextEditingController(text: c.chaveGuardada);
    WidgetsBinding.instance.addObserver(this);
    // Enquanto o pedido espera, pergunta ao servidor a cada 8 segundos: o
    // app abre sozinho assim que a Central liberar.
    _relogio = Timer.periodic(const Duration(seconds: 8), (_) {
      final p = c.pedido;
      if (_emPrimeiroPlano && p != null && p.pendente && !c.conferindo && !c.ocupado) {
        c.conferirAgora(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _nome.dispose();
    _whatsapp.dispose();
    _chave.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _emPrimeiroPlano = state == AppLifecycleState.resumed;
  }

  Future<void> _abrirWhatsApp() async {
    var abriu = false;
    try {
      abriu = await launchUrl(c.linkWhatsApp, mode: LaunchMode.externalApplication);
    } catch (_) {
      abriu = false;
    }
    if (!abriu && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui abrir o WhatsApp neste celular.')),
      );
    }
  }

  Future<void> _pedir() async {
    FocusScope.of(context).unfocus();
    final ok = await c.pedirLiberacao(nome: _nome.text, whatsapp: _whatsapp.text);
    if (ok && mounted) setState(() => _editando = false);
  }

  Future<void> _colarChave() async {
    String texto = '';
    try {
      texto = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    } catch (_) {
      texto = '';
    }
    final achada = extrairChave(texto, ignorar: c.codigoAparelho);
    if (!mounted) return;
    if (achada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não achei a chave no que está copiado. No WhatsApp, segure o dedo na mensagem '
              'com a chave, toque em Copiar e volte aqui.'),
        ),
      );
      return;
    }
    _chave.text = achada;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final tema = Theme.of(context);
        final cores = tema.colorScheme;
        final p = c.pedido;
        final soConfirmar = c.situacao == 'confirmar' || c.situacao == 'relogio' || c.situacao == 'sem_aparelho';
        final mostrarPendente = !soConfirmar && p != null && p.pendente && !_editando;
        final mostrarRecusado = !soConfirmar && p != null && p.recusado && !_editando;
        final mostrarFormulario = !soConfirmar && !mostrarPendente && !mostrarRecusado;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Cabecalho(icone: widget.icone, nome: c.config.nomeApp, subtitulo: _subtitulo()),
                      if (c.semInternet) ...[
                        const SizedBox(height: 16),
                        _Faixa(
                          icone: Icons.wifi_off,
                          texto: 'Sem internet. Ligue os dados do celular para pedir ou confirmar a liberação.',
                          cor: cores.tertiaryContainer,
                          corTexto: cores.onTertiaryContainer,
                        ),
                      ],
                      if (c.erro != null) ...[
                        const SizedBox(height: 16),
                        _Faixa(
                          icone: Icons.error_outline,
                          texto: c.erro!,
                          cor: cores.errorContainer,
                          corTexto: cores.onErrorContainer,
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (soConfirmar) _cartaoConfirmar(context),
                      if (mostrarPendente) _cartaoPendente(context, p),
                      if (mostrarRecusado) _cartaoRecusado(context),
                      if (mostrarFormulario) ...[
                        if (c.testeDisponivel && c.infoApp.testeDias > 0) ...[
                          _cartaoTeste(context),
                          const SizedBox(height: 14),
                        ],
                        _cartaoPedido(context),
                      ],
                      const SizedBox(height: 14),
                      _cartaoChave(context),
                      const SizedBox(height: 24),
                      _rodape(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _subtitulo() {
    switch (c.situacao) {
      case 'teste_acabou':
      case 'vencida':
      case 'bloqueada':
      case 'confirmar':
      case 'relogio':
      case 'sem_aparelho':
        if (c.motivo.isNotEmpty) return c.motivo;
        break;
    }
    return 'Para usar o ${c.config.nomeApp} neste celular, peça a liberação. É rápido e não precisa digitar chave.';
  }

  Widget _cartaoConfirmar(BuildContext context) {
    return _Cartao(
      titulo: 'Confirmar a licença',
      children: [
        Text(
          c.situacao == 'relogio'
              ? 'Acerte a data e a hora do celular (de preferência no automático) e toque em Tentar de novo.'
              : 'Com a internet ligada, toque em Tentar de novo. Seu aplicativo volta a abrir na hora.',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: c.conferindo ? null : () => c.conferirAgora(),
          icon: c.conferindo ? const _Girando() : const Icon(Icons.refresh),
          label: const Text('Tentar de novo'),
        ),
      ],
    );
  }

  Widget _cartaoPendente(BuildContext context, PedidoLiberacao p) {
    final tema = Theme.of(context);
    final preco = c.infoApp.preco;
    return _Cartao(
      titulo: 'Pedido enviado',
      children: [
        Text('Código de verificação', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        SelectableText(
          codigoPedidoLegivel(p.codigo),
          textAlign: TextAlign.center,
          style: tema.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            color: tema.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Fale com quem vende o aplicativo e informe este código. Assim que for liberado, '
          'o ${c.config.nomeApp} abre sozinho aqui — não feche esta tela.',
          textAlign: TextAlign.center,
        ),
        if (preco.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Valor: $preco', textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
        ],
        const SizedBox(height: 14),
        const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _abrirWhatsApp,
          icon: const Icon(Icons.chat),
          label: const Text('Falar no WhatsApp'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: c.conferindo ? null : () => c.conferirAgora(),
          icon: c.conferindo ? const _Girando() : const Icon(Icons.refresh),
          label: const Text('Já paguei — conferir agora'),
        ),
        TextButton(
          onPressed: () => setState(() => _editando = true),
          child: const Text('Corrigir nome ou WhatsApp'),
        ),
      ],
    );
  }

  Widget _cartaoRecusado(BuildContext context) {
    return _Cartao(
      titulo: 'Pedido não liberado',
      children: [
        const Text('O pedido deste aparelho foi recusado. Fale com quem vende o aplicativo para entender o que houve.'),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: _abrirWhatsApp, icon: const Icon(Icons.chat), label: const Text('Falar no WhatsApp')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => setState(() => _editando = true), child: const Text('Pedir de novo')),
      ],
    );
  }

  Widget _cartaoTeste(BuildContext context) {
    final dias = c.infoApp.testeDias;
    return _Cartao(
      titulo: 'Teste grátis',
      children: [
        Text('Use o ${c.config.nomeApp} de graça por $dias ${dias == 1 ? 'dia' : 'dias'}, sem compromisso.'),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: c.ocupado ? null : () => c.comecarTeste(),
          icon: c.ocupado ? const _Girando() : const Icon(Icons.play_circle_outline),
          label: Text('Começar teste grátis de $dias ${dias == 1 ? 'dia' : 'dias'}'),
        ),
      ],
    );
  }

  Widget _cartaoPedido(BuildContext context) {
    final tema = Theme.of(context);
    final preco = c.infoApp.preco;
    return _Cartao(
      titulo: 'Pedir liberação',
      children: [
        if (preco.isNotEmpty) ...[
          Text('Valor: $preco', style: tema.textTheme.titleMedium),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _nome,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Seu nome', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _pedir(),
          decoration: const InputDecoration(
            labelText: 'Seu WhatsApp com DDD',
            hintText: 'Ex.: 64 99999-8888',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: c.ocupado ? null : _pedir,
          icon: c.ocupado ? const _Girando() : const Icon(Icons.send),
          label: const Text('Pedir liberação'),
        ),
        const SizedBox(height: 10),
        Text(
          'Para liberar, o servidor da Fortaleza Digital Security recebe só o código deste aparelho, '
          'seu nome e seu WhatsApp.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _cartaoChave(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tema.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: c.chaveGuardada.isNotEmpty && c.situacao != 'sem_licenca',
        leading: const Icon(Icons.key_outlined),
        title: const Text('Tenho uma chave de ativação'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextField(
            controller: _chave,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            onChanged: (v) {
              final achada = v.length > 19 ? extrairChave(v, ignorar: c.codigoAparelho) : null;
              final m = achada ?? formatarChaveDigitada(v);
              if (m != v) {
                _chave.value = TextEditingValue(text: m, selection: TextSelection.collapsed(offset: m.length));
              }
            },
            decoration: InputDecoration(
              labelText: 'Chave',
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Colar chave',
                icon: const Icon(Icons.content_paste),
                onPressed: _colarChave,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: c.ocupado ? null : () => c.ativarComChave(_chave.text),
            icon: const Icon(Icons.lock_open),
            label: const Text('Ativar com a chave'),
          ),
        ],
      ),
    );
  }

  Widget _rodape(BuildContext context) {
    final tema = Theme.of(context);
    final codigo = c.codigoAparelho ?? '—';
    return Column(
      children: [
        Text('Código deste aparelho', style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SelectableText(codigo, style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1.5)),
            IconButton(
              tooltip: 'Copiar código',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: c.codigoAparelho == null
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: codigo));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado.')));
                    },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Fortaleza Digital Security',
            style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.icone, required this.nome, required this.subtitulo});

  final IconData icone;
  final String nome;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: tema.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icone, size: 38, color: tema.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: 14),
        Text(nome, textAlign: TextAlign.center, style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitulo, textAlign: TextAlign.center, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tema.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({required this.icone, required this.texto, required this.cor, required this.corTexto});

  final IconData icone;
  final String texto;
  final Color cor;
  final Color corTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: corTexto, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: corTexto))),
        ],
      ),
    );
  }
}

class _Girando extends StatelessWidget {
  const _Girando();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
}
