# DiagnosticoWin

Scripts PowerShell para diagnosticar desempenho, disco, pastas e seguranca do Windows. Inclui uma ferramenta para analisar e, mediante confirmacao, remover arquivos temporarios antigos.

## Uso

Execute individualmente no Windows PowerShell:

```powershell
.\scripts\desempenho.ps1
.\scripts\disco_C.ps1
.\scripts\pastas.ps1
.\scripts\subpastas.ps1
.\scripts\security.ps1
.\scripts\limpeza.ps1
```

Para simular a limpeza sem excluir arquivos:

```powershell
.\scripts\limpeza.ps1 -WhatIf
```

A limpeza lista os arquivos com mais de 7 dias e so continua se voce digitar `EXCLUIR`. A idade nao garante que um arquivo seja dispensavel; revise a lista antes de confirmar.

Os logs ficam em `scripts\logs` e podem conter caminhos, processos e informacoes do computador. Essa pasta e ignorada pelo Git; nao publique os logs sem revisar e sanitizar.
