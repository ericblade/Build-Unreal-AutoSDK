function Get-VS-Version-By-Tool-Version {
    param(
        [Parameter(Mandatory)]
        [string]
        $ToolVersion
    )

    Write-Host "ToolVersion: $ToolVersion"
    switch -regex ($ToolVersion) {
        # https://gist.github.com/RDCH106/40fe61f447df58c1b9c83a1781374bcd
        "14.1[0-9]" {
            "VS2017"
        }
        "14.2[0-9]" {
            "VS2019"
        }
        "14.3[0-9]" {
            "VS2022"
        }
        "14.4[0-9]" {
            "VS2022" # https://devblogs.microsoft.com/cppblog/msvc-toolset-minor-version-number-14-40-in-vs-2022-v17-10/
        }
        default {
            throw "Unknown VC tool version, please update Get-VS-Version-By-Tool-Version.ps1"
        }
    }
}
