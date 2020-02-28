function Invoke-DockerTests {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [String]
        $ImageName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String]
        $ConfigPath = '.',

        [ValidateNotNullOrEmpty()]
        [String]
        $TestReportDir = '.',

        [ValidateNotNullOrEmpty()]
        [String]
        $TestReportName = 'testreport.json',

        [Switch]
        $TreatTestFailuresAsExceptions = $false,

        [Switch]
        $Quiet = [System.Convert]::ToBoolean($env:DOCKER_CI_QUIET_MODE)
    )
    $absoluteConfigPath = Format-AsAbsolutePath ($ConfigPath)
    if (Test-Path -Path $absoluteConfigPath -PathType Container) {
        $foundConfigFiles = ((Get-ChildItem -Path $absoluteConfigPath -Filter *.y*ml | Select-Object FullName) | ForEach-Object { $_.FullName })
    }
    if ($null -eq $foundConfigFiles -or $foundConfigFiles.Length -eq 0) {
        throw [System.ArgumentException]::new('$ConfigPath does not contain any test configuration file.')
    }

    $here = Format-AsAbsolutePath (Get-Location)
    $absoluteTestReportDir = Format-AsAbsolutePath ($TestReportDir)
    if (!(Test-Path $absoluteTestReportDir -PathType Container)) {
        New-Item $absoluteTestReportDir -ItemType Directory -Force | Out-Null
    }
    $osType = Find-DockerOSType
    $dockerSocket = Find-DockerSocket -OsType $osType
    if ($osType -ieq 'windows') {
        $configs = 'C:/configs'
        $report = 'C:/report'
    } else {
        $configs = '/configs'
        $report = '/report'
    }
    $structureCommand = "run -i" + `
        " -v `"${here}:${configs}`"" + `
        " -v `"${absoluteTestReportDir}:${report}`"" + `
        " -v `"${dockerSocket}:${dockerSocket}`"" + `
        " 3shape/containerized-structure-test:latest test -i ${ImageName} --test-report ${report}/${TestReportName}"

    $foundConfigFiles.ForEach( {
            $configFile = Convert-ToUnixPath (Resolve-Path -Path $_  -Relative)
            $configName = Remove-Prefix -Value $configFile -Prefix './'
            $structureCommand = -join ($structureCommand, " -c ${configs}/${configName}")
        }
    )
    $commandResult = Invoke-DockerCommand $structureCommand
    if ($TreatTestFailuresAsExceptions) {
        Assert-ExitCodeOk $commandResult
    }

    $testReportPath = Join-Path $absoluteTestReportDir $TestReportName
    $testReportExists = Test-Path -Path $testReportPath -PathType Leaf
    if ($testReportExists) {
        $testResult = $(ConvertFrom-Json $(Get-Content $testReportPath))
    }

    $result = [PSCustomObject]@{
        'TestResult'     = $testResult
        'TestReportPath' = $testReportPath
        'CommandResult'  = $commandResult
        'ImageName'      = $ImageName
    }
    if (!$Quiet) {
        Write-CommandOuput $($result.TestResult)
    }
    return $result
}
