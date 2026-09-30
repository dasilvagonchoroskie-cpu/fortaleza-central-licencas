# Central de Licenças — Fortaleza Digital Security

Aplicativo de uso interno que gera as chaves que liberam os aplicativos
exclusivos (ex.: o taxímetro) — um celular por chave, com prazo opcional,
soltar do celular, bloquear e cópia de segurança.

## Segurança
- **O APK não leva senha nenhuma.** Na primeira vez, a senha de
  administrador é digitada em Ajustes e fica guardada só naquele celular.
  Se o arquivo do APK vazar, ele sozinho não libera nada — por isso este
  repositório pode ser público.
- A esteira confere que nenhuma senha foi parar no APK antes de publicar.
- O APK é assinado com a chave própria da Central (segredos
  `CENTRAL_KEYSTORE_BASE64` e `CENTRAL_KEYSTORE_SENHA`), então toda versão
  nova instala por cima da anterior.

## Servidor
`https://fortaleza-licencas.fortalezadigitalsecurity.workers.dev`
(repositório privado `fortaleza-licencas`). A esteira confere se ele está
no ar antes de montar.

## Histórico
Até a versão 2.0 a Central morava no repositório privado
`fortaleza-admin-licencas`, com a senha embutida no APK. Em 30/09/2026
mudou para cá, sem senha no APK.
