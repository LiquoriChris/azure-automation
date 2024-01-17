<#
.SYNOPSIS
    Starts a runbook one or more times.
.DESCRIPTION
    Runbook will trigger a child runbook one or more times.
.NOTES
    This script is intended to be run in an Azure Automation runbook. In order to run the runbook, the managed identity will need rbac permissions.

    Role Assignments:
    Contributor

    This runbook uses an internal cmdlet `Start-AutomationRunbook` that will trigger a child runbook in the same automation account.

    To trigger a child runbook, a psobject or json string equivalent should be passed in the ChildRunbookInputParameters parameter. The object should contain the following:
    - Name. Mandatory. Name of the child runbook to trigger.
    - Parameters. Optional. Parameters associated with the child runbook.
    - RunOn. Optional. Name of the hybrid worker for on-prem agents.

    Examples:
        Trigger runbook from Azure portal:
        {"Name":"My-ChildRunbook","Parameters":"Param1":"Working"}

        Trigger runbook from PowerShell console:
        Start-AzAutomationRunbook -ResourceGroupName automation-rg -AutomationAccountName automation -Name My-ParentRunbook -Parameters @{
            ChildRunbookInputParameters = @{
                Name = 'My-ChildRunbook'
                Parameters = @{
                    Param1 = 'Working'
                }
            }
        }
.LINK
    https://learn.microsoft.com/en-us/azure/automation/shared-resources/modules#internal-cmdlets
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [object]$ChildRunbookInputParameters
)

# Replace escape backslash if using Azure portal to trigger the runbook.
if ($ChildRunbookInputParameters -is [string]) {
    $ChildRunbookInputParameters = $ChildRunbookInputParameters -replace '\\','' |ConvertFrom-Json
}
foreach ($InputParameter in $ChildRunbookInputParameters) {
    Try {
        if (($InputParameter |Get-Member -MemberType NoteProperty).Name -notcontains 'Name') {
            Write-Error "Name parameter is required. It should contain the name of the child runbook to trigger"
            continue
        }
        else {
            $Params = @{
                Name = $InputParameter.Name
                ErrorAction = 'Stop'
            }
            if ($InputParameter.Parameters) {
                $HashTable = @{}
                $InputParameter.Parameters.PSObject.Properties |Foreach-Object {
                    $HashTable[$($PSItem.Name)] = $PSItem.Value
                }
                $Params.Parameters = $HashTable
            }
            if ($InputParameter.RunOn) {
                $Params.RunOn = $InputParameter.RunOn
            }
            $TriggerRunbook = Start-AutomationRunbook @Params
            Write-Output "Starting runbook $($InputParameter.Name) with guid: $($TriggerRunbook.Guid)"
        }
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        Write-Error $ErrorMessage
        continue
    }
}