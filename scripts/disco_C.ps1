# Define o caminho do arquivo de log.
$DiretorioLog = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
if (-not (Test-Path -LiteralPath $DiretorioLog -PathType Container)) {
    New-Item -Path $DiretorioLog -ItemType Directory -Force -ErrorAction Stop |
        Out-Null
}

$ArquivoLog = Join-Path -Path $DiretorioLog -ChildPath 'log_disco.txt'

# Registra a data e a hora da execução.
$DataHora = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

# Cria o cabeçalho do log, substituindo o arquivo anterior.
@(
    '========================================'
    "Diagnostico de Disco - $DataHora"
    '========================================'
    ''
) | Set-Content -LiteralPath $ArquivoLog -Encoding utf8

$Unidade = 'C:'

# Consulta as informações do disco no Windows.
$Disco = Get-CimInstance -ClassName Win32_LogicalDisk `
    -Filter "DeviceID='$Unidade'"

# Verifica se a unidade foi encontrada.
if ($null -eq $Disco) {
    Write-Error "A unidade $Unidade não foi encontrada."
    return
}

# Calcula os valores em gigabytes (GB).
$Total = [math]::Round($Disco.Size / 1GB, 2)
$Livre = [math]::Round($Disco.FreeSpace / 1GB, 2)
$Usado = [math]::Round(($Disco.Size - $Disco.FreeSpace) / 1GB, 2)

# Calcula o percentual de espaço ocupado.
$PercentualUsado = [math]::Round(
    (($Disco.Size - $Disco.FreeSpace) / $Disco.Size) * 100, 2
)


# Organiza os dados em um objeto.
$Resultado = [PSCustomObject]@{
    Unidade      = $Unidade
    'Total (GB)' = $Total
    'Usado (GB)' = $Usado
    'Livre (GB)' = $Livre
    'Uso (%)'    = $PercentualUsado
}

# Converte o objeto em texto tabular.
$Tabela = $Resultado |
    Format-List |
    Out-String

# Exibe o resultado no terminal e salva no log.
$Tabela | Tee-Object -FilePath $ArquivoLog -Append
