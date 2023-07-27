$context = Get-AzContext
if (!($context.Account.Type -eq 'User')){
    throw "Current user account type must be User. Re-run Connect-AzAccount."
} 
$resourceGroupName = 'azPolicyDev-RG'

Write-Host $resourceGroupName -ForegroundColor DarkYellow

Set-Location .\DevInfrastructure
#
# Deploy development infrastructure
#
"Deploying resources..."
. .\deployInfrastructure.ps1 $resourceGroupName

"Resources deployed."
Get-AzResource -ResourceGroupName $resourceGroupName | Select-Object Name, ResourceType | Format-Table 

Set-Location ..\Office365Policy
#
# Deploy Azure Policy
#
"Deploying Custom DSC Script policy..."
. .\compileDeployPolicy.ps1 $resourceGroupName

Set-Location ..