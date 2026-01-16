$phoneOctet = # Enter the octet used for phones in your DHCP scopes, e.g., "20" for
$dhcpServer = "dhcpServer"
$phoneScopes = Get-DhcpServerv4Scope  -ComputerName $dhcpServer | Where-Object scopeid -like *.*.$phoneOctet.*

$allResults = $phoneScopes | ForEach-Object -Parallel{
    $data = New-Object System.Collections.Generic.List[object]
    $phoneScope = $_
    $leases = Get-DhcpServerv4Lease -ComputerName $dhcpServer -ScopeId $phoneScope.ScopeId -AllLeases
    Write-Host "Scope id:$($phoneScope.ScopeId)"
    $results = $leases | ForEach-Object -Parallel{
        $lease= $_
        

        $ip = $lease.IPAddress
        try{
            $contenu = (Invoke-WebRequest -Uri "http://${ip}" -UseBasicParsing).content
            $found = $false
            $model = $null
            $version = $null
            $found = $contenu  -match "<TD><B>V\d+</B></TD>"
            if($found){
                $temp = $matches[0] -match "\d+"
                $version = $Matches[0]
                $found = $true
          
                $found_phone_model = $contenu -match "Cisco IP Phone \d+"
                if($found_phone_model){
                    $temp = $matches[0] -match "\d+"
                    $model = $Matches[0]
                }
                [PSCustomObject]@{
                    ScopeId = $using:phoneScope.ScopeId
                    Ip      = $ip
                    Model   = $model
                    Version = $version
                }
            }

        }
        catch {}
    } -ThrottleLimit 20
    $results = $results | Where-Object { $_ -ne $null }
    $results
  
} -ThrottleLimit 5
Write-Host $allResults
$allResults | Where-Object { $_ -ne $null } | Export-Csv -Path ".\all_phones.csv" -NoTypeInformation