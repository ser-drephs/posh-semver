$DEFAULT_CONFIGURATION = [PSCustomObject]@{
    conventional       = $true
    usetags            = $false
    types              = @(
        [PSCustomObject]@{ name = "feat"; semantic = "minor" },
        [PSCustomObject]@{ name = "fix"; semantic = "patch" },
        [PSCustomObject]@{ name = "docs"; semantic = "none" },
        [PSCustomObject]@{ name = "style"; semantic = "none" },
        [PSCustomObject]@{ name = "refactor"; semantic = "none" },
        [PSCustomObject]@{ name = "perf"; semantic = "none" },
        [PSCustomObject]@{ name = "test"; semantic = "none" },
        [PSCustomObject]@{ name = "revert"; semantic = "revert" },
        [PSCustomObject]@{ name = "build"; semantic = "none" },
        [PSCustomObject]@{ name = "chore"; semantic = "none" },
        [PSCustomObject]@{ name = "ci"; semantic = "none" }
    )
    url                = [PSCustomObject]@{
        commit  = "{remote}/commit/{hash}"
        compare = "{remote}/branchCompare?baseVersion=GC{from}&targetVersion=GC{to}"
    }
    headings           = [PSCustomObject]@{
        major  = "BREAKING CHANGES"
        minor  = "Features"
        patch  = "Bug Fixes"
        none   = "Other"
        revert = "Reverts"
    }
    dateformat         = "yyyy-MM-dd"
    changelog          = "CHANGELOG.md"
    breakingchangebody = $true
}

function Read-Configuration {
    [CmdletBinding()]
    param ()

    function Initialize {
        [CmdletBinding()] param([Parameter(Position = 0)]$_configFile)
        Write-Debug "Initializing configuration"
        $DEFAULT_CONFIGURATION | ConvertTo-Json -Depth 3 | Out-File $_configFile
        return $DEFAULT_CONFIGURATION
    }
    $_configPath = Join-Path (Get-Location) ".semver"
    $_configFile = Join-Path $_configPath "settings.json"
    $_configPathExists = Test-Path $_configPath
    $_configFileExists = Test-Path $_configFile
    $_configExists = $_configPathExists -and $_configFileExists
    Write-Debug ("Configuration exists: {0}" -f $_configExists)
    if (-not $_configExists) {
        New-Item $_configPath -ItemType Directory -ErrorAction SilentlyContinue
        return Initialize $_configFile
    }
    Write-Debug "Read configuration"
    $_rawcontent = Get-Content $_configFile -Raw -ErrorAction SilentlyContinue
    if (-not $_rawcontent) { return Initialize $_configFile }
    return ConvertFrom-Json $_rawcontent -Depth 3 -ErrorAction SilentlyContinue
}

function Get-Commits {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)][switch]$usetags,
        [Parameter(Position = 1)][Object[]]$Types
    )
    function EscapeRichText($_text) {
        if ($_text) {
            $_jsontext = ConvertTo-Json $_text -EscapeHandling EscapeNonAscii
            $_text = $_jsontext.SubString(1, $_jsontext.length - 2)
        }
        return $_text
    }
    function FixRawCommitsArray($_rawcommits) {
        return ($_rawcommits -join "`r`n").Split("|=|")
    }
    function GetLastChangelogCommitTimestamp($_changelogpath) {
        if (Test-Path $_changelogpath) {
            $_lastcommitdate = & git log -1 --format=%cI (Get-Item $_changelogpath).FullName
            $_result = if ($LASTEXITCODE -ne 0) { $_lastcommitdate; } else { $null; }
        }
        return $_result
    }
    function SplitRawCommit($_rawcommit) {
        return $_rawcommit.Trim().Split("{{{")
    }
    function GetCommitType($_rawtype, $Types) {
        return $Types | Where-Object { $_rawtype -like ("{0}*" -f $_.name) }
    }
    function IsBreakingChange($_commit) {
        return (($_commit.subject -like "*!:*") -or ($_commit.body -like "*BREAKING CHANGE*"))
    }
    function GetScope($_rawtype) {
        $_scope = $_rawtype | Select-String "\((.*)\)"
        $_result = if ($_scope.Matches.Success) { $_scope.Matches.Groups[1].Value; } else { ""; }
        return $_result
    }
    function AdditionalCommitInfo($_commit, $Types) {
        try {
            # todo tests
            $_rawtype, $_subject = $_commit.subject.Split(":").Trim()
            $_subject = $_subject -join " "
            $_commit.semantic = (GetCommitType $_rawtype $Types).semantic
            $_commit.breaking = (IsBreakingChange $_commit)
            $_commit.scope = (GetScope $_rawtype)
            if ($_commit.semantic -ne "revert" -and -not $_commit.breaking) {
                $_commit.subject = if ($_commit.scope) { "({0}) {1}" -f $_commit.scope, $_subject; } else { $_subject; }
            }
        }
        catch {
            Write-Error $_.Exception
        }
        return $_commit
    }
    function RawCommitToObject {
        [CmdletBinding()]
        param (
            [Parameter(Position = 0)][string[]]$_rawcommits,
            [Parameter(Position = 1)][Object[]]$Types
        )
        # todo tests
        $_commits = @()
        $_rawcommits = FixRawCommitsArray $_rawcommits
        Write-Debug "Fixed commits array. Transforming commits to object..."
        foreach ($_rawcommit in $_rawcommits) {
            try {
                $_details, $_subject, $_body = SplitRawCommit $_rawcommit
                $_commitdetails = ConvertFrom-Json $_details
                if ($_commitdetails) {
                    $_commitdetails.subject = EscapeRichText $_subject
                    $_commitdetails.body = EscapeRichText $_body
                    Write-Verbose ("Subject and Body escaped for commit {0}." -f $_commitdetails.abbrevhash)
                    $_commits += AdditionalCommitInfo $_commitdetails $Types
                    Write-Verbose ("Added additional information to commit {0}." -f $_commitdetails.abbrevhash)
                }
            }
            catch {
                Write-Error $_.Exception
            }
        }
        Write-Debug ("Created {0} commit objects from {1} raw commits." -f $_commits.Length, $_rawcommits.Length)
        return $_commits
    }

    $_prettyformat = "{'abbrevhash':'%h','hash':'%H','subject':'','breaking':'','semantic':'','body':'','scope':''}{{{%s{{{%b|=|"

    if ($usetags) {
        $_lasttagref = (& git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname')[-1]
        $_lasttag = ($_lasttagref -split "refs/tags/")[-1]
        $_rawcommits = & git --no-pager log --no-merges --pretty="$_prettyformat" "$_lasttag..head"
        return RawCommitToObject $_rawcommits $Types
    }
    else {
        $_changelogpath = Join-Path (Get-Location) "changelog.md"
        $_lastcommitdate = GetLastChangelogCommitTimestamp $_changelogpath
        if ($_lastcommitdate) {
            $_since = "--since=`"{0}`"" -f (Get-Date $_lastcommitdate).ToString("yyyy-MM-dd HH:mm:ss")
            $_rawcommits = & git --no-pager log --no-merges --pretty="$_prettyformat" $_since
            return RawCommitToObject $_rawcommits $Types
        }
        else {
            $_rawcommits = & git --no-pager log --no-merges --pretty="$_prettyformat"
            return RawCommitToObject $_rawcommits $Types
        }
    }
}

function Test-Repository {
    [CmdletBinding()]
    param ()
    $_path = Get-Location
    Write-Debug ("Test directory '{0}' is repository." -f $_path)
    if ($_path -and (Test-Path $_path)) {
        Write-Verbose ("Directory '{0}' exists." -f $_path)
        $_repository = Join-Path $_path ".git"
        if ((Test-Path $_repository)) {
            $_HEAD = Join-Path $_repository "HEAD"
            if (Test-Path $_HEAD) {
                Write-Debug ("Directory '{0}' is a repository." -f $_path)
                return $true
            }
        }
    }
    return $false
}

function Assert-Repository {
    [CmdletBinding()]
    param ()
    if (-not (Test-Repository)) { throw ("Directory '{0}' is not a git repository" -f (Get-Location)) }
}