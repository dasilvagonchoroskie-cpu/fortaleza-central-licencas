import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../comum.dart';
import '../estado.dart';

/// "Esqueci minha senha": troca a senha com o codigo de recuperacao (5
/// grupos de 5). Depois de usar, o servidor da um codigo NOVO — o antigo
/// para de valer, entao a tela so sai depois de anotar o novo.
class TelaRecuperar extends StatefulWidget {
  const TelaRecuperar({super.key, this.endereco});

  final String? endereco;

  @override
  State<TelaRecuperar> createState() => _TelaRecuperarState();
}

class _TelaRecuperarState extends State<TelaRecuperar> {
  final _codigo = TextEditingController();
  final _nova = TextEditingController();
  final _repete = TextEditingController();
  bool _trocando = false;
  String? _erro;
  String? _novoCodigo;

  @override
  void dispose() {
    _codigo.dispose();
    _nova.dispose();
    _repete.dispose();
    super.dispose();
  }

  Future<void> _trocar() async {
    FocusScope.of(context).unfocus();
    final codigo = _codigo.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    String? erro;
    if (codigo.length != 25) erro = 'O código tem 25 letras e números (5 grupos de 5).';
    if (erro == null && _nova.text.length < 10) erro = 'A senha nova precisa ter pelo menos 10 caracteres.';
    if (erro == null && _nova.text != _repete.text) erro = 'As duas senhas não estão iguais.';
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    setState(() {
      _trocando = true;
      _erro = null;
    });
    final r = await context.read<Central>().recuperarSenha(_codigo.text, _nova.text, endereco: widget.endereco);
    if (!mounted) return;
    setState(() {
      _trocando = false;
      if (r.ok) {
        _novoCodigo = (r.dados['novo_codigo'] ?? '').toString();
      } else {
        _erro = r.motivo;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final novo = _novoCodigo;
    return Scaffold(
      appBar: AppBar(title: const Text('Esqueci minha senha'), automaticallyImplyLeading: novo == null),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (novo == null) ...[
            Text('Use o código de recuperação que você guardou: 5 grupos de 5 letras e números.',
                style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: _codigo,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: campo('Código de recuperação', dica: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _nova, obscureText: true, decoration: campo('Senha nova (pelo menos 10 caracteres)')),
            const SizedBox(height: 12),
            TextField(controller: _repete, obscureText: true, decoration: campo('Repita a senha nova')),
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _trocando ? null : _trocar,
              child: Text(_trocando ? 'Conferindo o código...' : 'Trocar a senha com o código'),
            ),
          ] else ...[
            Cartao(
              destaque: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Senha trocada!', style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Agora anote o seu código de recuperação NOVO. O antigo não vale mais. '
                      'Guarde fora do celular (num papel, por exemplo).'),
                  const SizedBox(height: 16),
                  SelectableText(
                    novo,
                    textAlign: TextAlign.center,
                    style: tema.textTheme.titleLarge?.copyWith(
                      fontFamily: 'monospace',
                      color: corOuro,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => copiar(context, novo, aviso: 'Código novo copiado.'),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar código novo'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Já anotei')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const corOuro = Color(0xFFFDE9A8);
