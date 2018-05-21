<##################################################################################
# THIS SCRIPT AND IT'S COMPONENTS HAVE NOT BEEN TESTED. EVERYTHING IS THEORATICAL!#
##################################################################################>

# Defining variables
$ErrorActionPreference = "Stop"
[string]$Location = "West Europe" #GDPR
[string]$VaultName = "TestKeyVault"
[string]$RGname = "Assessment"
[string]$DeploymentMode = 'Incremental' #storing this here to prevent accidental resource deletion.
[string]$BasePath = "https://raw.githubusercontent.com/Kensjero/Sentia/master"
[Hashtable]$RGtag = @{Environment='Test'; Company='Sentia'}

# Defining the username and password, and storing this into a variable.
$User = "Administrator"
$Password = Get-AzureKeyVaultSecret -VaultName $VaultName -Name "AdminPassword"

# Building the PS Credential object in a secure manner.
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($User, $password.SecretValue) 

#Login to our imaginary Azure account.
Connect-AzureRmAccount -Credential $Cred

# Selecting our imaginary subscription, and assigning it into a variable for further processing.
Select-AzureRmSubscription -SubscriptionId "subscription ID, if I had one. http://i0.kym-cdn.com/entries/icons/facebook/000/010/897/imageso.jpg"
$Subscription = Get-AzureRmSubscription

#Creating a resource group. Location in West Europe due to GDPR.
New-AzureRmResourceGroup -Name $RGname  `
                         -Location $Location `
                         -Tag $RGtag

# Assign the Resource Group to a variable for further processing.
$rg = Get-AzureRmResourceGroup -Name $RGName

#Registering resource provider for the policy
Register-AzureRmResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'

# Creating policy definition to restrict allowed resource types.
$Definition = New-AzureRmPolicyDefinition -Name 'RestrictResourceTypes' `
                                          -DisplayName 'Restrict Resource Types.' `
                                          -Description 'Restricting the allowed resource types during deployment' `
                                          -Policy "$($BasePath)/TypeRestictionPolicy.json"`
                                          -Parameter "$($BasePath)/TypeRestrictionPolicy.paramaters.json"

# Assigning policy to our new RG. 
New-AzureRmPolicyAssignment -Name 'RestrictResourceTypes' -Scope $rg.ResourceId -PolicyDefinition $Definition

# Assigning policy to our subscription. 
New-AzureRmPolicyAssignment -Name 'RestrictResourceTypes' -Scope $Subscription.Id -PolicyDefinition $Definition

# Creating a keyvault for authentication and security purposes. Normally this would be done outside of the script for obvious reasons.
New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $RGname -Location $Location

# Storing my password into the vault, this should be done outside of the main script as well.
Set-AzureKeyVaultSecret -VaultName $VaultName -Name "AdminPassword" -SecretValue (Get-Credential).Password

# Enabling template-deployment for this keyvault.
Set-AzureRmKeyVaultAccessPolicy -VaultName $VaultName -ResourceGroupName $RGname -EnabledForTemplateDeployment

# Testing the deployment before actually deploying. Due to a lack of license I'm not certain on whichi value I could filter. 
$TestResult = Test-AzureRmResourceGroupDeployment

# The variable should contain an error if the deployment is faulty. If the variable is empty, it should be OK.
If ($TestResult -eq $null) {

    New-AzureRmResourceGroupDeployment -Name 'Sentia_Test_Deployment' `
                                       -ResourceGroupName "$($RGname)" `
                                       -Mode "$($DeploymentMode)" `
                                       -TemplateFile "$($BasePath)\azuredeploy.json" `
                                       -TemplateParameterFile "$($BasePath)\azuredeploy.parameters.json" `
                                       -Force -Verbose 
}
