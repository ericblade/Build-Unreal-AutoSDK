function Get-WindowsSDK-Path {
    # First check the environment for WindowsSdkDir, if it's there, then we're done.
    if (-not [string]::IsNullOrEmpty($env:WindowsSdkDir)) {
        return $env:WindowsSdkDir
    }
    # Instead, search HKLM:\SOFTWARE\Wow6432Node, HKCU:\SOFTWARE\Wow6432Node, HKLM:\SOFTWARE, HKCU:\SOFTWARE for the Microsoft\Microsoft SDKs\Windows\v10.0 key
    # Epic does not suport Windows 8.1 and lower, so let's just grab for v10.  Windows 11 does not have a separate kit at this time.
    $keyPath = "\Microsoft\Microsoft SDKs\Windows\v10.0"
    $regPathsToSearch = @(
        "HKLM:\SOFTWARE"
        "HKCU:\SOFTWARE"
        "HKLM:\SOFTWARE\Wow6432Node"
        "HKCU:\SOFTWARE\Wow6432Node"
    )
    $windowsSDKDir = $null
    $regPathsToSearch | ForEach-Object {
        $regPath = $_ + $keyPath
        Write-Verbose "Searching $regPath"
        if (Test-Path $regPath) {
            Write-Verbose "Found $regPath"
            $windowsSDKDir = (Get-ItemProperty -Path $regPath -Name "InstallationFolder").InstallationFolder
        }
    }
    if ([string]::IsNullOrEmpty($windowsSDKDir)) {
        throw "Could not find Windows SDK installation folder - Install it with the Visual Studio Installer"
    }
    Get-Item -Path $windowsSDKDir | Select-Object -ExpandProperty Parent | Select-Object -ExpandProperty FullName
}