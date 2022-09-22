## Download the msi file
Invoke-WebRequest 'https://aka.ms/WACDownload' -OutFile "C:\Windows\Temp\WAC.msi"

## install windows admin center
$msiArgs = @("/i", "$pwd\WAC.msi", "/qn", "/L*v", "log.txt", "SME_PORT=443", "SSL_CERTIFICATE_OPTION=generate")
Start-Process msiexec.exe -Wait -ArgumentList $msiArgs

## Add Firewall Rules
New-NetFirewallRule -DisplayName "Allow Windows Admin Center" -Direction Inbound -profile Public -LocalPort 443 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Allow Windows Admin Center" -Direction Inbound -profile Private -LocalPort 443 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Allow Windows Admin Center" -Direction Inbound -profile Domain -LocalPort 443 -Protocol TCP -Action Allow
