function Get-Android-SDKs {
    $AndroidSDKRootPaths = @(
        "${env:ProgramFiles(x86)}\Android\android-sdk"
        "$env:LocalAppData\Android\Sdk"
        "$env:ANDROID_HOME\Android\Sdk"
        "$env:ANDROID_SDK_HOME\Android\Sdk"
    )

    # if installed in \Program Files (x86)\Android then the SDK is in android-sdk and the NDK is in \Program Files (x86)\Android\AndroidNDK\(version)
    # if installed in %LocalAppData%\Android\ then the SDK is in Sdk and the NDK is in SDK\ndk\(version)
    # and this is all a righteous mess

    # Get the parent directory for each one of these paths, and see if it exists
    $AndroidSDKRoots = $AndroidSDKRootPaths | Get-Item -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Parent | Select-Object -ExpandProperty FullName
    Write-Output "Android SDK Roots: $($AndroidSDKRoots.Count) $($AndroidSDKRoots.FullName)"

    $SDKRoots = $AndroidSDKRoots | Get-ChildItem -Directory | Where-Object { $_.Name -like "android-sdk" -or $_.Name -like "Sdk" }
    $SDKVersions = $SDKRoots | Get-ChildItem -Directory -Filter "build-tools\*" | Select-Object -ExpandProperty Name
    $NDKRoots = $AndroidSDKRoots | ForEach-Object {
        $ndkPath = Join-Path -Path $_ -ChildPath "AndroidNDK"
        if (Test-Path -Path $ndkPath) {
            $ndkPath
        } else {
            $ndkPath = Join-Path -Path $_ -ChildPath "Sdk"
            $ndkPath = Join-Path -Path $ndkPath -ChildPath "ndk"
            if (Test-Path -Path $ndkPath) {
                $ndkPath
            }
        }
    }
    $NDKVersions = $NDKRoots | Get-ChildItem -Directory | Select-Object -ExpandProperty Name
    Write-Output "SDK Roots: $($SDKRoots.Count) $SDKRoots"
    Write-Output "SDK Versions: $($SDKVersions.Count) $SDKVersions"
    Write-Output "NDK Roots: $($NDKRoots.Count) $NDKRoots"
    Write-Output "NDK Versions: $($NDKVersions.Count) $NDKVersions"
}
