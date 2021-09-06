$cs = @(
    [PSCustomObject]@{semantic = "revert"; breaking = $true },
    [PSCustomObject]@{semantic = "patch"; breaking = $true },
    [PSCustomObject]@{semantic = "patch"; breaking = $false },
    [PSCustomObject]@{semantic = "revert"; breaking = $false })

foreach ($c in $cs) {
    Write-Host ("revert: {0}, breaking {1}" -f $c.semantic, $c.breaking)
    if ($c.semantic -ne "revert" -and -not $c.breaking) { write-host "Not revert, not breaking" } else { Write-host "revert or breaking" }
}
