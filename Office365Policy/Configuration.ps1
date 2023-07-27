Configuration EnforceOffice365 {

    $ErrorActionPreference = 'Stop'

    $logPath = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\ScriptLog.log"
    $workingDirectory = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))"
    
    Import-DscResource -Name 'Script' -ModuleName 'PSDscResources'

    Script ExecuteInstallOffice365{
        GetScript = { return @{'Result' = ''} }
        SetScript = { Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Executing SetScript..." }
        TestScript = {
            try {
                $wordRegKey = 'HKLM:\SOFTWARE\Microsoft\Office\16.0\Word\InstallRoot'
                if (Test-Path -Path $wordRegKey) {
                    $pathValue = Get-ItemPropertyValue $wordRegKey -Name Path
                    $winwordPath = Join-Path -Path $pathValue -ChildPath "WINWORD.EXE"
                    if (Test-Path -Path $winwordPath ){

                        $officeVersion = (Get-Item $winwordPath).VersionInfo.ProductVersion
                        Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Found Office 365 version $officeVersion already installed."
                    
                        return $true
                    } 
                } 
                
                Set-Location $using:workingDirectory

                New-Item -Name "o365ODT" -ItemType Directory -Force | Select-Object -ExpandProperty FullName | Set-Location

                $configfile = New-Item -Path . -Name "configuration.xml" -ItemType "file" -Force
                Add-Content -Path $configfile -Value '<Configuration>'
                Add-Content -Path $configfile -Value ' <Add OfficeClientEdition="64" Channel="Current">'
                Add-Content -Path $configfile -Value '  <Product ID="O365ProPlusRetail">'
                Add-Content -Path $configfile -Value '   <Language ID="en-US" />'
                Add-Content -Path $configfile -Value '   <ExcludeApp ID="Groove" />'
                Add-Content -Path $configfile -Value '   <ExcludeApp ID="Lync" />'
                Add-Content -Path $configfile -Value '   <ExcludeApp ID="OneDrive" />'
                Add-Content -Path $configfile -Value '   <ExcludeApp ID="OneNote" />'
                Add-Content -Path $configfile -Value '   <ExcludeApp ID="Teams" />'
                Add-Content -Path $configfile -Value '  </Product>'
                Add-Content -Path $configfile -Value ' </Add>'
                Add-Content -Path $configfile -Value ' <RemoveMSI/>'
                Add-Content -Path $configfile -Value ' <Updates Enabled="FALSE"/>'
                Add-Content -Path $configfile -Value ' <Display Level="None" AcceptEULA="TRUE" />'
                Add-Content -Path $configfile -Value ' <Property Name="FORCEAPPSHUTDOWN" Value="TRUE"/>'
                Add-Content -Path $configfile -Value ' <Property Name="SharedComputerLicensing" Value="1"/>'
                Add-Content -Path $configfile -Value '</Configuration>'

                Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Wrote Office 365 configuration file." 
                

                $response = Invoke-WebRequest -UseBasicParsing "https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117"
                    
                $ODTUri = $response.links | Where-Object {$_.outerHTML -like "*click here to download manually*"}

                Invoke-WebRequest $ODTUri.href -OutFile ".\officedeploymenttool.exe"
                Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Downloaded Office 385 Deployment tool."

                Start-Process -FilePath .\officedeploymenttool.exe -ArgumentList "/quiet /extract:.\" -Wait
                Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Extracted Office 385 Deployment tool."

                Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Installing Office 365..."
                Start-Process -FilePath .\setup.exe -ArgumentList "/configure $configfile" -Wait
                Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Installed Office 365."
            }
            catch {
                $msg= "[ERROR] in TestScript: " + $PSItem | Format-List -Force | Out-String
                Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - $msg"
                return $false
            }

            if (Test-Path -Path $wordRegKey) {
                $pathValue = Get-ItemPropertyValue $wordRegKey -Name Path
                $winwordPath = Join-Path -Path $pathValue -ChildPath "WINWORD.EXE"
                if (Test-Path -Path $winwordPath ){

                    $officeVersion = (Get-Item $winwordPath).VersionInfo.ProductVersion
                    Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Version: $officeVersion"

                    return $true

                } else { 
                    Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Executable $winwordPath not found."
                    return $false 
                }
            } else { 
                Add-Content -Path $using:logPath -Value "$(Get-Date -Format "MM-dd-yy HH:mm") - Registry key $wordRegKey not found."
                return $false
            }
        }
    }
}
EnforceOffice365
