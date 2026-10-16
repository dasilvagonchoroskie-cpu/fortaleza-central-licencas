#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Integrador da Central de Licenças — liga a trava num app Flutter SEM precisar
programar.

O que ele faz, sozinho, num projeto Flutter:
  1. pubspec.yaml ...... adiciona a dependência do pacote fortaleza_licenca.
  2. MainActivity.kt .... adiciona o canal "fortaleza/licenca" (código do
                         aparelho + modelo), sem mexer no resto.
  3. main.dart ......... põe o portão (PortaoLicenca) em volta da tela inicial.
  4. AndroidManifest ... garante a permissão de internet.

Por padrão a trava entra só no APK de venda direta (quem compila com
--dart-define=LICENCA_CENTRAL=true); a versão da Play Store sai sem trava.
Com --sempre, a trava vale em todas as versões.

Depois de rodar, é só cadastrar o app na Central (aba Apps) com o mesmo
apelido. O integrador NÃO compila nada: quem compila é a esteira do app.

Uso:
  python3 integrar-licenca.py --repo /caminho/do/app --apelido meuapp \\
      --nome "Meu App" [--icone shield] [--sempre]

Ele é seguro de rodar duas vezes (não duplica nada) e, quando não consegue
mexer com segurança num arquivo, PARA e diz exatamente o que colar à mão, em
vez de estragar o arquivo.
"""
import argparse
import os
import re
import sys

REF_PACOTE = "8d208fbadafd65a681bd81473a4b49619b041b4c"  # licenca-v1
URL_PACOTE = "https://github.com/dasilvagonchoroskie-cpu/fortaleza-central-licencas.git"


class ParaComAviso(Exception):
    """Erro com instrução do que fazer à mão."""


def ler(caminho):
    with open(caminho, encoding="utf-8") as f:
        return f.read()


def gravar(caminho, texto):
    with open(caminho, "w", encoding="utf-8") as f:
        f.write(texto)


def achar_um(raiz, nome):
    achados = []
    for pasta, _, arquivos in os.walk(raiz):
        if nome in arquivos:
            achados.append(os.path.join(pasta, nome))
    return achados


# ----------------------------------------------------------------------- pubspec
def integrar_pubspec(repo):
    caminho = os.path.join(repo, "pubspec.yaml")
    if not os.path.exists(caminho):
        raise ParaComAviso("Não achei o pubspec.yaml — isto é um projeto Flutter?")
    texto = ler(caminho)
    if "fortaleza_licenca" in texto:
        return "pubspec.yaml: já tinha a dependência (sem mudança)."

    dep = (
        "  fortaleza_licenca:\n"
        "    git:\n"
        f"      url: {URL_PACOTE}\n"
        "      path: pacote/fortaleza_licenca\n"
        f"      # licenca-v1 (commit fixo do pacote)\n"
        f"      ref: {REF_PACOTE}\n"
    )
    # Entra logo depois de "flutter:\n    sdk: flutter" (padrão dos apps dele).
    m = re.search(r"\n(dependencies:\s*\n(?:[ \t]+flutter:\s*\n[ \t]+sdk:\s*flutter\s*\n))", texto)
    if m:
        pos = m.end(1)
        texto = texto[:pos] + dep + texto[pos:]
    else:
        m = re.search(r"\ndependencies:\s*\n", texto)
        if not m:
            raise ParaComAviso(
                "Não achei a seção 'dependencies:' no pubspec.yaml. Adicione à mão:\n\n" + dep
            )
        pos = m.end()
        texto = texto[:pos] + dep + texto[pos:]
    gravar(caminho, texto)
    return "pubspec.yaml: dependência fortaleza_licenca adicionada."


# ------------------------------------------------------------------- MainActivity
BLOCO_CANAL = """        // Central de Licenças: entrega o código do aparelho (ANDROID_ID) e o modelo.
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fortaleza/licenca")
            .setMethodCallHandler { chamada, resultado ->
                when (chamada.method) {
                    "idDoAparelho" -> resultado.success(
                        try {
                            android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ANDROID_ID)
                        } catch (e: Exception) {
                            null
                        } ?: "",
                    )
                    "modelo" -> resultado.success("${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}".trim())
                    else -> resultado.notImplemented()
                }
            }
"""

METODO_CONFIGURE = (
    "    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {\n"
    "        super.configureFlutterEngine(flutterEngine)\n"
    + BLOCO_CANAL
    + "    }\n"
)


def integrar_mainactivity(repo):
    achados = achar_um(os.path.join(repo, "android"), "MainActivity.kt")
    if not achados:
        raise ParaComAviso(
            "Não achei o MainActivity.kt. Cole, dentro da classe MainActivity, o método:\n\n" + METODO_CONFIGURE
        )
    caminho = achados[0]
    texto = ler(caminho)
    if 'fortaleza/licenca' in texto:
        return f"MainActivity.kt: já tinha o canal (sem mudança). [{os.path.relpath(caminho, repo)}]"

    if "configureFlutterEngine" in texto:
        # Insere o bloco logo depois do super.configureFlutterEngine(...).
        m = re.search(r"super\.configureFlutterEngine\([^\)]*\)\s*\n", texto)
        if not m:
            raise ParaComAviso(
                "Achei configureFlutterEngine mas não o super.configureFlutterEngine(...). "
                "Cole este bloco logo depois dele:\n\n" + BLOCO_CANAL
            )
        pos = m.end()
        texto = texto[:pos] + BLOCO_CANAL + texto[pos:]
    else:
        # Classe COM corpo: insere o método logo após a chave de abertura.
        m = re.search(r"class\s+MainActivity\b[^\{]*\{\s*\n", texto)
        if m:
            pos = m.end()
            texto = texto[:pos] + METODO_CONFIGURE + texto[pos:]
        else:
            # Classe de UMA LINHA (padrão do Flutter): "class MainActivity : FlutterActivity()"
            # — sem corpo. Vira uma classe com corpo e o método dentro.
            m = re.search(r"class\s+MainActivity\s*:\s*[A-Za-z0-9_.]*FlutterActivity\s*\(\s*\)\s*(?:\n|$)", texto)
            if not m:
                raise ParaComAviso(
                    "Não achei a classe MainActivity. Cole, dentro dela, o método:\n\n" + METODO_CONFIGURE
                )
            nova = "class MainActivity : FlutterActivity() {\n" + METODO_CONFIGURE + "}\n"
            texto = texto[:m.start()] + nova + texto[m.end():]
    gravar(caminho, texto)
    return f"MainActivity.kt: canal fortaleza/licenca adicionado. [{os.path.relpath(caminho, repo)}]"


# ------------------------------------------------------------------------ manifest
def integrar_manifest(repo):
    caminho = os.path.join(repo, "android", "app", "src", "main", "AndroidManifest.xml")
    if not os.path.exists(caminho):
        return "AndroidManifest.xml: não encontrado (confira a permissão de internet à mão)."
    texto = ler(caminho)
    if "android.permission.INTERNET" in texto:
        return "AndroidManifest.xml: permissão de internet já existia."
    m = re.search(r"(<manifest[^>]*>\s*\n)", texto)
    if not m:
        return "AndroidManifest.xml: não consegui achar a tag <manifest>; adicione a permissão de internet à mão."
    pos = m.end()
    linha = '    <uses-permission android:name="android.permission.INTERNET" />\n'
    texto = texto[:pos] + linha + texto[pos:]
    gravar(caminho, texto)
    return "AndroidManifest.xml: permissão de internet adicionada."


# ------------------------------------------------------------------------- main.dart
def integrar_main(repo, apelido, nome, versao, icone, sempre):
    caminho = os.path.join(repo, "lib", "main.dart")
    if not os.path.exists(caminho):
        raise ParaComAviso("Não achei o lib/main.dart.")
    texto = ler(caminho)
    if "PortaoLicenca" in texto and "fortaleza_licenca" in texto:
        return "main.dart: o portão já estava posto (sem mudança)."

    # 1) import
    if "package:fortaleza_licenca/fortaleza_licenca.dart" not in texto:
        m = re.search(r"(import\s+'package:flutter/material\.dart';\s*\n)", texto)
        if not m:
            raise ParaComAviso("Não achei o import do material.dart no main.dart.")
        pos = m.end()
        texto = texto[:pos] + "import 'package:fortaleza_licenca/fortaleza_licenca.dart';\n" + texto[pos:]

    # 2) config da licença + chave da trava, antes do void main(
    if sempre:
        cabecalho = (
            "\n/// Trava pela Central de Licenças (vale em todas as versões).\n"
            "const licencaCentral = true;\n"
        )
    else:
        cabecalho = (
            "\n/// Trava pela Central de Licenças. Entra só no APK de venda direta\n"
            "/// (compilado com --dart-define=LICENCA_CENTRAL=true).\n"
            "const licencaCentral = bool.fromEnvironment('LICENCA_CENTRAL', defaultValue: false);\n"
        )
    cabecalho += (
        "final _licencaFDS = ControleLicenca(const ConfiguracaoLicenca(\n"
        f"  appId: '{apelido}',\n"
        f"  nomeApp: '{nome}',\n"
        f"  versaoApp: '{versao}',\n"
        "));\n"
    )
    m = re.search(r"\n((?:Future<void>\s+|void\s+)main\s*\()", texto)
    if not m:
        raise ParaComAviso("Não achei a função main() no main.dart.")
    pos = m.start() + 1
    texto = texto[:pos] + cabecalho + texto[pos:]

    # 3) embrulha o home: da MaterialApp
    novo, trocas = re.subn(
        r"home:\s*(.+?),(\s*\n)",
        lambda g: (
            f"home: licencaCentral\n"
            f"            ? PortaoLicenca(controle: _licencaFDS, icone: Icons.{icone}, child: {g.group(1)})\n"
            f"            : {g.group(1)},{g.group(2)}"
        ),
        texto,
        count=1,
        flags=re.DOTALL,
    )
    if trocas != 1:
        raise ParaComAviso(
            "Não achei um 'home:' simples na MaterialApp para embrulhar. Embrulhe à mão assim:\n\n"
            "  home: licencaCentral\n"
            f"      ? PortaoLicenca(controle: _licencaFDS, icone: Icons.{icone}, child: SUA_TELA_INICIAL)\n"
            "      : SUA_TELA_INICIAL,\n"
        )
    gravar(caminho, novo)
    return "main.dart: portão da Central posto em volta da tela inicial."


def versao_do_pubspec(repo):
    try:
        m = re.search(r"\nversion:\s*([0-9]+\.[0-9]+\.[0-9]+)", ler(os.path.join(repo, "pubspec.yaml")))
        return m.group(1) if m else "1.0.0"
    except Exception:
        return "1.0.0"


def main():
    p = argparse.ArgumentParser(description="Liga a trava da Central de Licenças num app Flutter.")
    p.add_argument("--repo", required=True, help="pasta raiz do projeto Flutter")
    p.add_argument("--apelido", required=True, help="apelido do app no servidor (ex.: orbion)")
    p.add_argument("--nome", required=True, help="nome que aparece para o cliente (ex.: Orbion VPN)")
    p.add_argument("--icone", default="verified_user", help="ícone do portão (nome do Icons, ex.: shield)")
    p.add_argument("--versao", default=None, help="versão (padrão: a do pubspec)")
    p.add_argument("--sempre", action="store_true", help="trava em todas as versões (sem o modo Play Store)")
    a = p.parse_args()

    repo = os.path.abspath(a.repo)
    apelido = re.sub(r"[^a-z0-9-]", "", a.apelido.lower())
    if not apelido:
        print("ERRO: apelido inválido (use minúsculas, números e traço).")
        sys.exit(2)
    versao = a.versao or versao_do_pubspec(repo)

    print(f"Integrando a Central de Licenças em: {repo}")
    print(f"  apelido={apelido}  nome={a.nome}  versão={versao}  trava={'sempre' if a.sempre else 'só venda direta'}\n")

    passos = [
        lambda: integrar_pubspec(repo),
        lambda: integrar_manifest(repo),
        lambda: integrar_mainactivity(repo),
        lambda: integrar_main(repo, apelido, a.nome, versao, a.icone, a.sempre),
    ]
    try:
        for passo in passos:
            print("  ✓ " + passo())
    except ParaComAviso as e:
        print("\n  ✗ PAREI para não estragar o arquivo:\n")
        print("    " + str(e).replace("\n", "\n    "))
        sys.exit(1)

    print("\nPronto. Agora:")
    print(f"  1. Cadastre o app na Central (aba Apps) com o apelido '{apelido}'.")
    print("  2. Compile pela esteira do app. O APK de venda direta usa")
    print("     --dart-define=LICENCA_CENTRAL=true; a versão da Play Store, sem.")
    print("  Lembre: toda versão tem que sair assinada com a MESMA chave do app.")


if __name__ == "__main__":
    main()
