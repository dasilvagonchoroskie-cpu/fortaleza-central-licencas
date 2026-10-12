import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../comum.dart';
import '../estado.dart';

/// Gerar chave de ativacao (caminho alternativo ao pedido pelo app). Util
/// para vender antes de o cliente instalar, ou dar de presente.
class TelaGerar extends StatefulWidget {
  const TelaGerar({super.key});

  @override
  State<TelaGerar> createState() => _TelaGerarState();
}

class _TelaGerarState extends State<TelaGerar> {
  static const _prazos = <int, String>{0: 'Vitalícia', 15: '15 dias', 30: '30 dias', 60: '60 dias', 90: '90 dias', 365: '1 ano'};

  final _cliente = TextEditingController();
  final _whatsapp = TextEditingController();
  final _obs = TextEditingController();
  String _app = '';
  int _dias = 0;
  bool _gerando = false;

  // Chave gerada (mostrada no cartao de baixo).
  String _chave = '';
  String _nomeApp = '';
  String _link = '';
  String _validade = '';
  String _clienteDaChave = '';
  String _foneDaChave = '';

  @override
  void dispose() {
    _cliente.dispose();
    _whatsapp.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _gerar() async {
    final c = context.read<Central>();
    FocusScope.of(context).unfocus();
    if (_app.isEmpty) {
      avisar(context, 'Escolha o aplicativo.', erro: true);
      return;
    }
    final fone = whatsappNormalizado(_whatsapp.text);
    if (fone == null) {
      avisar(context, 'WhatsApp estranho. Use DDD + número (ex.: 64 99999-8888) ou deixe em branco.', erro: true);
      return;
    }
    setState(() => _gerando = true);
    final r = await c.gerar(appId: _app, cliente: _cliente.text.trim(), whatsapp: fone, observacao: _obs.text.trim(), dias: _dias);
    if (!mounted) return;
    setState(() => _gerando = false);
    if (!r.ok) {
      avisar(context, r.motivo, erro: true);
      return;
    }
    setState(() {
      _chave = (r.dados['chave'] ?? '').toString();
      _nomeApp = (r.dados['app_nome'] ?? c.nomeDoApp(_app)).toString();
      _link = (r.dados['link'] ?? '').toString();
      _validade = (r.dados['validade'] ?? '').toString();
      _clienteDaChave = _cliente.text.trim();
      _foneDaChave = fone;
      _cliente.clear();
      _whatsapp.clear();
      _obs.clear();
    });
    avisar(context, 'Chave criada e guardada no servidor.');
  }

  String get _recado =>
      recadoChave(nomeApp: _nomeApp, chave: _chave, link: _link, cliente: _clienteDaChave, validade: _validade);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    if (_app.isNotEmpty && c.appPorId(_app) == null) _app = '';
    if (_app.isEmpty && c.apps.length == 1) _app = c.apps.first.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'O jeito mais fácil é o cliente pedir a liberação pelo próprio aplicativo (aba Pedidos). '
          'A chave serve para vender antes, dar de presente ou quando o cliente preferir.',
          style: TextStyle(color: cores.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: campo('Aplicativo'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _app.isEmpty ? null : _app,
              isExpanded: true,
              isDense: true,
              hint: const Text('Escolha o aplicativo'),
              items: [for (final a in c.apps) DropdownMenuItem(value: a.id, child: Text(a.nome))],
              onChanged: (v) => setState(() => _app = v ?? ''),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: _cliente, textCapitalization: TextCapitalization.words, decoration: campo('Nome do cliente')),
        const SizedBox(height: 12),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          decoration: campo('WhatsApp do cliente (opcional)', dica: 'Ex.: 64 99999-8888'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _obs, decoration: campo('Observação (opcional)', dica: 'Ex.: pagou no Pix')),
        const SizedBox(height: 16),
        Text('Prazo', style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _prazos.entries)
              ChoiceChip(label: Text(e.value), selected: _dias == e.key, onSelected: (_) => setState(() => _dias = e.key)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _dias == 0
              ? 'Pagou tudo. Ainda dá para bloquear ou transferir pela Central.'
              : 'Com prazo, o app renova sozinho enquanto você for esticando a data em Licenças. Se parar, ele trava no dia.',
          style: TextStyle(color: cores.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _gerando ? null : _gerar,
          icon: _gerando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.key),
          label: const Text('Gerar chave'),
        ),
        if (_chave.isNotEmpty) ...[
          const SizedBox(height: 20),
          Cartao(
            destaque: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Chave do $_nomeApp', textAlign: TextAlign.center, style: TextStyle(color: cores.onSurfaceVariant)),
                const SizedBox(height: 6),
                SelectableText(
                  _chave,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: cores.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vale num celular só. ${_validade.isEmpty ? 'Vitalícia.' : 'Vence em ${dataCurta(_validade)}.'}'
                  '${_link.isEmpty ? '\nEste app não tem link de download (aba Apps): mande o APK junto.' : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cores.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => abrirWhatsApp(context, numero: _foneDaChave, texto: _recado),
                  icon: const Icon(Icons.chat),
                  label: Text(_foneDaChave.isEmpty ? 'Mandar pelo WhatsApp' : 'Mandar para ${whatsappLegivel(_foneDaChave)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => copiar(context, _recado, aviso: 'Recado copiado. É só colar no WhatsApp.'),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copiar o recado'),
                ),
                TextButton(
                  onPressed: () => copiar(context, _chave, aviso: 'Chave copiada.'),
                  child: const Text('Copiar só a chave'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
