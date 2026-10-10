$Unidade = 'C:\Program Files'

$DiretorioLog = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
if (-not (Test-Path -LiteralPath $DiretorioLog -PathType Container)) {
    New-Item -Path $DiretorioLog -ItemType Directory -Force -ErrorAction Stop |
        Out-Null
}

$ArquivoLog = Join-Path -Path $DiretorioLog -ChildPath 'log_subpastas.txt'

$DataHora = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

# Obtém as subpastas diretamente do diretório analisado.
$Pastas = Get-ChildItem -LiteralPath $Unidade `
    -Directory -Force -ErrorAction SilentlyContinue |
    Sort-Object -Property Name

# Cria o cabeçalho, sobrescrevendo o log da execução anterior.
@(
    '========================================'
    "Diagnostico de subpastas - $DataHora"
    "Pasta analisada: $Unidade"
    '========================================'
    ''
) | Set-Content -LiteralPath $ArquivoLog -Encoding utf8

# Converte a listagem em texto para exibição e registro.
$Tabela = $Pastas |
    Select-Object Name |
    Format-Table -AutoSize |
    Out-String -Width 200

# Exibe a listagem e acrescenta seu conteúdo ao log.
$Tabela | Tee-Object -FilePath $ArquivoLog -Append

while ($true) {

    # Solicita o nome da subpasta que será analisada.
    $Nome = Read-Host "`nDigite a subpasta que deseja medir ou 'q' para encerrar"

    # Encerra o loop somente quando o usuário solicitar.
    if ($Nome.Trim() -ieq 'q') {
        break
    }

    # Aceita somente subpastas listadas diretamente em $Unidade.
    $PastaSelecionada = $Pastas |
        Where-Object { $_.Name -eq $Nome.Trim() } |
        Select-Object -First 1

    if ($null -eq $PastaSelecionada) {
        Write-Host "Subpasta nao encontrada: $Nome" -ForegroundColor Yellow
        continue
    }

    $Caminho = $PastaSelecionada.FullName

    # Percorre os arquivos e soma seus tamanhos.
    Write-Host "`nCalculando o tamanho de '$Nome'..." 

    $Bytes = (Get-ChildItem -LiteralPath $Caminho `
        -File -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum

    # Trata o caso em que nenhum tamanho foi contabilizado.
    if ($null -eq $Bytes) {
        $Bytes = 0
    }

    # Organiza o resultado da medição.
    $Resultado = [PSCustomObject]@{
        DataHora = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
        Pasta    = $Caminho
        'GB'     = [math]::Round($Bytes / 1GB, 2)
    }

    # Cria uma seção no log para esta medição.
    @(
        ''
        '----------------------------------------'
        'Resultado da medicao'
        '----------------------------------------'
    ) | Add-Content -LiteralPath $ArquivoLog -Encoding utf8

    # Exibe o resultado e acrescenta os dados ao log.
    $Texto = $Resultado | Format-List | Out-String

    $Texto | Tee-Object -FilePath $ArquivoLog -Append
}

# Mensagem exibida quando o usuário digita 'sair'.
Write-Host "`nDiagnostico encerrado. Log salvo em: $ArquivoLog"
