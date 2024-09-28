# Copy the Unreal Windows SDK and tools to the specified AutoSDK directory, HostWin64\Win64 into subdirectories for each Visual Studio version.
# Initial version only does Win64 host and Win64 target.  Support for additional hosts and targets will be necessary.
# TODO: we should probably use RoboCopy instead of Copy-Item for better performance...
# TODO: support -WhatIf switch

param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $Path = "h:\Unreal\AutoSDK",

    [Parameter()]
    [switch]
    $Clean,

    [Parameter()]
    [switch]
    $SkipVCTools,

    [Parameter()]
    [switch]
    $SkipWindowsSDK,

    [Parameter()]
    [switch]
    $SkipNetFXSDK,

    [Parameter()]
    [switch]
    $SkipDIASDK
)

. ".\Get-AutoSDK-PlatformPath.ps1"
. ".\Get-VisualStudio-Installs.ps1"
. ".\Get-WindowsSDK-Path.ps1"
. ".\Copy-SDK.ps1"

$AutoSDKRoot = Get-Item -Path $Path -ErrorAction SilentlyContinue
if (-not $AutoSDKRoot) {
    Write-Output "AutoSDK path not found: $Path"
    New-Item -Path $Path -ItemType Directory
    $AutoSDKRoot = Get-Item -Path $Path
}

# Gather up all the things the Windows AutoSDK needs - VC++ Tools, Windows 10 SDK Kit, NetFX SDK, DIA SDK
# As each one is found, copy it to the AutoSDKPlatformPath directory.

Write-Output "AutoSDK path: $AutoSDKRoot"
$AutoSDKPlatformPath = Get-AutoSDK-PlatformPath -Root $AutoSDKRoot -HostPlatform Win64 -TargetPlatform Win64
Write-Output "AutoSDK platform path: $AutoSDKPlatformPath"

if ($Clean) {
    Write-Output "Cleaning AutoSDK platform path: $AutoSDKPlatformPath"
    Remove-Item -Path $AutoSDKPlatformPath -Recurse -Force
}

$VSInstalls = Get-VisualStudio-Installs
Write-Information "Visual Studio installs: $($VSInstalls.Count)"
if ($VSInstalls.Count -eq 0) {
    Write-Error "No Visual Studio installs found"
    Exit -1
}
Write-Verbose "Visual Studio install 1: $($VSInstalls[0])"

$VSInstalls | ForEach-Object {
    $vsPath = $_.installationPath
    $vsVersion = $_.buildVersion
    Write-Output "Visual Studio $vsVersion path: $vsPath"
    $vcToolsPath = [IO.Path]::Combine($vsPath, "VC", "Tools", "MSVC")
    Write-Output "VC Tools path: $vcToolsPath"
    Get-ChildItem -Path $vcToolsPath | ForEach-Object {
        $vcToolsVersion = $_.Name
        Write-Output "VC Tools version: $vcToolsVersion"
        $outDir = ""
        switch -regex ($vcToolsVersion) {
            # https://gist.github.com/RDCH106/40fe61f447df58c1b9c83a1781374bcd
            "14.1[0-9]" {
                $outDir = "VS2017"
                Write-Output "VS 2017"
            }
            "14.2[0-9]" {
                $outDir = "VS2019"
                Write-Output "VS 2019"
            }
            "14.3[0-9]" {
                $outDir = "VS2022"
                Write-Output "VS 2022"
            }
            "14.4[0-9]" {
                $outDir = "VS2022"
                Write-Output "VS 2022 17.10+" # https://devblogs.microsoft.com/cppblog/msvc-toolset-minor-version-number-14-40-in-vs-2022-v17-10/
            }
        }
        if (-not $SkipVCTools) {
            # TODO: need to reflow this some to be able to put the SKipVCTools switch earlier since some other code below is probably dependent on a variable set above here.
            # I may be wrong about that, though.
            if (-not [string]::IsNullOrEmpty($outDir)) {
                $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, $outDir)
                $inToolsPath = [IO.Path]::Combine($vcToolsPath, $vcToolsVersion)
                Copy-SDK -Source $inToolsPath -Destination $outDir
            }
            else {
                Write-Output "Unknown VC Tools version: $vcToolsVersion update the Build-Unreal-AutoSDK.ps1 script"
            }
        }
    }
}

$windowsSDKDir = Get-WindowsSDK-Path
Write-Output "Windows SDK Dir: $windowsSDKDir"

$win10SDKDirPath = [IO.Path]::Combine($windowsSDKDir, "10")
if (-not $SkipWindowsSDK) {
    # Copy the Windows SDK to $AutoSDKPlatformPath\Windows Kits\10
    $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, "Windows Kits")
    Copy-SDK -Source $win10SDKDirPath -Destination $outDir
}

# Handle NetFX SDK and DIA SDK - Theoretically, you could have a NetFX SDK for different Kit installs, and a different DIA SDK for each Visual Studio install
# but I don't think there's any good reason to actually try to handle that, since Epic doesn't seem to handle it.

# NetFX SDK is one level above the SDK directory
if (-not $SkipNetFXSDK) {
    $parentPath = Get-Item -Path $windowsSDKDir | Select-Object -ExpandProperty FullName
    $netFXSDKDir = [IO.Path]::Combine($parentPath, "NETFXSDK")
    $outDir = $AutoSDKPlatformPath

    Copy-SDK -Source $netFXSDKDir -Destination $outDir
}

# DIA SDK is installed with the Visual Studio install.
if (-not $SkipDIASDK) {
    $DIASDKDir = [IO.Path]::Combine($vsPath, "DIA SDK")
    $outDir = $AutoSDKPlatformPath

    Copy-SDK -Source $DIASDKDir -Destination $outDir
}

# TODO: print some final output summarizing what we did
Write-Output "Done"
