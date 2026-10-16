# Integrador da Central de Licenças

`integrar-licenca.py` liga a trava da Central num app Flutter **sem precisar
programar**. Ele põe sozinho:

1. a dependência do pacote `fortaleza_licenca` no `pubspec.yaml`;
2. o canal `fortaleza/licenca` (código do aparelho + modelo) no `MainActivity.kt`;
3. o portão (`PortaoLicenca`) em volta da tela inicial no `main.dart`;
4. a permissão de internet no `AndroidManifest.xml`.

## Como usar

```bash
python3 integrar-licenca.py --repo /caminho/do/app --apelido meuapp --nome "Meu App" --icone shield
```

- `--apelido` é o mesmo nome curto que você cadastra na Central (aba Apps).
- `--icone` é o ícone do portão (ex.: `shield`, `local_taxi`, `local_shipping`).
- `--sempre` faz a trava valer em **todas** as versões. Sem ele (padrão), a
  trava entra só no APK de venda direta (`--dart-define=LICENCA_CENTRAL=true`)
  e a versão da Play Store sai sem trava.

É seguro rodar duas vezes: se já estiver integrado, ele diz "sem mudança" e não
duplica nada. Quando não consegue mexer num arquivo com segurança, ele **para**
e mostra exatamente o que colar à mão, em vez de estragar o arquivo.

## Depois de rodar

1. Cadastre o app na Central (aba Apps) com o mesmo apelido.
2. Compile pela esteira do app. **Toda versão tem que sair assinada com a
   mesma chave** — senão o código do aparelho muda e o cliente perde a liberação.

## O que ele NÃO faz

- Não compila nem publica nada (quem faz isso é a esteira do app).
- Não transforma num app Flutter um app que não seja Flutter.
- Não tranca um app à distância: a trava precisa estar **dentro** do app e o
  app precisa ser recompilado. Cadastrar na Central, sozinho, não tranca um
  APK que não tem a trava — serve para os apps que já nasceram com ela.
