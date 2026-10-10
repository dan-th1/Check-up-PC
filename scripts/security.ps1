# Define o caminho do arquivo de log.
$DiretorioLog = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
if (-not (Test-Path -LiteralPath $DiretorioLog -PathType Container)) {
    New-Item -Path $DiretorioLog -ItemType Directory -Force -ErrorAction Stop |
        Out-Null
}

$ArquivoLog = Join-Path -Path $DiretorioLog -ChildPath 'security.txt'

# Registra a data e a hora da execucao.
$DataHora = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

# Cria o cabecalho, sobrescrevendo o log anterior.
@(
    '========================================'
    "Diagnostico de seguranca - $DataHora"
    '========================================'
    ''
) | Set-Content -LiteralPath $ArquivoLog -Encoding utf8

# Consulta o estado do Microsoft Defender.
try {
    $Defender = Get-MpComputerStatus -ErrorAction Stop

    $ResultadoDefender = [PSCustomObject]@{
        'Antivirus habilitado' = $Defender.AntivirusEnabled
        'Protecao em tempo real' = $Defender.RealTimeProtectionEnabled
        'Antivirus atualizado' = $Defender.AntivirusSignatureLastUpdated
        'Ultima verificacao rapida' = $Defender.QuickScanEndTime
        'Ultima verificacao completa' = $Defender.FullScanEndTime
    }

    $TextoDefender = $ResultadoDefender |
        Format-List |
        Out-String

    @(
        '========================================'
        'MICROSOFT DEFENDER'
        '========================================'
        ''
    ) | Tee-Object -FilePath $ArquivoLog -Append

    $TextoDefender |
        Tee-Object -FilePath $ArquivoLog -Append
}
catch {
    $Mensagem = "Nao foi possivel consultar o Microsoft Defender: $($_.Exception.Message)"

    Write-Warning $Mensagem
    $Mensagem | Tee-Object -FilePath $ArquivoLog -Append
}

try {
    # Consulta os perfis de rede do Firewall.
    $PerfisFirewall = Get-NetFirewallProfile -ErrorAction Stop

    # Organiza o estado de cada perfil.
    $ResultadoFirewall = foreach ($Perfil in $PerfisFirewall) {
        [PSCustomObject]@{
            Perfil    = $Perfil.Name
            Habilitado = $Perfil.Enabled
        }
    }

    @(
        ''
        '========================================'
        'FIREWALL DO WINDOWS'
        '========================================'
        ''
    ) | Tee-Object -FilePath $ArquivoLog -Append

    $TabelaFirewall = $ResultadoFirewall |
        Format-Table -AutoSize |
        Out-String -Width 200

    $TabelaFirewall |
        Tee-Object -FilePath $ArquivoLog -Append
}
catch {
    $Mensagem = "Nao foi possivel consultar o Firewall do Windows: $($_.Exception.Message)"

    Write-Warning $Mensagem
    $Mensagem | Tee-Object -FilePath $ArquivoLog -Append
}

try {
    # Consulta os antivirus registrados no Centro de Seguranca.
    $Antivirus = Get-CimInstance `
        -Namespace 'root/SecurityCenter2' `
        -ClassName AntivirusProduct `
        -ErrorAction Stop

    # Remove registros duplicados pelo nome e caminho do produto.
    $AntivirusUnicos = $Antivirus |
        Sort-Object -Property displayName, pathToSignedProductExe -Unique

    @(
        ''
        '========================================'
        'ANTIVIRUS REGISTRADOS NO WINDOWS'
        '========================================'
        ''
    ) | Tee-Object -FilePath $ArquivoLog -Append

    if ($AntivirusUnicos) {
        $ResultadoAntivirus = foreach ($Produto in $AntivirusUnicos) {
            [PSCustomObject]@{
                Nome = $Produto.displayName
                Caminho = $Produto.pathToSignedProductExe
                EstadoBruto = ('0x{0:X6}' -f $Produto.productState)
            }
        }

        $TabelaAntivirus = $ResultadoAntivirus |
            Format-Table -AutoSize |
            Out-String -Width 200

        $TabelaAntivirus |
            Tee-Object -FilePath $ArquivoLog -Append
    }
    else {
        'Nenhum antivirus foi retornado pela consulta.' |
            Tee-Object -FilePath $ArquivoLog -Append
    }
}
catch {
    $Mensagem = "Nao foi possivel consultar os antivirus registrados: $($_.Exception.Message)"

    Write-Warning $Mensagem
    $Mensagem | Tee-Object -FilePath $ArquivoLog -Append
}

Write-Host "`nDiagnostico de seguranca concluido."
Write-Host "Log salvo em: $ArquivoLog"