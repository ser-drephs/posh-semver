BeforeAll {
    . "$PSScriptRoot/setup.ps1"
}
Describe 'function tests' {
    BeforeAll {
    }
    AfterAll {
    }
    Context "test-repsitory" {
        Context "not inside a repository" {
            It "should be false because .git directory does not exist" {
                Mock Get-Location { return Join-Path $TestDrive "no-git-directory" }
                Test-Repository | Should -Be $false
            }
            It "should be false because .git is not a directory" {
                $folder = Join-Path $TestDrive "git-not-directory"
                Mock Get-Location { return $folder }
                New-Item $folder -ItemType Directory
                $git = Join-Path $folder ".git"
                New-Item $git
                Test-Repository | Should -Be $false -ErrorAction Continue
            }
            It "should be false because .git does not contain HEAD file" {
                $folder = Join-Path $TestDrive "git-not-contains-head-directory"
                Mock Get-Location { return $folder }
                $git = Join-Path $folder ".git"
                New-Item $git -ItemType Directory
                Test-Repository | Should -Be $false -ErrorAction Continue
                Pop-Location
            }
        }
        Context "inside a repository" {
            It "should be true because path points to a git repository" {
                $folder = Join-Path $TestDrive "git-directory"
                Mock Get-Location { return $folder }
                $git = Join-Path $folder ".git"
                $head = Join-Path $git "HEAD"
                New-Item $git -ItemType Directory
                New-Item $head
                Test-Repository | Should -Be $true
            }
        }
    }
    Context "assert-repository" {
        It "should throw exception if not inside repository" {
            Mock Get-Location { return Join-Path $TestDrive "no-git-directory" }
            { Assert-Repository } | Should -Throw "Directory '*' is not a git repository"
        }
        It "should not throw exception if inside repository" {
            $folder = Join-Path $TestDrive "git-directory"
            Mock Get-Location { return $folder }
            $git = Join-Path $folder ".git"
            $head = Join-Path $git "HEAD"
            New-Item $git -ItemType Directory
            New-Item $head
            { Assert-Repository } | Should -Not -Throw
        }
    }
    Context "read-configuration" {
        It "should create configuration if it does not exist" {
            $_fut = Join-Path $TestDrive "new-config"
            Mock Get-Location { return $_fut }
            New-Item $_fut -ItemType Directory
            Read-Configuration
            Test-Path (Join-Path $_fut ".semver" "settings.json")
        }
        It "should create initial configuration" {
            $_fut = Join-Path $TestDrive "inital-config"
            Mock Get-Location { return $_fut }
            New-Item $_fut -ItemType Directory
            Read-Configuration
            $_configFile = Get-Item (Join-Path $_fut ".semver" "settings.json")
            $_config = ConvertFrom-Json (Get-Content $_configFile -Raw -ErrorAction SilentlyContinue) -Depth 3 -ErrorAction SilentlyContinue
            $_config.usetags | Should -Be $false
        }
        It "should create configuration if it does not exist but folder exists" {
            $_fut = Join-Path $TestDrive "new-config-only" ".semver"
            Mock Get-Location { return $_fut }
            New-Item $_fut -ItemType Directory
            Read-Configuration
            Test-Path (Join-Path $_fut "settings.json")
        }
        It "should create configuration if it can not be read" {
            $_fut = Join-Path $TestDrive "malformed-config"
            Mock Get-Location { return $_fut }
            $_configFut = Join-Path $_fut ".semver"
            New-Item $_configFut -ItemType Directory
            $_corruptconfigfile = Join-Path $_configFut "settings.json"
            New-Item $_corruptconfigfile
            Read-Configuration
            $_configFile = Get-Item $_corruptconfigfile
            $_config = ConvertFrom-Json (Get-Content $_configFile -Raw -ErrorAction SilentlyContinue) -Depth 3 -ErrorAction SilentlyContinue
            $_config.usetags | Should -Be $false
        }
        Context "initial configuration" {
            BeforeAll {
                $_fut = Join-Path $TestDrive "read-config"
                Mock Get-Location { return $_fut }
                $_config = Read-Configuration
            }
            It "conventional true" {
                $_config.conventional | Should -Be $true
            }
            It "usetags false" {
                $_config.usetags | Should -Be $false
            }
            It "11 types defined" {
                $_config.types.length | Should -Be 11
            }
            It "1 minor type defined" {
                ($_config.types | Where-Object { "minor" -eq $_.semantic }).length | Should -Be 1 -Because "initially 1 minor type is defined"
            }
            It "1 patch type defined" {
                ($_config.types | Where-Object { "patch" -eq $_.semantic }).length | Should -Be 1 -Because "initially 1 patch type is defined"
            }
            It "9 none types defined" {
                ($_config.types | Where-Object { "none" -eq $_.semantic }).length | Should -Be 9 -Because "initially 9 none types are defined"
            }
            It "0 major types defined" {
                ($_config.types | Where-Object { "major" -eq $_.semantic }).length | Should -Be 0 -Because "initially 0 major types are defined"
            }
            It "commit url format" {
                $_config.url.commit | Should -Be "{remote}/commit{hash}"
            }
            It "compare url format" {
                $_config.url.compare | Should -Be "{remote}/branchCompare?baseVersion=GC{firstcommit}&targetVersion=GC{lastcommit}"
            }
        }
    }
    Context "get-commits" {
        BeforeAll {
            $_repository = Join-Path $TestDrive "log-tests"
            New-Item $_repository -ItemType Directory
            Push-Location $_repository
            & git init
            New-Item "sample"
            & git add .
            & git commit -m "chore: sample"
            New-Item "other sample"
            & git add .
            & git commit -m "chore: other sample" -m "BREAKING 'CHANGE': Require Node.js >= 10.13"
            New-Item "other sample 2"
            & git add .
            & git commit -m "chore: complex sample (#123)" -m "* sample change" -m "* and another" -m "Why commit'n stuff?"
            $_commits = Get-Commits
        }
        AfterAll {
            Pop-Location
        }
        It "should return a commit object" {
            $_commits | Should -Not -Be $null
        }
        It "should have two elements" {
            $_commits.commits.length | Should -Be 3
        }
        It "should have a parsed commit" {
            $_commits.commits[2].abbrevhash | Should -Not -Be ""
        }
        It "should have subject" {
            $_commits.commits.subject | Should -Contain "`"chore: other sample`""
        }
        It "should have parsed simple body"{
            $_commits.commits[1].body | Should -Be "`"BREAKING 'CHANGE': Require Node.js >= 10.13`""
        }
        It "should have parsed complex subject"{
            $_commits.commits[0].subject | Should -Be "`"chore: complex sample (#123)`""
        }
        It "should have parsed complex body"{
            $_commits.commits[0].body | Should -Be "`"* sample change\r\n\r\n* and another\r\n\r\nWhy commit'n stuff?`""
        }
    }
    Context "get-comits semantic-release repo"{
        BeforeAll{
            Push-Location "../../semantic-release"
        }
        AfterAll{
            Pop-Location
        }
        It "test"{
            $_commits = Get-Commits
            $_commits.Length | Should -Be 14
        }
    }
    # todo umbau nach get-commits
    # Context "add-additionalcommitinfo" {
    #     BeforeAll {
    #         $_fut = Join-Path $TestDrive "read-config"
    #         Mock Get-Location { return $_fut }
    #         $_config = Read-Configuration
    #     }
    #     It "should set semantic types" {
    #         $_commits = @(
    #             [PSCustomObject]@{ subject = "feat: feature 1"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "fix: fix 1"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "fix: fix 2"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "chore: nothing 2"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "revert: chore: nothing 2"; body = ""; semantic = ""; breaking = "" }
    #         )
    #         $_result = Add-AdditionalCommitInfo -Commits $_commits -Types $_config.types
    #         $_result.length | Should -Be 5 -Because "commits count should not change"
    #         ($_result | Where-Object { $_.semantic -eq "minor" }).length | Should -Be 1 -Because "one minor commit was parsed"
    #         ($_result | Where-Object { $_.semantic -eq "patch" }).length | Should -Be 2 -Because "two patch commits were parsed"
    #         ($_result | Where-Object { $_.semantic -eq "revert" }).length | Should -Be 1 -Because "one revert commit was parsed"
    #         ($_result | Where-Object { $_.semantic -eq "none" }).length | Should -Be 1 -Because "one other commit was parsed"
    #         ($_result | Where-Object { $_.breaking -eq $true }).length | Should -Be 0 -Because "no commit was breaking"
    #     }
    #     It "should set semantic types with scope" {
    #         $_commits = @(
    #             [PSCustomObject]@{ subject = "feat(Sample): feature 1"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "fix(Sample): fix 1"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "fix(Sample): fix 2"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "chore(Sample): nothing 2"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "revert: chore(Sample): nothing 2"; body = ""; semantic = ""; breaking = "" }
    #         )
    #         $_result = Add-AdditionalCommitInfo -Commits $_commits -Types $_config.types
    #         $_result.length | Should -Be 5 -Because "commits count should not change"
    #         ($_result | Where-Object { $_.semantic -eq "minor" }).length | Should -Be 1 -Because "one minor commit was parsed"
    #         ($_result | Where-Object { $_.semantic -eq "patch" }).length | Should -Be 2 -Because "two patch commits were parsed"
    #         ($_result | Where-Object { $_.semantic -eq "revert" }).length | Should -Be 1 -Because "one revert commit was parsed"
    #         ($_result | Where-Object { $_.semantic -eq "none" }).length | Should -Be 1 -Because "one other commit was parsed"
    #         ($_result | Where-Object { $_.breaking -eq $true }).length | Should -Be 0 -Because "no commit was breaking"
    #     }
    #     It "should set breaking from subject" {
    #         $_commits = @(
    #             [PSCustomObject]@{ subject = "feat(Sample)!: feature 1"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "fix(Sample)!: fix 1"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "fix(Sample): fix 2"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "chore(Sample): nothing 2"; body = ""; semantic = ""; breaking = "" }
    #         )
    #         $_result = Add-AdditionalCommitInfo -Commits $_commits -Types $_config.types
    #         $_result.length | Should -Be 4 -Because "commits count should not change"
    #         ($_result | Where-Object { $_.semantic -eq "minor" }).length | Should -Be 1 -Because "one minor commit was parsed"
    #         ($_result | Where-Object { $_.semantic -eq "patch" }).length | Should -Be 2 -Because "two patch commits were parsed"
    #         ($_result | Where-Object { $_.semantic -eq "none" }).length | Should -Be 1 -Because "one other commit was parsed"
    #         ($_result | Where-Object { $_.breaking -eq $true }).length | Should -Be 2 -Because "two commits were breaking"
    #     }
    #     It "should set breaking from body" {
    #         $_commits = @(
    #             [PSCustomObject]@{ subject = "feat(Sample): feature 1"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "fix(Sample): fix 1"; body = ""; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "fix(Sample): fix 2"; body = "fixed something and broke things.`r`nBREAKING CHANGE: do stuff"; semantic = ""; breaking = "" }
    #             [PSCustomObject]@{ subject = "chore(Sample): nothing 2"; body = ""; semantic = ""; breaking = "" }
    #         )
    #         $_result = Add-AdditionalCommitInfo -Commits $_commits -Types $_config.types
    #         $_result.length | Should -Be 4 -Because "commits count should not change"
    #         ($_result | Where-Object { $_.semantic -eq "minor" }).length | Should -Be 1 -Because "one minor commit was parsed"
    #         ($_result | Where-Object { $_.semantic -eq "patch" }).length | Should -Be 2 -Because "two patch commits were parsed"
    #         ($_result | Where-Object { $_.semantic -eq "none" }).length | Should -Be 1 -Because "one other commit was parsed"
    #         ($_result | Where-Object { $_.breaking -eq $true }).length | Should -Be 1 -Because "one commit has breaking change body"
    #     }
    # }
}