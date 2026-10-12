# Central de Licenças — Fortaleza Digital Security

Este repositório tem duas coisas:

1. **A Central de Licenças 3** (Flutter) — o aplicativo de uso interno do
   Evandro que libera os apps vendidos: **Pedidos** (o cliente pede pelo
   próprio app; aqui você confere o código de verificação e toca em
   Liberar), **Gerar chave**, **Licenças** (prazo, bloquear, soltar,
   transferir, revogar), **Apps** (WhatsApp de venda, preço, teste grátis,
   enviar o app) e **Mais** (aviso de pedido novo, cópia de segurança,
   senha, servidor).
2. **O pacote `pacote/fortaleza_licenca`** — a licença que TODOS os apps
   vendidos usam (Taxímetro, Meu Frete, Fortaleza CRM e os próximos).
   Como ligar num app novo: `pacote/fortaleza_licenca/README.md`.

> **Este repositório precisa ficar PÚBLICO**: os outros apps baixam o
> pacote daqui na hora de compilar. Ele não tem segredo nenhum: a Central
> não leva senha dentro e o pacote só tem a chave **pública**.

## Segurança

- **O APK da Central não leva senha.** Na primeira vez, a senha de
  administrador é digitada e fica guardada só naquele celular.
- O APK é assinado com a chave própria da Central (segredos
  `CENTRAL_KEYSTORE_BASE64` e `CENTRAL_KEYSTORE_SENHA`), a mesma da 2.x:
  a versão 3 instala por cima. A esteira confere a impressão digital antes
  de publicar.

## Servidor

`https://fortaleza-licencas.fortalezadigitalsecurity.workers.dev`
(repositório privado `fortaleza-licencas`, versão 3).

## Esteira

A cada envio: pacote (análise + testes) → Central (análise + testes + APK
assinado). Na branch `main`, o APK vira Release `apk-mais-recente`. O
resumo da última montagem fica em `logs/ultima-montagem.txt`.

Versões do pacote usadas pelos apps: tags `licenca-v1`, `licenca-v2`...

## Histórico

- Até a 2.0: repositório privado `fortaleza-admin-licencas`, senha no APK.
- 2.1 a 2.3 (30/09 a 01/10/2026): HTML + Capacitor, sem senha no APK.
- 3.0 (11/10/2026): Flutter, pedidos de liberação sem chave, aviso de
  pedido novo, pacote de licença para todos os apps.
