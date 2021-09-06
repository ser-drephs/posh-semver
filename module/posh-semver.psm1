$functions = @(Get-ChildItem (Join-Path $PSScriptRoot "functions") -Recurse -Filter "*.ps1" -ErrorAction SilentlyContinue)

foreach ($function in $functions) {
    try{
        Write-Verbose "Importing $($function.FullName)"
        . $function.FullName
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Export-ModuleMember -Function $export