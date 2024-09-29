# Copy the Unreal Windows SDK and tools to the specified AutoSDK directory, HostWin64\Win64 into subdirectories for each Visual Studio version.
# Initial version only does Win64 host and Win64 target.  Support for additional hosts and targets will be necessary.
# TODO: support -WhatIf switch
# TODO: add Host and Target platform selection, support Android targets, Linux targets and hosts, etc.

param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $Path,

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
. ".\Get-VS-Version-By-Tool-Version.ps1"

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
Write-Output "Visual Studio installs: $($VSInstalls.Count)"
if ($VSInstalls.Count -eq 0) {
    Write-Error "No Visual Studio installs found"
    Exit -1
}
Write-Verbose "Visual Studio install 1: $($VSInstalls[0])"

if (-not $SkipVCTools) {
    $VSInstalls | ForEach-Object {
        $vsPath = $_.installationPath
        $vsVersion = $_.buildVersion
        Write-Output "Visual Studio $vsVersion path: $vsPath"
        $vcToolsPath = [IO.Path]::Combine($vsPath, "VC", "Tools", "MSVC")
        Write-Output "VC Tools path: $vcToolsPath"
        Get-ChildItem -Path $vcToolsPath | ForEach-Object {
            $vcToolsVersion = $_.Name
            $outDir = Get-VS-Version-By-Tool-Version -ToolVersion $vcToolsVersion
            Write-Output "VC Tools version: $vcToolsVersion $outDir"
            if (-not [string]::IsNullOrEmpty($outDir)) {
                $inToolsPath = [IO.Path]::Combine($vcToolsPath, $vcToolsVersion)
                Write-Output "Copying VC Tools from $inToolsPath to $outDir"
                Copy-SDK -Source $inToolsPath -Destination ([IO.Path]::Combine($AutoSDKPlatformPath, $outDir))
            }
            else {
                Write-Output "Unknown VC Tools version: $vcToolsVersion update the Build-Unreal-AutoSDK.ps1 script"
            }
        }
    }
}

$windowsSDKDir = Get-WindowsSDK-Path
Write-Output "Windows SDK Dir: $windowsSDKDir"

if (-not $SkipWindowsSDK) {
    # Copy the Windows SDK to $AutoSDKPlatformPath\Windows Kits
    $win10SDKDirPath = [IO.Path]::Combine($windowsSDKDir, "10")
    $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, "Windows Kits")
    Copy-SDK -Source $win10SDKDirPath -Destination $outDir
}

# Handle NetFX SDK and DIA SDK - Theoretically, you could have a NetFX SDK for different Kit installs, and a different DIA SDK for each Visual Studio install
# but I don't think there's any good reason to actually try to handle that, since Epic doesn't seem to handle it.

# NetFX SDK is one level above the SDK directory
if (-not $SkipNetFXSDK) {
    $parentPath = Get-Item -Path $windowsSDKDir | Select-Object -ExpandProperty FullName
    $netFXSDKDir = [IO.Path]::Combine($parentPath, "NETFXSDK")
    # check if preferredVersion is available
    $versions = Get-ChildItem -Path $netFXSDKDir | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty Name
    $preferredVersion = @('4.6.2', '4.6.1', '4.6')
    $shouldUseVersion = $versions | Where-Object { $preferredVersion -contains $_ } | Select-Object -First 1
    if ($shouldUseVersion) {
        $netFXSDKDir = [IO.Path]::Combine($netFXSDKDir, $shouldUseVersion)
        $outDir = [IO.Path]::Combine($AutoSDKPlatformPath, $shouldUseVersion)
    }
    else {
        $outDir = $AutoSDKPlatformPath
        Write-Warning "Unreal may not support using AutoSDK with NETFXSDK versions other than 4.6 - 4.6.2. Versions found: $($versions.Join(', '))"
        Write-Warning "If your version is not supported, compiling Lightmass will fail with a message to install .Net 4.6 or better."
        Write-Warning "A bug has been filed with Epic to support other versions, as the regular compiler step does."
        Write-Warning "You may install .Net 4.6.2 locally and re-run this script to get the correct SDK, or manually put it into your AutoSDK."
        Write-Warning "We are going to copy the versions found, but Unreal may not use them until this bug is fixed."
        Write-Warning "This bug was found in the 5.6 development tree."
    }

    Copy-SDK -Source $netFXSDKDir -Destination $outDir
}

# DIA SDK is installed with the Visual Studio install.
if (-not $SkipDIASDK) {
    $DIASDKDir = [IO.Path]::Combine($VSInstalls[0].installationPath, "DIA SDK")
    $outDir = $AutoSDKPlatformPath

    Copy-SDK -Source $DIASDKDir -Destination $outDir
}

# TODO: print some final output summarizing what we did
Write-Output "Done"
