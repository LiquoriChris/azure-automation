<#
.SYNOPSIS
    Script can enable or disable sftp on an Azure storage account.
.NOTES
    This script is intended to be run in an Azure Automation runbook. In order to run the runbook, the managed identity will need rbac permissions on the resource group or storage account specific resource. See below for managed identity and permission information.

    Role Assignments:\
    Storage Account Contributor

    Resources:
    1. Storage account

    The runbook uses the system assigned managed identity to connect to Azure using Connect-AzAccount. No client secret is needed as we connect to Azure using `Connect-AzAccount -Identity`
.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.storage/set-azstorageaccount?view=azps-11.2.0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory,
        HelpMessage = 'Name of the resource group containing the storage account.',
        Position = 0)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory,
        HelpMessage = 'Name of the storage account.',
        Position = 1)]
    [string]$StorageAccountName,
    [Parameter(HelpMessage = 'Enable sftp on the storage account.',
        Position = 2)]
    [bool]$EnableSftp = $false,
    [Parameter(HelpMessage = 'Disable sftp on the storage account.',
        Position = 3)]
    [bool]$DisableSftp = $false,
    [Parameter(Position = 4,
        HelpMessage = 'Sets the subscription context.')]
    [string]$Subscription,
    [Parameter(Position = 6,
        HelpMessage = 'Defaults to true. Should be set to false when using locally in PowerShell console. Azure Automation will use the default value and should not be changed.')]
    [bool]$UseManagedIdentity = $true
)

# Connect to Azure PowerShell using managed identity. Set to false if running locally or Pester tests.
if ($UseManagedIdentity) {
    Connect-AzAccount -Identity |Out-Null
}

# Set the subscription context.
Set-AzContext -Subscription $Subscription -ErrorAction Stop |Out-Null
Write-Output "Subscription set to: $Subscription"

Try {
    $Params = @{
        ResourceGroupName = $ResourceGroupName
        Name = $StorageAccountName
        ErrorAction = 'Stop'
    }
    $StorageAccount = Get-AzStorageAccount @Params
    if ($EnableSftp) {
        if ($StorageAccount.EnableSftp) {
            Write-Output "SFTP is currently enabled on: $($StorageAccount.StorageAccountName). No action was taken."
            exit 0
        }
        else {
            $Params.EnableSftp = $true
            Write-Output "Enabling SFTP on: $($StorageAccount.StorageAccountName)"
            Try {
                Set-AzStorageAccount @Params |Out-Null
                Write-Output "SFTP has been successfully enabled on: $($StorageAccount.StorageAccountName)"
            }
            Catch {
                $Message = $_.Exception.Message
                Write-Error $Message
                exit 1
            }
        }
    }
    if ($DisableSftp) {
        if (-not($StorageAccount.EnableSftp)) {
            Write-Output "SFTP is currently disabled on: $($StorageAccount.StorageAccountName). No action was taken."
            exit 0
        }
        else {
            $Params.EnableSftp = $false
            Write-Output "Disabling SFTP on: $($StorageAccount.StorageAccountName)"
            Try {
                Set-AzStorageAccount @Params |Out-Null
                Write-Output "SFTP has been successfully disabled on: $($StorageAccount.StorageAccountName)"
            }
            Catch {
                $Message = $_.Exception.Message
                Write-Error $Message
                exit 1
            }
        }
    }
}
Catch {
    $Message = $_.Exception.Message
    Write-Error $Message
    exit 1
}