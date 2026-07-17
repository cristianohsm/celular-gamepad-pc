# Desinstalação

O desinstalador encerra processos pertencentes à pasta instalada, neutraliza controles virtuais, remove atalhos, arquivos do programa e a regra **Celular Gamepad — Rede Local**.

Por padrão, `%LOCALAPPDATA%\CelularGamepad` e o HIDMaestro são preservados. Isso mantém preferências e evita remover um componente que pode ser compartilhado por outros programas.

Durante uma desinstalação interativa existe uma confirmação separada para remover os pacotes de driver HIDMaestro identificados pelo provedor e pelos INF oficiais. Essa opção não remove ViGEmBus nem certificados de terceiros. Use-a somente quando tiver certeza de que nenhum outro programa depende do componente.
