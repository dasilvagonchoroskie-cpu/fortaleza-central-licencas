# fortaleza_licenca

Pacote Flutter da licença dos aplicativos da Fortaleza Digital Security.
O app só abre no aparelho liberado pela **Central de Licenças**; nos outros
aparece a tela de **Pedir liberação** (nome + WhatsApp → código de
verificação → o dono libera na Central → o app abre sozinho), o **teste
grátis** (se o app tiver) e a **chave de ativação**.

## Ligar num app novo (4 passos)

1. **pubspec.yaml**

   ```yaml
   dependencies:
     fortaleza_licenca:
       git:
         url: https://github.com/dasilvagonchoroskie-cpu/fortaleza-central-licencas.git
         path: pacote/fortaleza_licenca
         ref: 8d208fbadafd65a681bd81473a4b49619b041b4c  # licenca-v1
   ```

2. **MainActivity.kt** — o canal que entrega o código do aparelho:

   ```kotlin
   import android.os.Build
   import android.provider.Settings
   import io.flutter.embedding.engine.FlutterEngine
   import io.flutter.plugin.common.MethodChannel

   override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
       super.configureFlutterEngine(flutterEngine)
       MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fortaleza/licenca")
           .setMethodCallHandler { chamada, resultado ->
               when (chamada.method) {
                   "idDoAparelho" -> resultado.success(
                       try { Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) } catch (e: Exception) { null } ?: "")
                   "modelo" -> resultado.success("${Build.MANUFACTURER} ${Build.MODEL}".trim())
                   else -> resultado.notImplemented()
               }
           }
   }
   ```

   E a permissão de internet no `AndroidManifest.xml` (main):
   `<uses-permission android:name="android.permission.INTERNET"/>`

3. **main.dart** — o portão em volta da tela inicial:

   ```dart
   final licenca = ControleLicenca(const ConfiguracaoLicenca(
     appId: 'meuapp',          // o apelido cadastrado na Central (aba Apps)
     nomeApp: 'Meu App',
     versaoApp: '1.0.0',
   ));

   MaterialApp(
     home: PortaoLicenca(controle: licenca, icone: Icons.apps, child: const TelaInicial()),
   );
   ```

4. **Cadastrar o app na Central** (aba Apps), com o mesmo apelido. Lá
   também ficam o WhatsApp de venda, o preço e os dias de teste grátis.

## Regra de ouro: sempre a mesma chave de assinatura

O código do aparelho vem do `ANDROID_ID`, que no Android depende da chave
que assina o APK. **Toda versão do app tem que sair assinada com a mesma
chave** (guardada nos segredos do GitHub do app). Assim a atualização
instala por cima e o cliente continua liberado.

## Como funciona por dentro

- Liberação assinada pelo servidor (`FDS2|app|aparelho|ate|plano|vence`,
  ECDSA P-256). O app confere com a chave pública: ninguém fabrica nem
  estica liberação.
- Abre sem internet enquanto a liberação estiver dentro da janela (até
  90 dias). Com internet, renova em silêncio a cada 6 horas no máximo.
- Reinstalou ou perdeu os dados: o app pergunta ao servidor e volta sozinho.
- Bloqueio ou transferência feitos na Central valem na próxima abertura
  (nunca derrubam a tela no meio do trabalho).
- Relógio do celular voltado para trás: não vale sem internet.
- `prefixoLegado`: aceita a licença antiga do app (ex.: `taxi.licenca` no
  taxímetro 3.1) e a transforma em licença nova sozinha.
- `PortaoLicenca(ativo: false)`: o portão some (ex.: versão da Play Store,
  onde a própria loja cobra).
