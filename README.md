# Custom DSC Script Azure Policy

The scripts in this project will compile and deploy a custom Desired State Configuration (DSC) script as an Azure policy. The scripts also deploy a development resource group with the resources necessary to test the application of the policy. The custom DSC script deploys Office 365 in the resource group VMs. The scripts assign the policy to the development resource group, so VMs residing in the resource group will have to successfully execute the custom DSC script, and install Office 365 to comply with the policy. 

Both the development infrastructure and the policy can be deployed independently of each other. Each part of the project has its own folder and deployment script. At the root of the project there is an deployAll.ps1 script the executes both deployments.

To successfully run all the scrips in the repository you need to following modules installed on a **PowerShell 7** console:

* Az.Accounts
* Az.KeyVault
* Az.PolicyInsights
* Az.Resources
* Az.Storage
* GuestConfiguration
* PSDesiredStateConfiguration
* PSDscResources

And, in addition to the modules you will need to install the **Bicep CLI**.

## deployAll.ps1

Running the **deployAll.ps1** script will first run the **DevInfrastructure\deployInfrastructure.ps1** script.

### deployInfrastructure.ps1

The **deployInfrastructure.ps1** script will:

1. Perform a bicep deployment using the **modules\keyvault.bicep** file to create a KeyVault to store the admin username and password of the development VM.
2. Perform a second bicep deployment using the **main.bicep** file to create the remainder of the development infrastructure. The **main.bicep** file deploys these resources:
    - A role assignment that assigns the user running the script **Virtual Machine Administrator Login** role scoped to the resource group containing the development VM. So that the user running the script can use its Azure Active Directory credentials to login to the VM to test the application of the Policy.
    - Next the main.bicep file deploys a Virtual Network using the **modules\vnet.bicep** file. This is the VNet that hosts the development VM.
    - Next the main.bicep file deploys a Storage Account using the **modules\storage.bicep**. The storage account will store the GuestConfiguration package that will be deployed to target VMs by the policy. The storage account security is set so that it only allows access from the VNet that hosts the development VM or from the public IP of the computer running the scripts.
    - Lastly, the main.bicep file deploys a VM using the **modules\vm.bicep** file. The bicep file deploys the VM with the **AADLoginForWindows** extension to allow Azure AD credentials to be used to log into the computer. The file also deploys the VM with the **Azure Automanage** machine configuration extension to enable Azure Policy to perform and audit DSC configurations inside the VM. Finally, the VM’s network interface is deployed with a Network Security Group that allows remote desktop access to the VM only from the the public IP of the computer running the scripts.

### compileDeployPolicy.ps1

After running the **deployInfrastructure.ps1** script, the **deployAll.ps1** script runs the **Office365Policy\compileDeployPolicy.ps1** script.

The **compileDeployPolicy.ps1** script will:

1. Compile the configuration into a **.mof** file by executing the **Office365Policy\Configuration.ps1** script.
2. Renames the resulting .mof file to **EnforceOffice365.mof** to match the configuration name.
3. Create a configuration **EnforceOffice365.zip** package.
4. Upload the configuration package zip file to the storage account deployed by the **deployInfrastructure.ps1** script.
5. Create a GuestConfiguration policy **.json** file.
6. Create an Azure Policy definition with the **.json** file
7. And lastly, creates a new policy assignment that assigns the new policy to the resource group containing the development VM.

## Monitoring policy application

The repository also contains a **monitorPolicyCompliance.ps1** script that will display the current state of the compliance of the policy and exit when the policy becomes compliant.

The DSC Configuration script creates log entries when it is executed and during the installation of Office 365. Thus, to monitor the execution of the DSC Configuration script on the target VM. You can remote into the VM and execute the powershell code below, which will monitor the script's log file and display its entries as they are written:

```
$scriptlog = "C:\Windows\Temp\ScriptLog.log"
while (!(Test-Path $scriptlog)){
    Start-Sleep -Seconds 5
}
Get-Content -Path $scriptlog -Wait -Tail 10
```

I also posted a video demonstrating a sample run of the scripts. The video first shows the deployment of the development infrastructure and compilation, upload, and deployment of the custom DSC policy. Then it shows the monitoring of the installation of Office 365 in a VM. Lastly, it monitors the state of the policy until it becomes compliant.

https://youtu.be/BnP_xWChTNM

I hope you find this project useful.

:smiley: