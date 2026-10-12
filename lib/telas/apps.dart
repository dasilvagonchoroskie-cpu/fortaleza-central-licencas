import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../comum.dart';
import '../estado.dart';
import '../modelos.dart';
import '../tema.dart';

/// Aplicativos que passam pela Central. Cada um tem o apelido que vem
/// dentro do app, o link do APK, o WhatsApp de venda, o preco e os dias
/// de teste gratis (tudo isso aparece na tela de liberacao do cliente).
class TelaApps extends StatelessWidget {
  const TelaApps({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFormularioApp(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo app'),
      ),
      body: RefreshIndicator(
        onRefresh: () => c.carregarApps(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text(
              'Versão nova de um app NÃO precisa de cadastro novo: as licenças continuam no mesmo apelido.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (c.erroApps != null && c.apps.isEmpty)
              Vazio(icone: Icons.cloud_off, texto: c.erroApps!, aoTentar: () => c.carregarApps())
            else if (c.apps.isEmpty)
              const Vazio(icone: Icons.apps, texto: 'Nenhum aplicativo cadastrado ainda.')
            else
              for (final a in c.apps) _CartaoApp(a),
          ],
        ),
      ),
    );
  }
}

class _CartaoApp extends StatelessWidget {
  const _CartaoApp(this.a);

  final AppCadastrado a;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(a.nome, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              if (a.pendentes > 0) Selo('${a.pendentes} PEDIDO(S)', cor: corAviso),
            ],
          ),
          Info('Apelido', a.id),
          Info('Licenças', '${a.chaves}'),
          Info('Teste grátis', a.testeDias > 0 ? '${a.testeDias} dias' : 'não tem'),
          Info('Preço', a.preco.isEmpty ? 'não informado' : a.preco),
          Info('WhatsApp de venda',
              a.whatsapp.isEmpty ? 'o padrão (${c.whatsappPadrao.isEmpty ? 'Mais › Ajustes' : whatsappLegivel(c.whatsappPadrao)})' : whatsappLegivel(a.whatsapp)),
          Info('Link do APK', a.link.isEmpty ? 'sem link — o APK vai à parte' : a.link),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => abrirWhatsApp(context, texto: recadoEnviarApp(nomeApp: a.nome, link: a.link)),
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar o app'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Editar',
                onPressed: () => abrirFormularioApp(context, app: a),
                icon: const Icon(Icons.edit),
              ),
              if (a.chaves == 0)
                IconButton(
                  tooltip: 'Apagar',
                  onPressed: () => _apagar(context),
                  icon: Icon(Icons.delete_outline, color: cores.error),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _apagar(BuildContext context) async {
    final c = context.read<Central>();
    if (!await confirmar(context, 'Apagar ${a.nome}?', 'Ele não tem nenhuma licença. Os pedidos dele também somem.',
        sim: 'Apagar', perigo: true)) {
      return;
    }
    final r = await c.apagarApp(a.id);
    if (context.mounted) avisar(context, r.ok ? 'Apagado.' : r.motivo, erro: !r.ok);
  }
}

Future<void> abrirFormularioApp(BuildContext context, {AppCadastrado? app}) {
  final central = context.read<Central>();
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider<Central>.value(value: central, child: FormularioApp(app: app)),
  ));
}

/// Cadastro e edicao de um aplicativo.
class FormularioApp extends StatefulWidget {
  const FormularioApp({super.key, this.app});

  final AppCadastrado? app;

  @override
  State<FormularioApp> createState() => _FormularioAppState();
}

class _FormularioAppState extends State<FormularioApp> {
  late final TextEditingController _id;
  late final TextEditingController _nome;
  late final TextEditingController _link;
  late final TextEditingController _whatsapp;
  late final TextEditingController _preco;
  late final TextEditingController _teste;
  bool _salvando = false;

  bool get _editando => widget.app != null;

  @override
  void initState() {
    super.initState();
    final a = widget.app;
    _id = TextEditingController(text: a?.id ?? '');
    _nome = TextEditingController(text: a?.nome ?? '');
    _link = TextEditingController(text: a?.link ?? '');
    _whatsapp = TextEditingController(text: (a == null || a.whatsapp.isEmpty) ? '' : whatsappLegivel(a.whatsapp));
    _preco = TextEditingController(text: a?.preco ?? '');
    _teste = TextEditingController(text: (a == null || a.testeDias == 0) ? '' : '${a.testeDias}');
  }

  @override
  void dispose() {
    for (final c in [_id, _nome, _link, _whatsapp, _preco, _teste]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final c = context.read<Central>();
    FocusScope.of(context).unfocus();
    final id = _id.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
    final nome = _nome.text.trim();
    final link = _link.text.trim();
    final fone = whatsappNormalizado(_whatsapp.text);
    final teste = int.tryParse(_teste.text.trim().isEmpty ? '0' : _teste.text.trim());
    String? erro;
    if (id.isEmpty || nome.isEmpty) erro = 'Preencha o apelido e o nome.';
    if (erro == null && link.isNotEmpty && !link.toLowerCase().startsWith('https://')) {
      erro = 'O link tem que começar com https://';
    }
    if (erro == null && fone == null) erro = 'WhatsApp de venda estranho. Use DDD + número ou deixe em branco.';
    if (erro == null && (teste == null || teste < 0 || teste > 90)) erro = 'Teste grátis: de 0 a 90 dias.';
    if (erro != null) {
      avisar(context, erro, erro: true);
      return;
    }
    setState(() => _salvando = true);
    final r = await c.salvarApp(id: id, nome: nome, link: link, whatsapp: fone ?? '', preco: _preco.text.trim(), testeDias: teste ?? 0);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (!r.ok) {
      avisar(context, r.motivo, erro: true);
      return;
    }
    Navigator.of(context).pop();
    avisar(context, 'Salvo.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar ${widget.app!.nome}' : 'Novo aplicativo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _id,
            readOnly: _editando,
            autocorrect: false,
            decoration: campo(
              'Apelido (o mesmo que vem dentro do app)',
              dica: 'Ex.: meufrete',
              ajuda: _editando ? 'O apelido não muda: é ele que liga o app às licenças.' : 'Minúsculas, números e traço, sem espaço.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _nome, textCapitalization: TextCapitalization.words, decoration: campo('Nome que aparece')),
          const SizedBox(height: 12),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: campo('Link de download do APK (opcional)', dica: 'https://...'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: campo(
              'WhatsApp de venda (opcional)',
              dica: 'Ex.: 64 99999-8888',
              ajuda: 'O cliente fala com este número na tela de liberação. Vazio = o WhatsApp padrão (Mais › Ajustes).',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _preco,
            decoration: campo('Preço (opcional)', dica: 'Ex.: R\$ 150 à vista ou R\$ 30 por mês', ajuda: 'Aparece para o cliente na tela de liberação.'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teste,
            keyboardType: TextInputType.number,
            decoration: campo(
              'Teste grátis (dias)',
              dica: '0',
              ajuda: 'Com dias aqui, o cliente libera sozinho um teste de graça (uma vez por celular). Vazio ou 0 = sem teste.',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: const Icon(Icons.save),
            label: const Text('Salvar aplicativo'),
          ),
        ],
      ),
    );
  }
}
