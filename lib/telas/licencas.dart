import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../comum.dart';
import '../estado.dart';
import '../modelos.dart';
import '../tema.dart';

/// Todas as licencas: em qual celular estao, prazo, ultima vez que o app
/// conferiu e as acoes (esticar prazo, bloquear, soltar, revogar...).
class TelaLicencas extends StatefulWidget {
  const TelaLicencas({super.key});

  @override
  State<TelaLicencas> createState() => _TelaLicencasState();
}

class _TelaLicencasState extends State<TelaLicencas> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  bool _combina(LicencaAdmin l, String termo) {
    if (termo.isEmpty) return true;
    final t = termo.toLowerCase();
    final digitos = termo.replaceAll(RegExp(r'\D'), '');
    return l.chave.toLowerCase().contains(t) ||
        l.cliente.toLowerCase().contains(t) ||
        l.observacao.toLowerCase().contains(t) ||
        l.aparelho.toLowerCase().contains(t) ||
        l.modelo.toLowerCase().contains(t) ||
        (digitos.length >= 4 && l.whatsapp.contains(digitos));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    final cores = Theme.of(context).colorScheme;
    final lista = c.licencas.where((l) => _combina(l, _busca.text.trim())).toList();
    final emUso = c.licencas.where((l) => l.situacaoEm(c.agora) == 'em_uso').length;

    return RefreshIndicator(
      onRefresh: () => c.carregarLicencas(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          InputDecorator(
            decoration: campo('Aplicativo'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: c.filtroApp,
                isExpanded: true,
                isDense: true,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todos')),
                  for (final a in c.apps) DropdownMenuItem(value: a.id, child: Text(a.nome)),
                ],
                onChanged: (v) => c.carregarLicencas(appId: v ?? ''),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: campo(
              'Procurar',
              dica: 'Nome, chave, WhatsApp ou celular',
              sufixo: _busca.text.isEmpty
                  ? const Icon(Icons.search)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(_busca.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text('${c.licencas.length} licença(s) · $emUso em uso', style: TextStyle(color: cores.onSurfaceVariant)),
          const SizedBox(height: 10),
          if (c.carregandoLicencas && c.licencas.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (c.erroLicencas != null && c.licencas.isEmpty)
            Vazio(icone: Icons.cloud_off, texto: c.erroLicencas!, aoTentar: () => c.carregarLicencas())
          else if (lista.isEmpty)
            const Vazio(icone: Icons.verified_user_outlined, texto: 'Nenhuma licença por aqui.')
          else
            for (final l in lista) _CartaoLicenca(l),
        ],
      ),
    );
  }
}

class _CartaoLicenca extends StatelessWidget {
  const _CartaoLicenca(this.l);

  final LicencaAdmin l;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final situacao = l.situacaoEm(c.agora);
    final (selo, corSelo) = switch (situacao) {
      'bloqueada' => ('BLOQUEADA', corPerigo),
      'vencida' => (l.planoReal == 'teste' ? 'TESTE ACABOU' : 'VENCIDA', corPerigo),
      'em_uso' => ('EM USO', corAviso),
      _ => ('LIVRE', corDestaque),
    };

    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  l.chave,
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: cores.primary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Ações',
                onSelected: (v) => _acao(context, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '+30', child: Text('Esticar 30 dias')),
                  const PopupMenuItem(value: '+15', child: Text('Esticar 15 dias')),
                  if (!l.vitalicia) const PopupMenuItem(value: 'vitalicia', child: Text('Tornar vitalícia')),
                  const PopupMenuItem(value: 'revogar', child: Text('Revogar agora')),
                  if (l.aparelho.isNotEmpty) const PopupMenuItem(value: 'soltar', child: Text('Soltar do celular')),
                  PopupMenuItem(value: 'bloquear', child: Text(l.bloqueada ? 'Desbloquear' : 'Bloquear')),
                  const PopupMenuItem(value: 'editar', child: Text('Editar cliente')),
                  if (l.whatsapp.isNotEmpty) const PopupMenuItem(value: 'whatsapp', child: Text('Conversar no WhatsApp')),
                  const PopupMenuItem(value: 'copiar', child: Text('Copiar a chave')),
                  const PopupMenuItem(value: 'excluir', child: Text('Apagar a chave')),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Selo(selo, cor: corSelo),
              Selo(planoLegivel(l.planoReal).toUpperCase(), cor: corInfo),
              Selo(c.nomeDoApp(l.appId), cor: cores.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 6),
          if (l.cliente.isNotEmpty) Info('Cliente', l.cliente),
          if (l.whatsapp.isNotEmpty) Info('WhatsApp', whatsappLegivel(l.whatsapp)),
          if (l.aparelho.isNotEmpty) Info('Celular', l.modelo.isEmpty ? l.aparelho : '${l.modelo} (${l.aparelho})'),
          if (l.ativadaEm.isNotEmpty) Info('Ativada em', dataCurta(l.ativadaEm)),
          Info(
            l.vitalicia ? 'Prazo' : (situacao == 'vencida' ? 'Venceu em' : 'Vence em'),
            l.vitalicia ? 'vitalícia' : dataCurta(l.validade),
          ),
          if (l.ultimoContato.isNotEmpty)
            Info('Conferiu', '${haQuanto(l.ultimoContato, c.agora)}${l.versaoApp.isEmpty ? '' : ' · versão ${l.versaoApp}'}'),
          if (l.observacao.isNotEmpty) Info('Obs.', l.observacao),
        ],
      ),
    );
  }

  Future<void> _acao(BuildContext context, String acao) async {
    final c = context.read<Central>();
    Future<void> fazer(Future<Resposta> Function() acao, String sucesso) async {
      final r = await acao();
      if (context.mounted) avisar(context, r.ok ? sucesso : r.motivo, erro: !r.ok);
    }

    switch (acao) {
      case '+30':
      case '+15':
        final dias = acao == '+30' ? 30 : 15;
        await fazer(() => c.prazo(l.chave, dias), 'Prazo esticado em $dias dias. O app renova sozinho.');
      case 'vitalicia':
        if (await confirmar(context, 'Tornar vitalícia?', 'A chave ${l.chave} passa a valer para sempre neste celular.')) {
          await fazer(() => c.prazo(l.chave, 0), 'Agora é vitalícia.');
        }
      case 'revogar':
        if (await confirmar(
            context,
            'Revogar agora?',
            'O app trava na próxima vez que conferir a licença (ao abrir com internet, ou quando acabar a folga sem '
                'internet). Dá para desfazer esticando o prazo.',
            sim: 'Revogar',
            perigo: true)) {
          await fazer(() => c.revogar(l.chave), 'Revogada.');
        }
      case 'soltar':
        if (await confirmar(context, 'Soltar do celular?',
            'A chave volta a ficar livre e pode ser ativada em outro celular. O celular atual para na próxima conferência.')) {
          await fazer(() => c.soltar(l.chave), 'Chave solta.');
        }
      case 'bloquear':
        final bloquear = !l.bloqueada;
        if (await confirmar(
            context,
            bloquear ? 'Bloquear?' : 'Desbloquear?',
            bloquear
                ? 'O app deste cliente trava na próxima vez que conferir a licença.'
                : 'A licença volta a valer.',
            sim: bloquear ? 'Bloquear' : 'Desbloquear',
            perigo: bloquear)) {
          await fazer(() => c.bloquear(l.chave, bloquear), bloquear ? 'Bloqueada.' : 'Desbloqueada.');
        }
      case 'editar':
        await _editar(context, c);
      case 'whatsapp':
        await abrirWhatsApp(context, numero: l.whatsapp);
      case 'copiar':
        await copiar(context, l.chave, aviso: 'Chave copiada.');
      case 'excluir':
        if (await confirmar(context, 'Apagar a chave?',
            'Não dá para desfazer. Se ela estava num celular, o app para na próxima conferência.',
            sim: 'Apagar', perigo: true)) {
          await fazer(() => c.excluirLicenca(l.chave), 'Chave apagada.');
        }
    }
  }

  Future<void> _editar(BuildContext context, Central c) async {
    final cliente = TextEditingController(text: l.cliente);
    final fone = TextEditingController(text: l.whatsapp.isEmpty ? '' : whatsappLegivel(l.whatsapp));
    final obs = TextEditingController(text: l.observacao);
    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: cliente, textCapitalization: TextCapitalization.words, decoration: campo('Nome')),
              const SizedBox(height: 10),
              TextField(controller: fone, keyboardType: TextInputType.phone, decoration: campo('WhatsApp')),
              const SizedBox(height: 10),
              TextField(controller: obs, decoration: campo('Observação')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (salvar == true) {
      final r = await c.editarLicenca(l.chave, cliente: cliente.text.trim(), whatsapp: fone.text, observacao: obs.text.trim());
      if (context.mounted) avisar(context, r.ok ? 'Salvo.' : r.motivo, erro: !r.ok);
    }
  }
}
