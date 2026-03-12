param(
    [string]$Repo = "",
    [string]$CardsFile = "scripts/github/next-step-cards.json",
    [string]$ProjectOwner = "",
    [int]$ProjectNumber = 0
)

$ErrorActionPreference = "Stop"

function Test-GitHubCliInstalled {
    $command = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $command) {
        throw @"
GitHub CLI ('gh') nao foi encontrado no PATH.

Instale o GitHub CLI e reabra o PowerShell:
- winget install --id GitHub.cli
- ou choco install gh

Depois autentique:
- gh auth login
"@
    }
}

function Test-GitHubAuth {
    $authOutput = & gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw @"
GitHub CLI encontrado, mas sem autenticacao valida.

Execute:
- gh auth login

Detalhe:
$authOutput
"@
    }
}

function Get-DefaultRepo {
    $remote = git remote get-url origin 2>$null
    if (-not $remote) {
        throw "Nao foi possivel identificar o repositorio. Informe -Repo no formato owner/repo."
    }

    if ($remote -match 'github\.com[:/](.+?)(?:\.git)?$') {
        return $matches[1]
    }

    throw "Remote origin nao parece ser um repositorio GitHub: $remote"
}

if (-not $Repo) {
    $Repo = Get-DefaultRepo
}

Test-GitHubCliInstalled
Test-GitHubAuth

if (-not (Test-Path $CardsFile)) {
    throw "Arquivo de cards nao encontrado: $CardsFile"
}

$cards = Get-Content $CardsFile | ConvertFrom-Json
$createdIssues = @()

foreach ($card in $cards) {
    Write-Host "Criando issue: $($card.title)"

    $args = @(
        "issue", "create",
        "--repo", $Repo,
        "--title", $card.title,
        "--body", $card.body
    )

    foreach ($label in $card.labels) {
        $args += @("--label", $label)
    }

    $issueUrl = & gh @args

    if (-not $issueUrl) {
        throw "Falha ao criar a issue '$($card.title)'."
    }

    $issueUrl = $issueUrl.Trim()
    $createdIssues += $issueUrl
    Write-Host "Issue criada: $issueUrl"

    if ($ProjectOwner -and $ProjectNumber -gt 0) {
        Write-Host "Adicionando issue ao GitHub Project $ProjectOwner/$ProjectNumber"
        & gh project item-add $ProjectNumber --owner $ProjectOwner --url $issueUrl | Out-Null
    }
}

Write-Host ""
Write-Host "Resumo:"
$createdIssues | ForEach-Object { Write-Host $_ }
