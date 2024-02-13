Describe 'Set-AzStorageAccountSftpState' {
    BeforeAll {
        $Path = Split-Path -Path $PSScriptRoot
        $ScriptPath = Join-Path -Path $Path -ChildPath Set-AzStorageAccountSftpState.ps1
        $Params = @{
            ResourceGroupName = 'pester-rg'
            StorageAccountName = 'pesterst'
            Subscription = 'pester'
            UseManagedIdentity = $false
        }
    }
    Context 'Run Tests' {
        BeforeAll {
            Mock -CommandName Set-AzContext -ParameterFilter {$Subscription -eq 'pester'} -MockWith {
                return New-Object Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription
            }
            Mock -CommandName Set-AzStorageAccount -MockWith {}
        }
        It 'Should take no action if sftp is disabled' {
            $Params.EnableSftp = $false
            $Response = & $ScriptPath @Params
            $Response -match 'Subscription set to: pester' -or 'SFTP is currently disabled on: pesterst. No action was taken.' |Should -Be $true
        }
        It 'Should take on action if sftp is enabled' {
            $Params.EnableSftp = $true
            $Response = & $ScriptPath @Params
            $Response -match 'Subscription set to: pester' -or 'SFTP is currently enabled on: pesterst. No action was taken.' |Should -Be $true
        }
        It 'Should enable sftp' {
            $Params.EnableSftp = $true
            $Response = & $ScriptPath @Params
            $Response -match 'Subscription set to: pester' -or 'SFTP has been successfully enabled on: pesterst' |Should -Be $true
        }
        It 'Should disable sftp' {
            $Params.EnableSftp = $false
            $Response = & $ScriptPath @Params
            $Response -match 'Subscription set to: pester' -or 'SFTP has been successfully disabled on: pesterst' |Should -Be $true
        }
    }
}