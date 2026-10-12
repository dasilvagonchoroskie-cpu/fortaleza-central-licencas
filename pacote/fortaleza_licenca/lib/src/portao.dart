import 'package:flutter/material.dart';

import 'controle.dart';
import 'tela_liberacao.dart';

/// Portao de licenca: mostra o app ([child]) so no aparelho liberado.
/// Fora isso, mostra a tela de pedir liberacao.
///
/// Uso, dentro do MaterialApp:
///
/// ```dart
/// home: PortaoLicenca(controle: controle, icone: Icons.local_taxi, child: TelaInicial()),
/// ```
///
/// Com [ativo] falso (ex.: versao da Play Store, onde a loja cuida do
/// pagamento), o portao some e o app abre direto.
class PortaoLicenca extends StatefulWidget {
  const PortaoLicenca({
    super.key,
    required this.controle,
    required this.child,
    this.icone = Icons.verified_user_outlined,
    this.ativo = true,
  });

  final ControleLicenca controle;
  final Widget child;
  final IconData icone;
  final bool ativo;

  @override
  State<PortaoLicenca> createState() => _PortaoLicencaState();
}

class _PortaoLicencaState extends State<PortaoLicenca> with WidgetsBindingObserver {
  bool _avisouVencimento = false;

  @override
  void initState() {
    super.initState();
    if (!widget.ativo) return;
    WidgetsBinding.instance.addObserver(this);
    widget.controle.addListener(_aoMudar);
    widget.controle.iniciar();
  }

  @override
  void dispose() {
    if (widget.ativo) {
      WidgetsBinding.instance.removeObserver(this);
      widget.controle.removeListener(_aoMudar);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controle.aoVoltarParaOApp();
  }

  void _aoMudar() {
    final c = widget.controle;
    if (c.estado != EstadoLicenca.liberado) return;
    String? aviso;
    if (c.consumirAvisoLiberado()) {
      aviso = 'Pronto! ${c.config.nomeApp} liberado neste aparelho.';
    } else if (!_avisouVencimento && c.liberacao != null && !c.liberacao!.vitalicia) {
      final dias = c.diasRestantes;
      if (dias != null && dias <= 5) {
        _avisouVencimento = true;
        final quando = dias == 0 ? 'hoje' : (dias == 1 ? 'amanhã' : 'em $dias dias');
        aviso = c.liberacao!.teste
            ? 'Seu teste grátis termina $quando.'
            : 'Sua licença vence $quando. Fale com quem vendeu para renovar.';
      }
    }
    if (aviso == null) return;
    final texto = aviso;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(texto), duration: const Duration(seconds: 5)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ativo) return widget.child;
    return ListenableBuilder(
      listenable: widget.controle,
      builder: (context, _) {
        switch (widget.controle.estado) {
          case EstadoLicenca.liberado:
            return widget.child;
          case EstadoLicenca.bloqueado:
            return TelaLiberacao(controle: widget.controle, icone: widget.icone);
          case EstadoLicenca.carregando:
            return _Carregando(icone: widget.icone, nome: widget.controle.config.nomeApp);
        }
      },
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando({required this.icone, required this.nome});

  final IconData icone;
  final String nome;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: cores.primary),
            const SizedBox(height: 16),
            Text(nome, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: 12),
            Text('Conferindo a licença...', style: TextStyle(color: cores.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
