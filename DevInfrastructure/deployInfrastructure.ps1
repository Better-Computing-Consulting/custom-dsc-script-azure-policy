param (
    [string]$resourceGroupName = $(throw "-resourceGroupName is required."),
    [string]$resourceGroupLocation = 'westus'
)
$context = Get-AzContext

$rg = New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -Force

"Monitor deployment on Azure's portal" 
$shellcmd = "start msedge --new-window --app=https://portal.azure.com/#@$($context.Account.id.Split("@")[1])/resource/subscriptions/$($context.subscription.id)/resourceGroups/$resourceGroupName/overview"
cmd.exe /c $shellcmd

$keyVaultName = (Get-AzResource -ResourceType 'Microsoft.KeyVault/vaults' -ResourceGroupName $rg.ResourceGroupName).Name 

if (!($keyVaultName)){
    $pubIp = (Invoke-WebRequest -uri "https://api.ipify.org/").Content

    "Deploying KeyVault"
    $outputs = (New-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName `
        -Name "KeyVaultdeployment-$((get-date).ToString('yyyyMMddHHmm'))"  `
        -TemplateFile '.\modules\keyvault.bicep' `
        -tenantId $context.Tenant.Id `
        -publicIP $pubIp `
        -keyVaultUser $context.Account.ExtendedProperties.HomeAccountId.Split('.')[0]).Outputs

    $pass = ([char[]]([char]33..[char]95) + ([char[]]([char]97..[char]126)) + 0..9 | Sort-Object {Get-Random})[0..12] -join ''

    $secUserName = ConvertTo-SecureString 'vmadmin' -AsPlainText -Force
    $secPassword = ConvertTo-SecureString $pass -AsPlainText -Force

    Set-AzKeyVaultSecret -VaultName $outputs.keyVaultName.value -Name 'adminUserName' -SecretValue $secUserName | Out-Null
    Set-AzKeyVaultSecret -VaultName $outputs.keyVaultName.value -Name 'adminPassword' -SecretValue $secPassword | Out-Null

    $keyVaultName = (Get-AzKeyVault -VaultName $outputs.keyVaultName.value).VaultName
}

"Deploying Infrastructure"
New-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName `
    -Name "Infradeployment-$(get-date -Format 'yyyyMMddHHmm')" `
    -TemplateFile '.\main.bicep' `
    -vmName "vm$(Get-Date -Format 'MMddHHmm')" `
    -kvName $keyVaultName | Out-Null

"List Deployments"
Get-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName | Select-Object ResourceGroupName, DeploymentName, ProvisioningState, Timestamp | Format-Table