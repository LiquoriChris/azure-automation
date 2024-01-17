<#
.SYNOPSIS
    Refresh one or more datasets in PowerBI.
.DESCRIPTION
    Runbook will get a workspace and refresh one or more datasets within it. The runbook will utilize the PowerBI rest api to query and refresh the datasets. 
.NOTES
    This script is intended to be run in an Azure Automation runbook. In order to run the runbook, the managed identity will need rbac permissions on the resource group or VM specific resource. See below for managed identity and permission information. This runbook should be set on a schedule to perform tasks on PowerBI.

    Enable Service Account API Access on the PowerBI Tenant:
    https://learn.microsoft.com/en-us/power-bi/enterprise/service-premium-service-principal

    Role Assignments:
    - Member of the PowerBI Workspace

    https://learn.microsoft.com/en-us/power-bi/collaborate-share/service-give-access-new-workspaces

    The runbook uses the system assigned managed identity to connect to Azure using Connect-AzAccount. No client secret is needed as we connect to Azure using `Connect-AzAccount -Identity`
.LINK
    https://learn.microsoft.com/en-us/rest/api/power-bi/
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0,
        HelpMessage = 'Name of the PowerBI workspace.')]
    [string]$WorkspaceName,
    [Parameter(Mandatory,
        Position = 1,
        HelpMessage = 'Name of the dataset(s).')]
    [string]$DatasetName,
    [Parameter(HelpMessage = 'Type of dataset refresh.',
        Position = 2)]
    [ValidateSet('Automatic', 'Full')]
    [string]$RefreshType = 'Full',
    [Parameter(HelpMessage = 'One or more tables and/or partitions to refresh.',
        Position = 3)]
    [object]$RefreshObject,
    [Parameter(HelpMessage = 'Wait for refresh status.',
        Position = 4)]
    [bool]$Wait = $false,
    [Parameter(Position = 5,
        HelpMessage = 'Defaults to true. Should be set to false when using locally in PowerShell console. Azure Automation will use the default value and should not be changed.')]
    [bool]$UseManagedIdentity = $true
)

function Convert-PSObjectToHashtable {
    param (
        [Parameter(Position = 0,
            ValueFromPipeline)]
        [object]$InputObject
    )

    Process {
        if ($null -eq $InputObject) {
            return $null
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $Collection = @(
                foreach ($Object in $InputObject) {
                    Convert-PSObjectToHashtable $Object
                }
            )
            Write-Output -NoEnumerate $Collection
        }
        elseif ($InputObject -is [psobject]) {
            $HashTable = @{}
            foreach ($Property in $InputObject.PSObject.Properties) {
                $HashTable[$property.Name] = (Convert-PSObjectToHashtable $property.Value).PSObject.BaseObject
            }
            $HashTable
        }
        else {
            $InputObject
        }
    }
}

function Get-PBIWorkspace {
    <#
    .SYNOPSIS
        Get a workspace from PowerBI.
    .PARAMETER WorkspaceName
        Name of the workspace.
    .LINK
        https://learn.microsoft.com/en-us/rest/api/power-bi/groups/get-groups
    .EXAMPLE
        Get-PBIWorkspace -WorkspaceName workspace1

        Gets workspace1 from PowerBI.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            Position = 0,
            HelpMessage = 'Name of the PowerBI workspace.')]
        [string]$WorkspaceName
    )

    Try {
        $Params = @{
            Uri = "$($BaseUrl)?`$filter=name eq '$WorkspaceName'"
            Headers = @{
                Authorization = "Bearer $PowerBIAccessToken"
            }
            ErrorAction = 'Stop'
        }
        $Response = (Invoke-RestMethod @Params).value
        if ($Response) {
            [pscustomobject]@{
                WorkspaceName = $Response.name
                WorkspaceId = $Response.id
            }
        }
        else {
            $Message = "$WorkspaceName does not exist"
            Write-Error $Message
            exit 1
        }
    }
    Catch {
        $Message = $_.Exception.Message
        Write-Error $Message
        exit 1
    }
}

function Get-PBIDataset {
    <#
    .SYNOPSIS
        Get dataset(s) from PowerBI.
    .PARAMETER InputObject
        Workspace id.
    .PARAMETER DatasetName
        Name of one or more datasets.
    .LINK
        https://learn.microsoft.com/en-us/rest/api/power-bi/datasets/get-datasets-in-group
    .EXAMPLE
        Get-PBIWorkspace -WorkspaceName workspace1 |Get-PBIDataset -DatasetName dataset1

        Get dataset1 from workspace1 in PowerBI.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            HelpMessage = 'Id of the PowerBI workspace.',
            Position = 0)]
        [object]$InputObject,
        [Parameter(Mandatory,
            HelpMessage = 'Name of one or more PowerBI datasets.',
            Position = 1)]
        [string]$DatasetName
    )

    Try {
        $Params = @{
            Uri = "$($BaseUrl)/$($InputObject.WorkspaceId)/datasets"
            Headers = @{
                Authorization = "Bearer $PowerBIAccessToken"
            }
            ErrorAction = 'Stop'
        }
        $Response = (Invoke-RestMethod @Params).value
        $Dataset = $Response |Where-Object -Property name -eq $DatasetName
        if ($Dataset) {
            [pscustomobject]@{
                WorkspaceName = $InputObject.WorkspaceName
                WorkspaceId = $InputObject.WorkspaceId
                DatasetName = $Dataset.name
                DatasetId = $Dataset.id
            }
        }
        else {
            $Message = "Dataset: $DatasetName does not exist in $($InputObject.WorkspaceName)"
            Write-Error $Message
        }
    }
    Catch {
        $Message = $_.Exception.Message
        Write-Error $Message
        exit 1
    }
}

function Invoke-PBIDatasetRefresh {
    <#
    .SYNOPSIS
        Sends a refresh to one or more datasets in PowerBI.
    .PARAMETER InputObject
        Workspace and dataset information to invoke a refresh on one or more datasets.
    .LINK
        https://learn.microsoft.com/en-us/rest/api/power-bi/datasets/refresh-dataset-in-group
    .EXAMPLE
        Get-PBIWorkspace -WorkspaceName workspace1 |Get-PBIDataset -DatasetName dataset1 |Invoke-PBIDatasetRefresh

        Refreshes dataset1 in workspace1.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            HelpMessage = 'Workspace and dataset information to invoke a refresh on one or more datasets.',
            Position = 0)]
        [object]$InputObject,
        [Parameter(HelpMessage = 'Type of dataset refresh.',
            Position = 1)]
        [ValidateSet('Automatic', 'Full')]
        [string]$RefreshType,
        [Parameter(HelpMessage = 'One or more tables and/or partitions to refresh.',
            Position = 2)]
        [object]$RefreshObject
    )

    Process {
        Try {
            $Message = "$RefreshType refresh has been started on dataset: $($InputObject.DatasetName)"
            $Body = @{
                notifyOption = 'NoNotification'
                type = $RefreshType
            }
            if ($RefreshObject) {
                if ($RefreshObject -is [string]) {
                    $RefreshObject = Invoke-Expression -Command $RefreshObject
                }
                if (($RefreshObject |Get-Member).MemberType -contains 'NoteProperty') {
                    $RefreshObject = $RefreshObject |Convert-PSObjectToHashtable
                }
                $ObjectList = New-Object System.Collections.ArrayList
                foreach ($Object in $RefreshObject) {
                    [void]$ObjectList.Add(
                        $Object
                    )
                    $Message += "`nTable: $($Object.table)"
                    if ($Object.partition) {
                        $Message += "`nPartition: $($Object.partition)"
                    }
                }
                $Body.objects = @(
                    $ObjectList
                )
            }
            $Params = @{
                Uri = "$($BaseUrl)/$($InputObject.WorkspaceId)/datasets/$($InputObject.DatasetId)/refreshes"
                Headers = @{
                    Authorization = "Bearer $PowerBIAccessToken"
                }
                Method = 'Post'
                Body = $Body |ConvertTo-Json -ErrorAction Stop
                ErrorAction = 'Stop'
            }
            Invoke-RestMethod @Params
            Write-Output $Message
        }          
        Catch {
            $Message = $_.Exception.Message
            Write-Error $Message
            continue
        }
    }
}

function Get-PBIDatasetRefreshStatus {
    <#
    .SYNOPSIS
        Gets the status of the dataset refresh.
    .DESCRIPTION
        Function will use the workspace and datasets id to get the status of the refresh and wait for a status.
    .PARAMETER InputObject
        Object to build the url to find and wait for a status from the refresh.
    .LINK
        https://learn.microsoft.com/en-us/rest/api/power-bi/datasets/get-refresh-history-in-group
    .EXAMPLE
        $Dataset |Get-PBIDatasetRefreshStatus

        Gets the refresh status from the $Dataset variable.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            HelpMessage = 'Workspace and dataset information to invoke a refresh on one or more datasets.',
            Position = 0)]
        [object]$InputObject
    )
    
    Process {
        foreach ($Object in $InputObject) {
            Try {
                do {
                    $Params = @{
                        Uri = "$($BaseUrl)/$($InputObject.WorkspaceId)/datasets/$($InputObject.DatasetId)/refreshes?`$top=1"
                        Headers = @{
                            Authorization = "Bearer $PowerBIAccessToken"
                        }
                        ErrorAction = 'Stop'
                    }
                    $Response = (Invoke-RestMethod @Params).value
                    if ($Response.status -eq 'Completed') {
                        Write-Output "$($Object.DatasetName) refresh has a status of: Completed"
                    }
                    if ($Response.status -eq 'Failed') {
                        $Message = "$($Object.DatasetName) refresh has a status of: Failed`n"
                        $Message += $Response.serviceExceptionJson
                        Write-Error $Message
                        exit 1
                    }
                    Start-Sleep -Seconds 10
                }
                until ($Response.status -ne 'Unknown')
            }
            Catch {
                $Message = $_.Exception.Message
                Write-Error $Message
                continue
            }
        }
    }
}

# Base url for PowerBI api.
$BaseUrl = 'https://api.powerbi.com/v1.0/myorg/groups'

# Authenticate using managed identity
if ($UseManagedIdentity) {
    Connect-AzAccount -Identity |Out-Null
}

# Get access tokens for PowerBI.
$PowerBIAccessToken = (Get-AzAccessToken -ResourceUrl https://analysis.windows.net/powerbi/api).Token

# Get workspace and dataset information.
$Dataset = Get-PBIWorkspace @Params -WorkspaceName $WorkspaceName |Get-PBIDataset @Params -DatasetName $DatasetName
if ($RefreshObject) {
    $Params.RefreshObject = $RefreshObject
}

# Run refresh.
$Dataset |Invoke-PBIDatasetRefresh @Params -RefreshType $RefreshType

# Wait for refresh to complete before runbook completes.
if ($Wait) {
    $Dataset |Get-PBIDatasetRefreshStatus @Params
}