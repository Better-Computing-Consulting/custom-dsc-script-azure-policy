$currentPolicyState = Get-AzPolicyState -PolicyDefinitionName EnforceOffice365
$currentPolicyState | Select-Object Timestamp, ResourceGroup, PolicyDefinitionName, IsCompliant, ComplianceState | Format-Table 
while (!($currentPolicyState.IsCompliant)){
	Start-Sleep -Seconds 60
	$oldPolicyState = $currentPolicyState
	$currentPolicyState = Get-AzPolicyState -PolicyDefinitionName EnforceOffice365
	if ($oldPolicyState.Timestamp -ne $currentPolicyState.Timestamp){
		$currentPolicyState | Select-Object Timestamp, ResourceGroup, PolicyDefinitionName, IsCompliant, ComplianceState | Format-Table
	}
}
