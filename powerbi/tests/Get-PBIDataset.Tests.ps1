Describe 'Get-PBIDataset' {
    BeforeAll {
        $RootFolder = Split-Path -Path $PSScriptRoot -Parent
        $InformationFunction = Join-Path -Path (Split-Path -Path $RootFolder -Parent) -ChildPath 'helperFunctions/Get-FunctionInformation.ps1'
        . $InformationFunction
        $ScriptPath = Join-Path -Path $RootFolder -ChildPath 'Invoke-PBIDatasetRefresh.ps1'
        $PowerBIAccessToken = (Get-AzAccessToken -ResourceUrl https://analysis.windows.net/powerbi/api).Token
    }
    Context 'Run Tests' {
        BeforeAll {
            $FunctionInformation = Get-FunctionInformation -Path $ScriptPath |Where-Object -Property Name -eq 'Get-PBIDataset'
            $CreateFunction = "function $($FunctionInformation.Name) { $($FunctionInformation.Definition) }"
            $GetFunction = [scriptblock]::Create($CreateFunction)
            . $GetFunction
            $Object = [pscustomobject]@{
                WorkspaceName = 'workspace1'
                WorkspaceId = '8956a288-0ff5-4574-8a09-f5280e8a4190'
            }
        }
        It 'Should return a dataset' {
            Mock -CommandName Get-PBIDataset -MockWith {
                [pscustomobject]@{
                    WorkspaceName = 'workspace1'
                    WorkspaceId = '8956a288-0ff5-4574-8a09-f5280e8a4190'
                    DatasetName = 'dataset1'
                    DatasetId = '2e0fdc94-25ea-4e32-a0eb-5e8694d1abbe'
                }
            }
            $Result = Get-PBIDataset -InputObject $Object -DatasetName dataset1
            $Result.DatasetName |Should -BeExactly 'dataset1'
        }
        It 'Should error if database does not exist' {
            Mock -CommandName Get-PBIDataset -MockWith {throw 'Dataset: dataset1 does not exist in workspace1'}
            {Get-PBIDataset -InputObject $Object -DatasetName dataset1 -ErrorAction Stop} |Should -Throw 'Dataset: dataset1 does not exist in workspace1'
        }
    }
}