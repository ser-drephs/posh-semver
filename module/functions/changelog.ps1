function Build-Changelog {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Version
    )

    function FormatLinkHeading {
        [CmdletBinding()]
        param (
            [Parameter(Position = 0)][string]$_config,
            [Parameter(Position = 1)][string]$_version,
            [Parameter(Position = 2)][string]$_remoteurl,
            [Parameter(Position = 3)][string]$_fromcommit,
            [Parameter(Position = 4)][string]$_tocommit
        )
        $_compareurl = ((($_config.url.compare -replace "{remote}", $_remoteurl) -replace "{from}", $_fromcommit) -replace "{to}", $_tocommit)
        return ("## [v{0}]({1}) ({2})" -f $_version, $_compareurl, (Get-Date -Format $_config.dateformat))
    }

    function FormatHeading {
        [CmdletBinding()]
        param (
            [Parameter(Position = 0)][string]$_version,
            [Parameter(Position = 1)][string]$_date
        )
        return ("## v{0} ({1})" -f $_version, $_date)
    }

    function FormatCommitUrl {
        [CmdletBinding()]
        param (
            [Parameter(Position = 0)][string]$_urlcommit,
            [Parameter(Position = 1)][string]$_remoteurl,
            [Parameter(Position = 2)][string]$_hash
        )
        return (($_urlcommit -replace "{remote}", $_remoteurl) -replace "{hash}", $_hash)
    }

    function FormatCommitBullet {
        [CmdletBinding()]
        param (
            [Parameter(Position = 0)][Object]$_commit,
            [Parameter(Position = 1)][string]$_commitUrl,
            [Parameter(Position = 2)][switch]$outBody
        )
        $_result = @(("* {0} ([{1}]({2}))" -f $_commit.subject, $_commit.abbrevhash, $_commitUrl))
        if ($outBody) {
            # todo configuration object global
            $_body = $_commit.body.Split("\r\n")
            foreach ($_line in $_body) {
                $_result += "  > $_line"
            }
        }
        return $_result
    }

    function AddSection {
        [CmdletBinding()]
        param (
            [Parameter(Position = 0)][string]$_heading,
            [Parameter(Position = 1)][string]$_remoteUrl,
            [Parameter(Position = 2)][string]$_urlcommit,
            [Parameter(Position = 3)][Object[]]$_commits,
            [Parameter(Position = 4)][switch]$outBody
        )
        $_section = @()
        $_section += ("### {0}" -f $_heading)
        foreach ($_commit in $_commits) {
            try {
                $_section += FormatCommitBullet $_commit (FormatCommitUrl $_urlcommit $_remoteUrl $_commit.hash) $outBody
            }
            catch {
                Write-Error $_.Exception
            }
        }
        return $_section
    }

    # todo try catch everywhere
    Assert-Repository
    $_path = Get-Location
    $_config = Read-Configuration
    $_changelogfile = Join-Path $_path $_config.changelog
    $_remoteUrl = & git remote get-url --push origin
    if ($_remoteUrl.EndsWith(".git")) { $_remoteUrl = $_remoteUrl.Substring(0, $_remoteUrl.Length - ".git".Length ) }
    $_commits = Get-Commits $_config.usetags $_config.types

    $_features = $_commits | Where-Object { $_.semantic -eq "minor" }
    Write-Debug ("Found '{0}' feature commits." -f $_features.Length)

    $_fix = $_commits | Where-Object { $_.semantic -eq "patch" }
    Write-Debug ("Found '{0}' patch commits." -f $_fix.Length)

    $_reverts = $_commits | Where-Object { $_.semantic -eq "revert" }
    Write-Debug ("Found '{0}' revert commits." -f $_reverts.Length)

    $_breaking = $_commits | Where-Object { ($_.breaking -eq $true) -or ($_.semantic -eq "major") }
    Write-Debug ("Found '{0}' breaking commits." -f $_breaking.Length)

    $_firstcommit = $_commits[0].hash
    $_fromcommit = & git log --pretty=%P -n 1 "`"$_firstcommit`""
    $_tocommit = $_commits[-1].hash
    $_heading = if ($_parentcommit) { FormatLinkHeading $_config $Version $_remoteUrl $_fromcommit $_tocommit; } else { FormatHeading $Version (Get-Date -Format $_config.dateformat); }

    Write-Debug "Build changelog"
    $_changelog = @()
    $_changelog += $_heading

    if ($_features.length -gt 0) {
        Write-Debug "Add features section"
        $_changelog += AddSection $_config.headings.minor $_remoteUrl $_config.url.commit $_features
    }

    if ($_fix.length -gt 0) {
        Write-Debug "Add bug fix section"
        $_changelog += AddSection $_config.headings.patch $_remoteUrl $_config.url.commit $_fix
    }

    if ($_reverts.length -gt 0) {
        Write-Debug "Add reverts section"
        $_changelog += AddSection $_config.headings.revert $_remoteUrl $_config.url.commit $_reverts
    }

    if ($_breaking.length -gt 0) {
        Write-Debug "Add breaking changes section"
        $_changelog += AddSection $_config.headings.major $_remoteUrl $_config.url.commit $_breaking $_config.breakingchangebody
    }

    if (Test-Path $_changelogfile) {
        Write-Debug "Append old changelog"
        $_oldchangelog = Get-Content $_changelogfile
        $_changelog += $_oldchangelog
    }

    Write-Debug ("Write '{0}' lines to changelog '{1}'." -f $_changelog.Length, $_changelogfile)
    Set-Content -Path $_changelogfile -Value $_changelog -Encoding utf8
    # todo configuration for json object instead of md
    return $_changelogfile
}

try {
    Push-Location "D:\source\semantic-release"
    Build-Changelog
}
catch {
    Write-Host $_.Exception
}
finally {
    Pop-Location
}