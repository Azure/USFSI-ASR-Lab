param (
    [int] $MaxRetry = 3
)
function Enter-Login {
    Write-Information ">>> Initiating a login" -InformationAction Continue
    Connect-AzAccount
}

function Get-SignedInUser {

    $varSignedInUserDetails = Get-AzADUser -SignedIn

    if (!$varSignedInUserDetails) {
        Write-Information ">>> No logged in user found." -InformationAction Continue
        # Enter-Login
    }
    else {
        return $varSignedInUserDetails.UserPrincipalName
    }

    return $null

}

# function Confirm-UserOwnerPermission {
#     if ($null -ne $varSignedInUser) {

#         $subscriptionId = $varParameters.subscriptionId
#         $varSignedInUser = $varSignedInUserDetails.UserPrincipalName
#         Set-AzContext -subscriptionId $subscriptionId
#         Write-Information "`n>>> Checking the owner permissions for user: $varSignedInUser at $subscriptionId scope"  -InformationAction Continue
#         $roleAssignments  = Get-AzRoleAssignment -ObjectId $varSignedInUserDetails.Id -Scope "/subscriptions/$subscriptionId" -ErrorAction SilentlyContinue
#         $hasContributorRole = $roleAssignments | Where-Object {
#             $_.RoleDefinitionName -eq "Contributor" -or $_.RoleDefinitionName -eq "Owner"
#         }

#         if (!$hasContributorRole) {
#             Write-Information "Signed in user: $varSignedInUser does not have sufficient permission to the /subscriptions/$subscriptionId scope."  -InformationAction Continue
#             Write-Information "Permissions assigned: $roleAssignments"  -InformationAction Continue
#             return $false
#         }
#         else {
#             Write-Information "Signed in user: $varSignedInUser has sufficient permissions at the root /subscriptions/$subscriptionId scope."  -InformationAction Continue
#         }
#         return $true
#     }
#     else {
#         Write-Error "Logged in user details are empty." -ErrorAction Stop
#     }
# }

function New-ASRDemo {
    param()

    $parDeploymentPrefix = $varParameters.bicepParam.parDeploymentPrefix
    $parTimeStamp = $varParameters.varTimeStamp
    $parDeploymentLocation = $varParameters.bicepParam.sourceLocation
    $biceptemplateDeploymentName = "$parDeploymentPrefix-deploy-$partimeStamp"
    $parameters = @{
        parDeploymentPrefix = $varParameters.bicepParam.parDeploymentPrefix
        sourceLocation      = $varParameters.bicepparam.sourceLocation
        targetLocation      = $varParameters.bicepParam.targetLocation
        vmadminPassword     = $varParameters.bicepParam.vmAdminPassword
        sourceVnetConfig    = $varParameters.bicepParam.sourceVnetConfig
        targetVnetConfig    = $varParameters.bicepParam.targetVnetConfig
        vmConfigs           = $varParameters.bicepParam.vmConfigs
    }

    # Get-SignedInUser
    Set-AzContext -subscription $varParameters.subscriptionId

    while ($conLoopCounter -lt $conMaxRetryAttemptTransientErrorRetry) {
        try {
            Write-Information ">>> ASR Demo deployment started" -InformationAction Continue
            $bicepdeployment = New-AzSubscriptionDeployment `
                -Name $biceptemplateDeploymentName `
                -Location $parDeploymentLocation `
                -TemplateFile $biceptemplate `
                -parDeploymentPrefix $parameters.parDeploymentPrefix `
                -TemplateParameterObject $parameters `
                -WarningAction Ignore

            if (!$bicepdeployment -or $bicepdeployment.ProvisioningState -eq "Failed") {
                Write-Error "Error while executing ASR Demo deployment script" -ErrorAction Stop
            }

            return $bicepdeployment
        }
        catch {
            $conLoopCounter++
            $varException = $_.Exception
            $varErrorDetails = $_.ErrorDetails
            $varTrace = $_.ScriptStackTrace
            Write-Error "$varException \n $varErrorDetails \n $varTrace" -ErrorAction Continue

            if ($conRetry -and $conLoopCounter -lt $conMaxRetryAttemptTransientErrorRetry) {
                Write-Information ">>> Retrying deployment after waiting for $conRetryWaitTimeTransientErrorRetry secs" -InformationAction Continue
                Start-Sleep -Seconds $conRetryWaitTimeTransientErrorRetry
            }
            else {
                Write-Error ">>> Error occurred in Lighthouse deployment. Please try after addressing the error : $varException \n $varErrorDetails \n $varTrace" -ErrorAction Stop
            }
        }
    }
}

# Import the modules
$moduleName = "powershell-yaml"
if (-not (Get-Module -Name $moduleName -ListAvailable)) {
    Write-Output "Module '$moduleName' is not installed. Installing now..."
    Install-Module -Name $moduleName -Force
}
else {
    Write-Output "Module '$moduleName' is already installed."
    if (-not (Get-Module -Name $moduleName)) {
        Import-Module -Name $moduleName
    }
    else {
        Write-Output "Module $moduleName is already loaded."
    }
}
$moduleName = "Az"
if (-not (Get-Module -Name $moduleName -ListAvailable)) {
    Write-Output "Module '$moduleName' is not installed. Installing now..."
    Install-Module -Name $moduleName -Force
}
else {
    Write-Output "Module '$moduleName' is already installed."
    Write-Output "Module '$moduleName' can take a minute or two to load."
    if (-not (Get-Module -Name $moduleName)) {
        Import-Module -Name $moduleName
    }
    else {
        Write-Output "Module $moduleName is already loaded."
    }
}

# Get the current Azure context
$context = Get-AzContext

# Checking if the user is logged in
if ($context) {
    # If a context is found, display the account information
    Write-Output "User is logged in as: $($context.Account.Id)"
}
else {
    # If no context is found, inform the user
    Write-Output "No user is currently logged in. Please log in to Azure now."
    Enter-Login
}

# Convert the YAML content to a PowerShell object
write-output "Reading the YAML file"
$varParameters = ConvertFrom-Yaml -Yaml $(Get-Content -Path "./deployparam.yaml" -Raw)
$varParameters.add("varTimeStamp", (Get-Date).ToString("yyyy-MM-ddTHH.mm.ss"))

#constants
$conMaxRetryAttemptTransientErrorRetry = $MaxRetry
$conRetry = $true
$conRetryWaitTimeTransientErrorRetry = 10
$conLoopCounter = 0

#bicep files
$biceptemplate = '.\deploy.bicep'

New-ASRDemo