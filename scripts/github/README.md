# GitHub Cards

Este diretório contém um backlog inicial derivado da análise do repositório.

## Arquivos

- `next-step-cards.json`: fonte dos cards sugeridos
- `create-next-step-issues.ps1`: cria issues no GitHub usando `gh`

## Pré-requisitos

- GitHub CLI autenticado com permissão no repositório
- labels já existentes ou permissão para criá-las manualmente antes

## Uso

Criar issues no repositório remoto detectado a partir do `origin`:

```powershell
.\scripts\github\create-next-step-issues.ps1
```

Criar issues em um repositório específico:

```powershell
.\scripts\github\create-next-step-issues.ps1 -Repo "ALXAVIER-DEV/Data-journey"
```

Criar issues e adicionar ao GitHub Project:

```powershell
.\scripts\github\create-next-step-issues.ps1 `
  -Repo "ALXAVIER-DEV/Data-journey" `
  -ProjectOwner "ALXAVIER-DEV" `
  -ProjectNumber 1
```

## Observação

Os cards foram gerados a partir do código local. Se o board atual no GitHub já tiver itens parecidos, revise o JSON antes de executar o script para evitar duplicidade.
