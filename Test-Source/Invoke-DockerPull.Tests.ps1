Import-Module -Force (Get-ChildItem -Path $PSScriptRoot/../Source -Recurse -Include *.psm1 -File).FullName
Import-Module -Global -Force $PSScriptRoot/Docker-CI.Tests.psm1

Describe 'Pull docker images' {

    BeforeEach {
        Initialize-MockReg
        Mock -CommandName "Invoke-Command" $Global:CodeThatReturnsExitCodeZero -Verifiable -ModuleName $Global:moduleName
    }

    AfterEach {
        Assert-MockCalled -CommandName "Invoke-Command" -ModuleName $Global:moduleName
    }

    Context 'Docker pulls docker images' {

        It 'pulls public docker image by image name only' {
            Invoke-DockerPull -ImageName 'ubuntu'
            $result = GetMockValue -Key $Global:InvokeCommandArgsReturnValueKeyName
            Write-Debug $result
            $result | Should -BeLikeExactly "pull ubuntu:latest"
        }

        It 'pulls public docker image by image name and tag' {
            Invoke-DockerPull -ImageName 'ubuntu' -Tag 'bionic'
            $result = GetMockValue -Key $Global:InvokeCommandArgsReturnValueKeyName
            Write-Debug $result
            $result | Should -BeLikeExactly "pull ubuntu:bionic"
        }

        It 'pulls public docker image by registry and image name' {
            Invoke-DockerPull -Registry 'not.docker.hub' -ImageName 'ubuntu'
            $result = GetMockValue -Key $Global:InvokeCommandArgsReturnValueKeyName
            Write-Debug $result
            $result | Should -BeLikeExactly "pull not.docker.hub/ubuntu:latest"
        }

        It 'pulls explicit public docker image with $null registry value and image name' {
            Invoke-DockerPull -Registry $null -ImageName 'ubuntu'
            $result = GetMockValue -Key $Global:InvokeCommandArgsReturnValueKeyName
            Write-Debug $result
            $result | Should -BeLikeExactly "pull ubuntu:latest"
        }

        It 'pulls explicit public docker image with whitespace registry value and image name' {
            Invoke-DockerPull -Registry '   ' -ImageName 'ubuntu'
            $result = GetMockValue -Key $Global:InvokeCommandArgsReturnValueKeyName
            Write-Debug $result
            $result | Should -BeLikeExactly "pull ubuntu:latest"
        }

        It 'pulls explicit public docker image with empty registry value, image name and tag' {
            Invoke-DockerPull -Registry '' -ImageName 'ubuntu' -Tag 'bionic'
            $result = GetMockValue -Key $Global:InvokeCommandArgsReturnValueKeyName
            Write-Debug $result
            $result | Should -BeLikeExactly "pull ubuntu:bionic"
        }

        It 'pulls public docker image by image name and digest' {
            Invoke-DockerPull -ImageName 'ubuntu' -Digest 'sha256:a7b8b7b33e44b123d7f997bd4d3d0a59fafc63e203d17efedf09ff3f6f516152'
            $result = GetMockValue -Key $Global:InvokeCommandArgsReturnValueKeyName
            Write-Debug $result
            $result | Should -BeLikeExactly "pull ubuntu@sha256:a7b8b7b33e44b123d7f997bd4d3d0a59fafc63e203d17efedf09ff3f6f516152"
        }

        It 'pulls public docker image by image name, with both tag and digest; and fails' {
            $theCode = { Invoke-DockerPull -ImageName 'ubuntu' -Tag 'bionic' -Digest 'sha256:f5c0a8d225a4b7556db2b26753a7f4c4de3b090c1a8852983885b80694ca9840' }
            $theCode | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException]) -PassThru
        }

        It 'pulls public docker image by image name with invalid digest, missing sha256: prefix; and fails' {
            $theCode = { Invoke-DockerPull -ImageName 'ubuntu' -Digest 'f5c0a8d225a4b7556db2b26753a7f4c4de3b090c1a8852983885b80694ca9840' }
            $theCode | Should -Throw -ExceptionType ([System.Management.Automation.RuntimeException]) -PassThru
        }

        It 'pulls public docker image by image name with invalid digest, wrong digest length; and fails' {
            $theCode = { Invoke-DockerPull -ImageName 'ubuntu' -Digest 'sha256:f5c0a8d225a4b7556db2b26753a7f4c4d' }
            $theCode | Should -Throw -ExceptionType ([System.Management.Automation.RuntimeException]) -PassThru
        }

        It 'does not allow colons in imagename, force use of tag' {
            $theCode = { Invoke-DockerPull -ImageName 'ubuntu:bionic' }
            $theCode | Should -Throw -ExceptionType ([System.ArgumentException]) -PassThru
        }

        It 'does not allow at signs in imagename, force use of tag' {
            $theCode = { Invoke-DockerPull -ImageName 'ubuntu@sha256:f5c0a8d225a4b7556db2b26753a7f4c4d' }
            $theCode | Should -Throw -ExceptionType ([System.ArgumentException]) -PassThru
        }

        It 'cannot pull the requested docker image, throws exception on non-zero exit code' {
            Mock -CommandName "Invoke-Command" $Global:CodeThatReturnsExitCodeOne  -Verifiable -ModuleName $Global:ModuleName
            $theCode = { Invoke-DockerPull -ImageName 'mcr.microsoft.com/ubuntu' }
            $theCode | Should -Throw -ExceptionType ([System.Exception]) -PassThru
        }
    }

    Context 'Pipeline execution' {

        BeforeEach {
            Initialize-MockReg
            Mock -CommandName "Invoke-Command" $Global:CodeThatReturnsExitCodeZero -Verifiable -ModuleName $Global:ModuleName
        }

        AfterEach {
            Assert-MockCalled -CommandName "Invoke-Command" -ModuleName $Global:ModuleName
        }
        BeforeAll {
            $pipedInput = {
                $input = [PSCustomObject]@{
                    "ImageName" = "myimage";
                    "Registry"  = "localhost";
                    "Tag"       = "v1.0.2"
                }
                return $input
            }
        }

        It 'can consume arguments from pipeline' {
            & $pipedInput | Invoke-DockerPull
        }

        It 'returns the expected pscustomobject' {
            $result = & $pipedInput | Invoke-DockerPull

            $result.ImageName | Should -Be 'myimage'
            $result.Registry | Should -Be 'localhost/'
            $result.Tag | Should -Be 'v1.0.2'
            $result.CommandResult | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Verbosity of execution' {

        It 'outputs results if Quiet is disabled' {
            $tempFile = New-TemporaryFile
            Mock -CommandName "Invoke-Command" $Global:CodeThatReturnsExitCodeZero -Verifiable -ModuleName $Global:ModuleName

            Invoke-DockerPull -ImageName 'ubuntu' -Quiet:$false 6> $tempFile

            $result = Get-Content $tempFile
            $result | Should -Be @('Hello', 'World')
        }

        It 'suppresses results if Quiet is enabled' {
            $tempFile = New-TemporaryFile
            Mock -CommandName "Invoke-Command" $Global:CodeThatReturnsExitCodeZero -Verifiable -ModuleName $Global:ModuleName

            Invoke-DockerPull -ImageName 'ubuntu' -Quiet:$true 6> $tempFile

            $result = Get-Content $tempFile
            $result | Should -BeNullOrEmpty
        }

    }
}
