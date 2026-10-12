import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../comum.dart';
import '../estado.dart';
import '../modelos.dart';
import '../tema.dart';

/// Pedidos de liberacao que chegam dos apps dos clientes. Confira o codigo
/// de verificacao com o cliente no WhatsApp e toque em Liberar: o app dele
/// abre sozinho em alguns segundos.
class TelaPedidos extends StatelessWidget {
  const TelaPedidos({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    final lista = c.pedidos;
    return RefreshIndicator(
      onRefresh: () => c.carregarPedidos(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text('Esperando${c.pendentes > 0 ? ' (${c.pendentes})' : ''}')),
              const ButtonSegment(value: true, label: Text('Todos')),
            ],
            selected: {c.pedidosTodos},
            onSelectionChanged: (s) => c.carregarPedidos(todos: s.first),
          ),
          const SizedBox(height: 12),
          if (c.carregandoPedidos && lista.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (c.erroPedidos != null && lista.isEmpty)
            Vazio(icone: Icons.cloud_off, texto: c.erroPedidos!, aoTentar: () => c.carregarPedidos())
          else if (lista.isEmpty)
            Vazio(
              icone: Icons.inbox_outlined,
              texto: c.pedidosTodos
                  ? 'Nenhum pedido ainda.'
                  : 'Nenhum pedido esperando.\n\nQuando um cliente tocar em "Pedir liberação" no aplicativo, '
                      'o pedido aparece aqui com o código de verificação.',
            )
          else
            for (final p in lista) _CartaoPedido(p),
        ],
      ),
    );
  }
}

class _CartaoPedido extends StatelessWidget {
  const _CartaoPedido(this.p);

  final Pedido p;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final neste = p.nesteAparelho;
    return Cartao(
      destaque: p.pendente,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Selo(p.appNome, cor: corInfo),
              const Spacer(),
              Text(haQuanto(p.atualizadoEm, c.agora), style: TextStyle(color: cores.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(p.nome.isEmpty ? 'Sem nome' : p.nome,
              style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (p.whatsapp.isNotEmpty) Info('WhatsApp', whatsappLegivel(p.whatsapp)),
          if (p.modelo.isNotEmpty) Info('Celular', p.modelo),
          Info('Aparelho', p.aparelho),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: cores.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('Código de verificação', style: TextStyle(color: cores.onSurfaceVariant, fontSize: 12)),
                Text(
                  codigoLegivel(p.codigo),
                  style: tema.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: cores.primary,
                  ),
                ),
              ],
            ),
          ),
          if (neste != null) ...[
            const SizedBox(height: 8),
            Info('Este celular já teve', '${planoLegivel(neste.planoReal)} (${_situacaoTexto(neste, c.agora)})'),
          ],
          if (p.outras.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: corAviso.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                p.outras.length == 1
                    ? 'Este cliente já tem licença em outro celular (${p.outras.first.modelo.isEmpty ? p.outras.first.aparelho : p.outras.first.modelo}). '
                        'Se ele trocou de celular, use Transferir.'
                    : 'Este cliente já tem ${p.outras.length} licenças em outros celulares. Se trocou de celular, use Transferir.',
                style: const TextStyle(color: corAviso),
              ),
            ),
          ],
          if (!p.pendente) ...[
            const SizedBox(height: 8),
            Row(children: [
              Selo(p.aprovado ? 'LIBERADO' : 'RECUSADO', cor: p.aprovado ? corDestaque : corPerigo),
              if (p.licenca.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(p.licenca, style: TextStyle(color: cores.onSurfaceVariant, fontSize: 12)),
              ],
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (p.pendente)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _liberar(context, p),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Liberar'),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Conversar no WhatsApp',
                onPressed: p.whatsapp.isEmpty ? null : () => abrirWhatsApp(context, numero: p.whatsapp),
                icon: const Icon(Icons.chat),
              ),
              PopupMenuButton<String>(
                tooltip: 'Mais',
                onSelected: (v) => _acao(context, v),
                itemBuilder: (_) => [
                  if (p.pendente) const PopupMenuItem(value: 'recusar', child: Text('Recusar o pedido')),
                  const PopupMenuItem(value: 'copiar', child: Text('Copiar o código do aparelho')),
                  const PopupMenuItem(value: 'excluir', child: Text('Apagar o pedido')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _situacaoTexto(LicencaAdmin l, DateTime agora) {
    switch (l.situacaoEm(agora)) {
      case 'bloqueada':
        return 'bloqueada';
      case 'vencida':
        return 'venceu em ${dataCurta(l.validade)}';
      default:
        return l.vitalicia ? 'ativa' : 'vale até ${dataCurta(l.validade)}';
    }
  }

  Future<void> _acao(BuildContext context, String acao) async {
    final c = context.read<Central>();
    if (acao == 'copiar') {
      await copiar(context, p.aparelho, aviso: 'Código do aparelho copiado.');
      return;
    }
    if (acao == 'recusar') {
      if (!await confirmar(context, 'Recusar o pedido?',
          'O app de ${p.nome} mostra "pedido não liberado". Ele pode pedir de novo depois.',
          sim: 'Recusar', perigo: true)) {
        return;
      }
      final r = await c.recusar(p);
      if (context.mounted) avisar(context, r.ok ? 'Pedido recusado.' : r.motivo, erro: !r.ok);
      return;
    }
    if (acao == 'excluir') {
      if (!await confirmar(context, 'Apagar o pedido?', 'Some da lista. A licença (se houver) continua igual.',
          sim: 'Apagar', perigo: true)) {
        return;
      }
      final r = await c.excluirPedido(p);
      if (context.mounted) avisar(context, r.ok ? 'Pedido apagado.' : r.motivo, erro: !r.ok);
    }
  }

  Future<void> _liberar(BuildContext context, Pedido p) async {
    final central = context.read<Central>();
    final r = await showModalBottomSheet<Resposta>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<Central>.value(value: central, child: FolhaLiberar(pedido: p)),
    );
    if (r == null || !context.mounted) return;
    if (!r.ok) {
      avisar(context, r.motivo, erro: true);
      return;
    }
    final validade = (r.dados['validade'] ?? '').toString();
    final nomeApp = (r.dados['app_nome'] ?? p.appNome).toString();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: corDestaque, size: 40),
        title: const Text('Liberado!'),
        content: Text(
          'O $nomeApp de ${p.nome} abre sozinho em alguns segundos (se a tela do pedido estiver aberta) '
          'ou na próxima vez que ele abrir o aplicativo.\n\n'
          '${validade.isEmpty ? 'Licença vitalícia.' : 'Vale até ${dataCurta(validade)}.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              abrirWhatsApp(
                context,
                numero: p.whatsapp,
                texto: recadoLiberado(nomeApp: nomeApp, cliente: p.nome, validade: validade),
              );
            },
            icon: const Icon(Icons.chat),
            label: const Text('Avisar no WhatsApp'),
          ),
        ],
      ),
    );
  }
}

/// Escolha do prazo (ou transferencia) e confirmacao da liberacao.
class FolhaLiberar extends StatefulWidget {
  const FolhaLiberar({super.key, required this.pedido});

  final Pedido pedido;

  @override
  State<FolhaLiberar> createState() => _FolhaLiberarState();
}

class _FolhaLiberarState extends State<FolhaLiberar> {
  static const _prazos = <int, String>{0: 'Vitalícia', 30: '30 dias', 60: '60 dias', 90: '90 dias', 180: '6 meses', 365: '1 ano'};

  int _dias = 0;
  String? _transferir;
  bool _liberando = false;

  Pedido get p => widget.pedido;

  Future<void> _confirmar() async {
    setState(() => _liberando = true);
    final r = await context.read<Central>().aprovar(p, dias: _dias, transferir: _transferir);
    if (mounted) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Liberar ${p.nome}', style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text('${p.appNome} · código ${codigoLegivel(p.codigo)}', style: TextStyle(color: cores.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (p.outras.isNotEmpty) ...[
            Text('O cliente trocou de celular?', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Licença nova'),
                  selected: _transferir == null,
                  onSelected: (_) => setState(() => _transferir = null),
                ),
                for (final o in p.outras)
                  ChoiceChip(
                    label: Text('Transferir ${o.chave.substring(0, o.chave.length >= 4 ? 4 : o.chave.length)}…'
                        '${o.modelo.isEmpty ? '' : ' (${o.modelo})'}'),
                    selected: _transferir == o.chave,
                    onSelected: (_) => setState(() => _transferir = o.chave),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _transferir == null
                  ? 'Cria uma licença nova para este celular. A do outro celular continua valendo.'
                  : 'A mesma licença (com o mesmo prazo) passa para este celular. O celular antigo para de funcionar '
                      'na próxima vez que conferir a licença.',
              style: TextStyle(color: cores.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],
          if (_transferir == null) ...[
            Text('Prazo', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _prazos.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _dias == e.key,
                    onSelected: (_) => setState(() => _dias = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _dias == 0
                  ? 'Pagou tudo: vale para sempre neste celular. Ainda dá para bloquear ou transferir pela Central.'
                  : 'Vale ${_prazos[_dias]}. Antes de vencer, estique o prazo em Licenças quando ele pagar; '
                      'o app renova sozinho.',
              style: TextStyle(color: cores.onSurfaceVariant, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _liberando ? null : _confirmar,
            icon: _liberando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_open),
            label: Text(_transferir == null ? 'Liberar agora' : 'Transferir e liberar'),
          ),
        ],
      ),
    );
  }
}
