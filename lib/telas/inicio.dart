import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado.dart';
import 'apps.dart';
import 'gerar.dart';
import 'licencas.dart';
import 'mais.dart';
import 'pedidos.dart';

/// Tela principal: Pedidos, Gerar chave, Licencas, Apps e Mais.
class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key});

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> with WidgetsBindingObserver {
  int _aba = 0;
  Timer? _relogio;

  static const _titulos = ['Pedidos de liberação', 'Gerar chave', 'Licenças', 'Aplicativos', 'Mais'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Com a Central aberta, confere os pedidos a cada 30 segundos.
    _relogio = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final c = context.read<Central>();
      if (_aba == 0) {
        c.carregarPedidos();
      } else {
        c.atualizarResumo();
      }
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final c = context.read<Central>();
      c.atualizarResumo();
      c.carregarPedidos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<Central>();
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_aba]),
        actions: [
          if (c.conectado == false)
            IconButton(
              tooltip: 'Sem conexão com o servidor',
              icon: Icon(Icons.cloud_off, color: cores.error),
              onPressed: () => c.atualizarTudo(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (c.conectado == false && c.mensagemConexao.isNotEmpty)
            MaterialBanner(
              content: Text(c.mensagemConexao),
              leading: Icon(Icons.warning_amber, color: cores.error),
              actions: [TextButton(onPressed: () => c.atualizarTudo(), child: const Text('Tentar de novo'))],
            ),
          Expanded(
            child: IndexedStack(
              index: _aba,
              children: const [TelaPedidos(), TelaGerar(), TelaLicencas(), TelaApps(), TelaMais()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) {
          setState(() => _aba = i);
          if (i == 0) c.carregarPedidos();
          if (i == 2) c.carregarLicencas();
          if (i == 3) c.carregarApps();
        },
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: c.pendentes > 0,
              label: Text('${c.pendentes}'),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: c.pendentes > 0,
              label: Text('${c.pendentes}'),
              child: const Icon(Icons.inbox),
            ),
            label: 'Pedidos',
          ),
          const NavigationDestination(icon: Icon(Icons.key_outlined), selectedIcon: Icon(Icons.key), label: 'Gerar'),
          const NavigationDestination(
              icon: Icon(Icons.verified_user_outlined), selectedIcon: Icon(Icons.verified_user), label: 'Licenças'),
          const NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Apps'),
          const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}
