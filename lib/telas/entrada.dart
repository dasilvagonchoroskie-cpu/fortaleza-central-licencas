import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../comum.dart';
import '../estado.dart';
import 'recuperar.dart';

/// Primeiro acesso: a senha de administrador e digitada uma vez e fica
/// guardada so neste celular. O APK nao leva senha nenhuma.
class TelaEntrada extends StatefulWidget {
  const TelaEntrada({super.key});

  @override
  State<TelaEntrada> createState() => _TelaEntradaState();
}

class _TelaEntradaState extends State<TelaEntrada> {
  final _senha = TextEditingController();
  late final TextEditingController _endereco;
  bool _ver = false;
  bool _entrando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _endereco = TextEditingController(text: context.read<Central>().servidor.endereco);
  }

  @override
  void dispose() {
    _senha.dispose();
    _endereco.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _entrando = true;
      _erro = null;
    });
    final erro = await context.read<Central>().entrar(_senha.text, endereco: _endereco.text);
    if (!mounted) return;
    setState(() {
      _entrando = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.shield_outlined, size: 56, color: tema.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Central de Licenças',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Fortaleza Digital Security',
                      textAlign: TextAlign.center, style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  Text(
                    'Digite a senha de administrador. Ela fica guardada só neste celular — o aplicativo não leva '
                    'senha nenhuma, então o arquivo dele sozinho não libera nada.',
                    style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senha,
                    obscureText: !_ver,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _entrar(),
                    decoration: campo(
                      'Senha de administrador',
                      sufixo: IconButton(
                        tooltip: _ver ? 'Esconder' : 'Mostrar',
                        icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _ver = !_ver),
                      ),
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 10),
                    Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _entrando ? null : _entrar,
                    icon: _entrando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => TelaRecuperar(endereco: _endereco.text)),
                    ),
                    child: const Text('Esqueci minha senha'),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text('Servidor'),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      TextField(
                        controller: _endereco,
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        decoration: campo('Endereço do servidor'),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _endereco.text = ServidorAdmin.enderecoPadrao,
                          child: const Text('Voltar ao endereço padrão'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
