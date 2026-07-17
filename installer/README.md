# Instalador Windows

O instalador `1.4.0-beta.2` é compilado com Inno Setup 6.7.1 a partir de um staging auditado. Os binários oficiais baixados ficam em `installer/downloads/`; staging e saída ficam em `installer/staging/` e `installer/output/`. Nenhum desses diretórios é versionado.

```powershell
./scripts/build_installer.ps1
./scripts/audit_installer.ps1
./scripts/test_installed_app.ps1
```

O tipo **Instalação padrão** inclui Emuladores e Jogos de PC. **Somente Emuladores** não instala nem inicia HIDMaestro. O desinstalador preserva o componente compartilhado por padrão.
