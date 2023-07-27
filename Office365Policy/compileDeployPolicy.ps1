param (
    [string]$resourceGroupName = $(throw "-resourceGroupName is required.")
)
Remove-Item -LiteralPath .\EnforceOffice365 -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -LiteralPath .\policies -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -LiteralPath .\EnforceOffice365.zip -Force -ErrorAction SilentlyContinue

"Compile"
(.\Configuration.ps1).Name

"Rename .mof file"
$newItem = Rename-Item -Path .\EnforceOffice365\localhost.mof -NewName EnforceOffice365.mof -PassThru
$newItem.Name

"Create package"
$version = '1.0.1'
$newPackage = New-GuestConfigurationPackage -Name 'EnforceOffice365' `
    -Configuration $newItem.VersionInfo.FileName `
    -Type 'AuditAndSet' `
    -Version $version `
    -Force -ErrorAction SilentlyContinue

$packageFile = Split-Path $newPackage.path -leaf
$packageFile

$storageAccountName = (Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts' -ResourceGroupName $resourceGroupName).Name

$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value
$context = New-AzStoragecontext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$upload = (Set-AzStorageBlobContent -Container "scripts" -File $newPackage.path -Blob $packageFile -InformationAction SilentlyContinue -context $context -Force)

"Uploaded package to $($upload.ICloudBlob.Uri.AbsoluteUri)"

"New GuestConfiguration policy"
$policyId = New-Guid
$policyDisplayName = 'Office 365 should be installed'
$newPolicy = New-GuestConfigurationPolicy `
	-ContentUri $upload.ICloudBlob.Uri.AbsoluteUri `
	-DisplayName $policyDisplayName `
	-Description $policyDisplayName `
	-PolicyId $policyId `
	-PolicyVersion $version `
	-Path .\policies `
	-Mode 'ApplyAndAutoCorrect'

"New GuestConfiguration policy name: $($newPolicy.Name)"

$ResourceGroup = Get-AzResourceGroup -Name $resourceGroupName

$Policy = Get-AzPolicyDefinition -Name $newPolicy.Name -ErrorAction SilentlyContinue

if ($Policy.Name){    
    "Existing Policy Definition with name $($Policy.Name) found."
    "Removing old assigment"
    Remove-AzPolicyAssignment -Name $Policy.Name -Scope $ResourceGroup.ResourceId -ErrorAction SilentlyContinue | Out-Null

    "Removing old policy"
    Remove-AzPolicyDefinition -Id $Policy.ResourceId -Force -ErrorAction SilentlyContinue | Out-Null
}

"New policy definition"
$newPolicyDefinition = New-AzPolicyDefinition -Name $newPolicy.Name `
	-Policy $newPolicy.path `
	-DisplayName $policyDisplayName `
	-Description $policyDisplayName

"New policy definition name: $($newPolicyDefinition.Name)"

"New policy assignment"
$NonComplianceMessage = @(@{Message="$($newPolicyDefinition.Properties.DisplayName) is non-compliant."})
New-AzPolicyAssignment -Name $newPolicyDefinition.Properties.DisplayName `
    -PolicyDefinition $newPolicyDefinition `
    -Scope $ResourceGroup.ResourceId `
    -NonComplianceMessage $NonComplianceMessage `
    -AssignIdentity -Location $ResourceGroup.Location | Select-Object Name, ResourceGroupName | Format-Table