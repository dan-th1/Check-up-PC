# Define o caminho do arquivo de log.
$DiretorioLog = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
if (-not (Test-Path -LiteralPath $DiretorioLog -PathType Container)) {
    New-Item -Path $DiretorioLog -ItemType Directory -Force -ErrorAction Stop |
        Out-Null
}

$ArquivoLog = Join-Path -Path $DiretorioLog -ChildPath 'log_pastas.txt'

# Registra a data e a hora da execução.
$DataHora = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

# Cria o cabeçalho do log, substituindo o arquivo anterior.
@(
    '========================================'
    "Diagnostico de pastas - $DataHora"
    '========================================'
    ''
) | Set-Content -LiteralPath $ArquivoLog -Encoding utf8

$Unidade = 'C:\'

# Obtém as pastas diretamente na raiz do disco.
$Pastas = Get-ChildItem -LiteralPath $Unidade -Directory -Force `
    -ErrorAction SilentlyContinue

# Calcula o tamanho de cada pasta.
$Resultado = foreach ($Pasta in $Pastas) {

    # Soma o tamanho dos arquivos encontrados recursivamente. Pode levar varios minutos!!!
    $Arquivos = Get-ChildItem -LiteralPath $Pasta.FullName `
        -File -Recurse -Force -ErrorAction SilentlyContinue

    $Bytes = ($Arquivos | Measure-Object -Property Length -Sum).Sum

    # Evita deixar o resultado vazio quando não há arquivos acessíveis.
    if ($null -eq $Bytes) {
        $Bytes = 0
    }

    # Produz um objeto com nome e tamanho aproximado.
    [PSCustomObject]@{
        Pasta    = $Pasta.FullName
        'GB'     = [math]::Round($Bytes / 1GB, 2)
    }
}

# Ordena as pastas da maior para a menor.
$Tabela = $Resultado |
    Sort-Object -Property GB -Descending |
    Format-Table -AutoSize |
    Out-String -Width 200

# Exibe o resultado no terminal e o acrescenta ao arquivo de log.
$Tabela | Tee-Object -FilePath $ArquivoLog -Append
