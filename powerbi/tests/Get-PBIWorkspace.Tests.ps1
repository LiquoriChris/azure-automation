Describe 'Get-PBIWorkspace' {
    BeforeAll {
        $RootFolder = Split-Path -Path $PSScriptRoot -Parent
        $InformationFunction = Join-Path -Path (Split-Path -Path $RootFolder -Parent) -ChildPath 'helperFunctions/Get-FunctionInformation.ps1'
        . $InformationFunction
        $ScriptPath = Join-Path -Path $RootFolder -ChildPath 'Invoke-PBIDatasetRefresh.ps1'
        $PowerBIAccessToken = (Get-AzAccessToken -ResourceUrl https://analysis.windows.net/powerbi/api).Token
    }
    Context 'Run Tests' {
        BeforeAll {
            $FunctionInformation = Get-FunctionInformation -Path $ScriptPath |Where-Object -Property Name -eq 'Get-PBIWorkspace'
            $CreateFunction = "function $($FunctionInformation.Name) { $($FunctionInformation.Definition) }"
            $GetFunction = [scriptblock]::Create($CreateFunction)
            . $GetFunction
        }
        It 'Should return the workspace' {
            Mock -CommandName Get-PBIWorkspace -MockWith {
                [pscustomobject]@{
                    WorkspaceName = 'workspace1'
                    WorkspaceId = '8956a288-0ff5-4574-8a09-f5280e8a4190'
                }
            }
            $Result = Get-PBIWorkspace -WorkspaceName 'workspace1'
            $Result.WorkspaceName |Should -BeExactly 'workspace1'
        }
        It 'Should error if workspace does not exist' {
            Mock -CommandName Get-PBIWorkspace -MockWith { throw 'workspace1' }
            {Get-PBIWorkspace -WorkspaceName 'workspace1' -ErrorVariable err -ErrorAction Stop} |Should -Throw 'workspace1'

        }
    }
}