import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../comum.dart';
import '../estado.dart';
import '../versao.dart';
import 'recuperar.dart';

/// Avisos, WhatsApp padrao de venda, copia de seguranca, senha e servidor.
class TelaMais extends StatefulWidget {
  const TelaMais({super.key});

  @override
  State<TelaMais> createState() => _TelaMaisState();
}

class _TelaMaisState extends State<TelaMais> {
  final _whatsapp = TextEditingController();
  final _nova = TextEditingController();
  final _repete = TextEditingController();
  late final TextEditingController _endereco;
  String _copia = '';
  String _resumoCopia = '';
  bool _buscandoCopia = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<Central>();
    _endereco = TextEditingController(text: c.servidor.endereco);
    c.carregarAjustes().then((_) {
      if (mounted && _whatsapp.text.isEmpty) _whatsapp.text = whatsappLegivel(c.whatsappPadrao);
    });
  }

  @override
  void dispose() {
    _whatsapp.dispose();
    _nova.dispose();
    _repete.dispose();
    _endereco.dispose();
    super.dispose();
  }

  Future<void> _salvarWhatsapp() async {
    final c = context.read<Central>();
    final fone = whatsappNormalizado(_whatsapp.text);
    if (fone == null) {
      avisar(context, 'WhatsApp estranho. Use DDD + número, ex.: 64 99999-8888.', erro: true);
      return;
    }
    final r = await c.salvarWhatsappPadrao(fone);
    if (!mounted) return;
    avisar(context, r.ok ? 'WhatsApp padrão salvo.' : r.motivo, erro: !r.ok);
  }

  Future<void> _buscarCopia() async {
    final c = context.read<Central>();
    setState(() => _buscandoCopia = true);
    final r = await c.buscarCopia();
    if (!mounted) return;
    setState(() {
      _buscandoCopia = false;
      if (r.ok) {
        _copia = const JsonEncoder.withIndent('  ').convert(r.dados);
        _resumoCopia = '${r.lista('apps').length} aplicativo(s), ${r.lista('licencas').length} licença(s) e '
            '${r.lista('pedidos').length} pedido(s), em ${dataHora((r.dados['gerado_em'] ?? '').toString())}.';
      }
    });
    if (!r.ok) avisar(context, r.motivo, erro: true);
  }

  Future<void> _trocarSenha() async {
    final c = context.read<Central>();
    if (_nova.text.length < 10) {
      avisar(context, 'A senha nova precisa ter pelo menos 10 caracteres.', erro: true);
      return;
    }
    if (_nova.text != _repete.text) {
      avisar(context, 'As duas senhas não estão iguais.', erro: true);
      return;
    }
    final r = await c.trocarSenha(_nova.text);
    if (!mounted) return;
    if (r.ok) {
      _nova.clear();
      _repete.clear();
    }
    avisar(context, r.ok ? 'Senha trocada. A antiga não vale mais. Guarde a nova num lugar seguro.' : r.motivo, erro: !r.ok);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    TextStyle? titulo() => tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final dica = TextStyle(color: cores.onSurfaceVariant, fontSize: 13);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Cartao(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Avisar pedido novo', style: titulo()),
            subtitle: Text('O celular confere a cada 15 minutos e mostra uma notificação quando chega pedido.', style: dica),
            value: c.avisosLigados,
            onChanged: (v) => c.ligarAvisos(v),
          ),
        ),
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('WhatsApp padrão de venda', style: titulo()),
              const SizedBox(height: 4),
              Text('É com este número que o cliente fala na tela de liberação (quando o app não tem um próprio).', style: dica),
              const SizedBox(height: 12),
              TextField(controller: _whatsapp, keyboardType: TextInputType.phone, decoration: campo('WhatsApp', dica: 'Ex.: 64 99999-8888')),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _salvarWhatsapp, child: const Text('Salvar WhatsApp padrão')),
            ],
          ),
        ),
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cópia de segurança', style: titulo()),
              const SizedBox(height: 4),
              Text('Tudo o que está no servidor: aplicativos, licenças e pedidos. Copie e guarde fora do celular.', style: dica),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _buscandoCopia ? null : _buscarCopia,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Buscar a cópia'),
              ),
              if (_copia.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_resumoCopia),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => copiar(context, _copia, aviso: 'Cópia copiada. Cole onde quiser guardar.'),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copiar a cópia'),
                ),
              ],
            ],
          ),
        ),
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mudar senha', style: titulo()),
              const SizedBox(height: 4),
              Text('A senha nova vale na hora e a antiga para de valer.', style: dica),
              const SizedBox(height: 12),
              TextField(controller: _nova, obscureText: true, decoration: campo('Senha nova (pelo menos 10 caracteres)')),
              const SizedBox(height: 10),
              TextField(controller: _repete, obscureText: true, decoration: campo('Repita a senha nova')),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _trocarSenha, child: const Text('Mudar a senha')),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeNotifierProvider<Central>.value(value: c, child: const TelaRecuperar()),
                  ),
                ),
                child: const Text('Esqueci minha senha'),
              ),
            ],
          ),
        ),
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Servidor', style: titulo()),
              const SizedBox(height: 12),
              TextField(controller: _endereco, keyboardType: TextInputType.url, autocorrect: false, decoration: campo('Endereço')),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  await c.trocarEndereco(_endereco.text);
                  await c.atualizarTudo();
                  if (context.mounted) {
                    avisar(context, c.conectado == true ? 'Conversou certinho com o servidor.' : c.mensagemConexao,
                        erro: c.conectado != true);
                  }
                },
                child: const Text('Salvar e testar a conexão'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            if (await confirmar(context, 'Sair deste celular?',
                'Apaga a senha guardada aqui. Para entrar de novo, digite a senha de administrador.',
                sim: 'Sair', perigo: true)) {
              await c.sair();
            }
          },
          icon: Icon(Icons.logout, color: cores.error),
          label: Text('Sair (apagar a senha deste celular)', style: TextStyle(color: cores.error)),
        ),
        const SizedBox(height: 16),
        Text('Central de Licenças $versaoCentral (montagem $montagem)\nFortaleza Digital Security',
            textAlign: TextAlign.center, style: dica),
      ],
    );
  }
}
