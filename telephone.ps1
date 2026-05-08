$phoneOctet = $env:phoneOctet
$dhcpServer = $env:dhcpServer

$phoneScopes = Get-DhcpServerv4Scope -ComputerName $dhcpServer |
    Where-Object ScopeId -like "*.*.$phoneOctet.*"

$allResults = $phoneScopes | ForEach-Object -Parallel {

    $phoneScope = $_

    Write-Host "Scope id:$($phoneScope.ScopeId)"

    $leases = Get-DhcpServerv4Lease -ComputerName $using:dhcpServer -ScopeId $phoneScope.ScopeId -AllLeases

    $leases | ForEach-Object -Parallel {

        $lease = $_
        $ip = $lease.IPAddress

        try {
            $contenu = (Invoke-WebRequest -Uri "http://${ip}" -UseBasicParsing).Content

            # --- Version ---
            $version = $null
            if ($contenu -match "<TD><B>V(\d+)</B></TD>") {
                $version = $Matches[1]
            }

            # --- Modele ---
            $model = $null
            if ($contenu -match "Cisco IP Phone (\d+)") {
                $model = $Matches[1]
            }

            # --- DN ---
            $dn = $null
            if ($contenu -match "Numéro de téléphone.*?<B>\s*(\d+)\s*</B>") {
                $dn = $Matches[1]
            }

            # --- MAC ---
            $mac = $null
            if ($contenu -match "Adresse MAC.*?<B>\s*([0-9A-F]{12})\s*</B>") {
                $mac = $Matches[1]
            }

            # On retourne seulement si on a détecté quelque chose
            if ($model -or $dn -or $mac) {
                [PSCustomObject]@{
                    ScopeId = $using:phoneScope.ScopeId
                    Ip      = $ip
                    Model   = $model
                    Version = $version
                    DN      = $dn
                    MAC     = $mac
                }
            }

        } catch {
            # silence
        }

    } -ThrottleLimit 20

} -ThrottleLimit 5

# Nettoyage des null
$allResults = $allResults | Where-Object { $_ -ne $null }

# Export
$allResults | Export-Csv -Path ".\all_phones.csv" -NoTypeInformation

# Affichage
$allResults
