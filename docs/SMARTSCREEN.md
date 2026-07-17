# SmartScreen e integridade

A beta pode aparecer como **editor desconhecido**, pois o projeto não possui certificado comercial para assinar o instalador.

- Baixe somente da prerelease oficial em `cristianohsm/celular-gamepad-pc`.
- Compare o SHA-256 local com o arquivo `.sha256` da mesma prerelease.
- Não desative SmartScreen, Microsoft Defender ou outras proteções.
- Use **Mais informações** somente quando o hash corresponder exatamente ao publicado.

Exemplo:

```powershell
Get-FileHash .\CelularGamepad-Setup-v1.4.0-beta.2.exe -Algorithm SHA256
Get-AuthenticodeSignature .\CelularGamepad-Setup-v1.4.0-beta.2.exe
```
