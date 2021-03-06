#Requires -Version 6
# The psake module is needed to run tests and publish the module to powershell gallery.
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-Module -Name psake -MinimumVersion 4.9.0 -Repository "PSGallery"
Install-Module -Name pester -MinimumVersion 4.9.0 -Repository "PSGallery"
Install-Module -Name PSCodeCovIo -MinimumVersion 1.0.1 -Repository "PSGallery"

if ($env:TRAVIS -eq 'true') {
    & dotnet help | Out-Null
    if (Test-Path -Path "$env:HOME/.dotnet/tools/dotnet-gitversion") {
        Write-Host "GitVersion already installed, skipping installation."
    } else {
        & dotnet tool install --global GitVersion.Tool --version 5.1.1
    }
}
