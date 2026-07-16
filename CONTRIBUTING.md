# Como contribuir

1. Crie um fork e uma branch curta a partir de `main`.
2. Faça mudanças focadas, preservando Windows 10/11 e Python 3.10+.
3. Não inclua `runtime/`, `config.json`, segredos, PINs, IPs locais, logs ou pacotes ZIP.
4. Execute:

   ```powershell
   python -m py_compile server.py test_server.py
   python -m unittest -v
   ```

5. Envie um pull request explicando a motivação, o teste realizado e qualquer impacto de compatibilidade.

Evite dependências externas e alterações de arquitetura sem uma justificativa clara. Testes nunca devem pressionar teclas reais: injete ou simule o teclado.
