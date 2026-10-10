
# ============================================================
# CONFIGURACAO DO LOG
# ============================================================

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$DiretorioLog = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
if (-not (Test-Path -LiteralPath $DiretorioLog -PathType Container)) {
    New-Item -Path $DiretorioLog -ItemType Directory -Force -ErrorAction Stop |
        Out-Null
}

$ArquivoLog = Join-Path -Path $DiretorioLog -ChildPath 'limpeza.txt'
$DataHora = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

@(
    '========================================'
    "Diagnostico de limpeza - $DataHora"
    '========================================'
    ''
) | Set-Content -LiteralPath $ArquivoLog -Encoding utf8


# ============================================================
# ETAPA 1 - DEFINICAO DAS PASTAS
# ============================================================

$PastasTemporarias = @(
    [PSCustomObject]@{
        Nome = 'Temporarios do usuario'
        Caminho = $env:TEMP
    }
    [PSCustomObject]@{
        Nome = 'Temporarios do Windows'
        Caminho = "$env:WINDIR\Temp"
    }
)

# Define a idade minima dos arquivos candidatos.
$DiasMinimos = 7
$DataLimite = (Get-Date).AddDays(-$DiasMinimos)


# ============================================================
# ETAPA 2 - DIAGNOSTICO
# ============================================================

$Resultados = foreach ($Pasta in $PastasTemporarias) {

    Write-Host "Analisando: $($Pasta.Caminho)"

    if (-not (Test-Path -LiteralPath $Pasta.Caminho -PathType Container)) {
        [PSCustomObject]@{
            Categoria = $Pasta.Nome
            Caminho = $Pasta.Caminho
            Arquivos = 0
            'Tamanho (MB)' = 0
            Situacao = 'Pasta nao encontrada'
        }
        continue
    }

    $Arquivos = @(
        Get-ChildItem -LiteralPath $Pasta.Caminho `
            -File -Recurse -Force -ErrorAction SilentlyContinue
    )

    $TotalBytes = ($Arquivos |
        Measure-Object -Property Length -Sum).Sum

    if ($null -eq $TotalBytes) {
        $TotalBytes = 0
    }

    [PSCustomObject]@{
        Categoria = $Pasta.Nome
        Caminho = $Pasta.Caminho
        Arquivos = $Arquivos.Count
        'Tamanho (MB)' = [math]::Round($TotalBytes / 1MB, 2)
        Situacao = 'Analisada'
    }
}

@(
    ''
    '========================================'
    'DIAGNOSTICO DE ARQUIVOS TEMPORARIOS'
    '========================================'
    ''
) | Tee-Object -FilePath $ArquivoLog -Append

$Tabela = $Resultados |
    Format-Table -AutoSize |
    Out-String -Width 200

$Tabela | Tee-Object -FilePath $ArquivoLog -Append


# ============================================================
# ETAPA 3 - RESUMO
# ============================================================

$TotalMB = (
    $Resultados |
        Measure-Object -Property 'Tamanho (MB)' -Sum
).Sum

if ($null -eq $TotalMB) {
    $TotalMB = 0
}

$Resumo = [PSCustomObject]@{
    'Pastas analisadas' = @(
        $Resultados | Where-Object Situacao -eq 'Analisada'
    ).Count
    'Arquivos encontrados' = (
        $Resultados |
            Measure-Object -Property Arquivos -Sum
    ).Sum
    'Espaco ocupado (MB)' = [math]::Round($TotalMB, 2)
    'Espaco ocupado (GB)' = [math]::Round($TotalMB / 1024, 3)
}

$Resumo | Format-List | Out-String |
    Tee-Object -FilePath $ArquivoLog -Append


# ============================================================
# ETAPA 4 - CONFIRMACAO DE EXCLUSAO
# ============================================================

Write-Host ''
Write-Host "Previa: os arquivos listados abaixo tem mais de $DiasMinimos dias."
Write-Host 'A idade nao garante que um arquivo seja dispensavel.'
Write-Host ''

$Candidatos = @(
    foreach ($Pasta in $PastasTemporarias) {
        if (Test-Path -LiteralPath $Pasta.Caminho -PathType Container) {
            Get-ChildItem -LiteralPath $Pasta.Caminho `
                -File -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $DataLimite }
        }
    }
)

if ($Candidatos.Count -eq 0) {
    @(
        ''
        'Nenhum arquivo elegivel foi encontrado.'
    ) | Tee-Object -FilePath $ArquivoLog -Append

    Write-Host "Log salvo em: $ArquivoLog"
    return
}

Write-Host "Arquivos elegiveis para exclusao: $($Candidatos.Count)"
$Candidatos | ForEach-Object { Write-Host " - $($_.FullName)" }

if ($WhatIfPreference) {
    @(
        ''
        '========================================'
        'SIMULACAO (-WhatIf)'
        'Nenhum arquivo foi excluido pelo script.'
        '========================================'
    ) | Tee-Object -FilePath $ArquivoLog -Append

    Write-Host "`nPrevia concluida. Nenhum arquivo foi excluido."
    Write-Host "Log salvo em: $ArquivoLog"
    return
}
else {
    $Confirmacao = Read-Host "Digite EXCLUIR para continuar; qualquer outra entrada cancela"

    if ($Confirmacao -cne 'EXCLUIR') {
        @(
            ''
            '========================================'
            'EXCLUSAO CANCELADA PELO USUARIO'
            'Nenhum arquivo foi excluido pelo script.'
            '========================================'
        ) | Tee-Object -FilePath $ArquivoLog -Append

        Write-Host "`nOperacao cancelada. Nenhum arquivo foi excluido pelo script."
        Write-Host "Log salvo em: $ArquivoLog"
        return
    }
}


# ============================================================
# ETAPA 5 - EXCLUSAO DOS ARQUIVOS ELEGIVEIS
# ============================================================

$TotalExcluidos = 0
$TotalFalhas = 0
$BytesExcluidos = 0

foreach ($Arquivo in $Candidatos) {
    try {
        if (Test-Path -LiteralPath $Arquivo.FullName -PathType Leaf) {
            $ArquivoAtual = Get-Item -LiteralPath $Arquivo.FullName -ErrorAction Stop

            if ($ArquivoAtual.LastWriteTime -lt $DataLimite) {
                if ($PSCmdlet.ShouldProcess(
                    $ArquivoAtual.FullName,
                    'Excluir arquivo temporario'
                )) {
                    $TamanhoArquivo = $ArquivoAtual.Length
                    Remove-Item -LiteralPath $Arquivo.FullName `
                        -Force -ErrorAction Stop

                    $TotalExcluidos++
                    $BytesExcluidos += $TamanhoArquivo

                    "EXCLUIDO: $($Arquivo.FullName)" |
                        Add-Content -LiteralPath $ArquivoLog -Encoding utf8
                }
            }
        }
    }
    catch {
        $TotalFalhas++

        "FALHA: $($Arquivo.FullName) | $($_.Exception.Message)" |
            Add-Content -LiteralPath $ArquivoLog -Encoding utf8
    }
}


# ============================================================
# ETAPA 6 - RESULTADO DA EXCLUSAO
# ============================================================

$ResultadoFinal = [PSCustomObject]@{
    'Arquivos excluidos' = $TotalExcluidos
    'Arquivos com falha' = $TotalFalhas
    'Espaco liberado (MB)' = [math]::Round($BytesExcluidos / 1MB, 2)
    'Espaco liberado (GB)' = [math]::Round($BytesExcluidos / 1GB, 3)
}

@(
    ''
    '========================================'
    'RESULTADO DA EXCLUSAO'
    '========================================'
    ''
) | Tee-Object -FilePath $ArquivoLog -Append

$ResultadoFinal | Format-List | Out-String |
    Tee-Object -FilePath $ArquivoLog -Append


# ============================================================
# ENCERRAMENTO
# ============================================================

Write-Host "`nDiagnostico de limpeza concluido."
Write-Host "Arquivos excluidos: $TotalExcluidos"
Write-Host "Arquivos com falha: $TotalFalhas"
Write-Host "Espaco liberado: $([math]::Round($BytesExcluidos / 1MB, 2)) MB"
Write-Host "Log salvo em: $ArquivoLog"
