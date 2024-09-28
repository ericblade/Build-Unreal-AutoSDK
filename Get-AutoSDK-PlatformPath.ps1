function Get-AutoSDK-PlatformPath {
    param(
        [Parameter(Mandatory)]
        [string]
        $Root,

        [Parameter(Mandatory)]
        [string]
        $HostPlatform,

        [Parameter(Mandatory)]
        [string]
        $TargetPlatform
    )

    [IO.Path]::Combine($Root, "Host$HostPlatform", $TargetPlatform)
}