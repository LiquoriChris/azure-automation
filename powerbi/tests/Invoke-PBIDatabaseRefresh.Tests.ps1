Describe 'Invoke-PBIDatasetRefresh' {
    BeforeAll {
        $RootFolder = Split-Path -Path $PSScriptRoot -Parent
        $InformationFunction = Join-Path -Path (Split-Path -Path $RootFolder -Parent) -ChildPath 'helperFunctions/Get-FunctionInformation.ps1'
        . $InformationFunction
        $ScriptPath = Join-Path -Path $RootFolder -ChildPath 'Invoke-PBIDatasetRefresh.ps1'
        $PowerBIAccessToken = (Get-AzAccessToken -ResourceUrl https://analysis.windows.net/powerbi/api).Token
    }
    Context 'Run Tests' {
        BeforeAll {
            $FunctionInformation = Get-FunctionInformation -Path $ScriptPath |Where-Object -Property Name -eq 'Invoke-PBIDatasetRefresh'
            $CreateFunction = "function $($FunctionInformation.Name) { $($FunctionInformation.Definition) }"
            $GetFunction = [scriptblock]::Create($CreateFunction)
            . $GetFunction
            $Object = [pscustomobject]@{
                WorkspaceName = 'workspace1'
                WorkspaceId = '8956a288-0ff5-4574-8a09-f5280e8a4190'
                DatasetName = 'dataset1'
                DatasetId = '2e0fdc94-25ea-4e32-a0eb-5e8694d1abbe'
            }
        }
        It 'Should refresh a dataset' {
            Mock -CommandName Invoke-RestMethod -MockWith {}
            $Result = Invoke-PBIDatasetRefresh -InputObject $Object -RefreshType Automatic -ErrorAction Stop
            $Result |Should -BeExactly 'Automatic refresh has been started on dataset: dataset1'
            Assert-MockCalled -CommandName Invoke-RestMethod -Exactly -Times 1
        }
        It 'Should error if the dataset does not exist' {
            Mock -CommandName Invoke-RestMethod -MockWith {throw 'dataset does not exist'}
            {Invoke-PBIDatasetRefresh -InputObject $Object -RefreshType Automatic -ErrorAction Stop} |Should -Throw
            Assert-MockCalled -CommandName Invoke-RestMethod -Exactly -Times 1
        }
    }
}