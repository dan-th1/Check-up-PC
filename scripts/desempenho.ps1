# Define o caminho do arquivo de log.
$DiretorioLog = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
if (-not (Test-Path -LiteralPath $DiretorioLog -PathType Container)) {
    New-Item -Path $DiretorioLog -ItemType Directory -Force -ErrorAction Stop |
        Out-Null
}

$ArquivoLog = Join-Path -Path $DiretorioLog -ChildPath 'log_desempenho.txt'

# Registra a data e a hora da execucao.
$DataHora = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

# Cria o cabecalho, sobrescrevendo o log anterior.
@(
    '========================================'
    "Diagnostico de desempenho - $DataHora"
    '========================================'
    ''
) | Set-Content -LiteralPath $ArquivoLog -Encoding utf8

# Consulta informacoes do processador.
$CPU = Get-CimInstance -ClassName Win32_Processor

# Consulta informacoes da memoria fisica.
$RAM = Get-CimInstance -ClassName Win32_OperatingSystem

# Calcula a memoria total, livre e usada em GB.
$RAMTotal = [math]::Round($RAM.TotalVisibleMemorySize / 1MB, 2)
$RAMLivre = [math]::Round($RAM.FreePhysicalMemory / 1MB, 2)
$RAMUsada = [math]::Round($RAMTotal - $RAMLivre, 2)

# Calcula o percentual de RAM utilizada.
$PercentualRAM = [math]::Round(
    ($RAMUsada / $RAMTotal) * 100, 2
)

# Consulta o percentual de utilizacao atual da CPU.
$UsoCPU = Get-CimInstance -ClassName Win32_Processor |
    Measure-Object -Property LoadPercentage -Average

$PercentualCPU = [math]::Round($UsoCPU.Average, 2)

# Organiza os dados em um objeto.
$Resultado = [PSCustomObject]@{
    Processador              = $CPU[0].Name.Trim()
    Nucleos                  = $CPU[0].NumberOfCores
    'Processadores logicos'  = $CPU[0].NumberOfLogicalProcessors
    'CPU em uso (%)'         = $PercentualCPU
    'RAM total (GB)'         = $RAMTotal
    'RAM usada (GB)'         = $RAMUsada
    'RAM livre (GB)'         = $RAMLivre
    'RAM em uso (%)'         = $PercentualRAM
}

# Converte o objeto em texto.
$Texto = $Resultado | Format-List | Out-String

# Exibe os dados e acrescenta ao log.
$Texto | Tee-Object -FilePath $ArquivoLog -Append

# Consulta os processos e ordena pelo uso de memoria fisica.
$Processos = Get-Process |
    Sort-Object -Property WorkingSet64 -Descending |
    Select-Object -First 10

# Organiza os dados de cada processo.
$ResultadoProcessos = foreach ($Processo in $Processos) {
    [PSCustomObject]@{
        Processo   = $Processo.ProcessName
        PID        = $Processo.Id
        'RAM (MB)' = [math]::Round($Processo.WorkingSet64 / 1MB, 2)
    }
}

# Registra o titulo da secao.
@(
    ''
    '========================================'
    '10 processos com maior uso de RAM'
    '========================================'
    ''
) | Tee-Object -FilePath $ArquivoLog -Append

# Converte a tabela em texto.
$TabelaProcessos = $ResultadoProcessos |
    Format-Table -AutoSize |
    Out-String -Width 200

# Exibe e registra a tabela.
$TabelaProcessos | Tee-Object -FilePath $ArquivoLog -Append

# Define o intervalo entre as amostras.
$Intervalo = 1
$Duracao = 10

# Armazena as amostras de utilizacao da CPU.
$AmostrasCPU = @()

# Informa o inicio da coleta.
Write-Host "Coletando utilizacao da CPU por $Duracao segundos..."

# Consulta a CPU repetidamente durante o periodo definido.
for ($i = 0; $i -lt $Duracao; $i++) {

    $Leitura = Get-CimInstance -ClassName Win32_Processor |
        Measure-Object -Property LoadPercentage -Average

    if ($null -ne $Leitura.Average) {
        $AmostrasCPU += [double]$Leitura.Average
    }

    # Aguarda antes da proxima leitura, exceto na ultima.
    if ($i -lt ($Duracao - 1)) {
        Start-Sleep -Seconds $Intervalo
    }
}

# Verifica se alguma amostra foi obtida.
if ($AmostrasCPU.Count -gt 0) {

    # Calcula as estatisticas da coleta.
    $CPUMinima = [math]::Round(
        ($AmostrasCPU | Measure-Object -Minimum).Minimum, 2
    )

    $CPUMaxima = [math]::Round(
        ($AmostrasCPU | Measure-Object -Maximum).Maximum, 2
    )

    $CPUMedia = [math]::Round(
        ($AmostrasCPU | Measure-Object -Average).Average, 2
    )

    # Organiza o resultado da amostragem.
    $ResultadoCPU = [PSCustomObject]@{
        'Duracao (segundos)' = $Duracao
        'Quantidade de amostras' = $AmostrasCPU.Count
        'CPU minima (%)' = $CPUMinima
        'CPU maxima (%)' = $CPUMaxima
        'CPU media (%)' = $CPUMedia
    }

    # Converte o resultado em texto.
    $TextoCPU = $ResultadoCPU | Format-List | Out-String

    # Registra o titulo e as estatisticas da coleta.
    @(
        ''
        '========================================'
        'Amostragem da CPU - 10 segundos'
        '========================================'
        ''
    ) | Tee-Object -FilePath $ArquivoLog -Append

    $TextoCPU | Tee-Object -FilePath $ArquivoLog -Append

}
else {
    Write-Warning 'Nao foi possivel obter amostras de utilizacao da CPU.'

    'Nao foi possivel obter amostras de utilizacao da CPU.' |
        Tee-Object -FilePath $ArquivoLog -Append
}

Write-Host "`nDiagnostico concluido."
Write-Host "Log salvo em: $ArquivoLog"
