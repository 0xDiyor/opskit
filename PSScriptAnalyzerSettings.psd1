@{
    Severity     = @('Error', 'Warning')
    # Write-Host is the intended output mechanism for this menu-driven TUI:
    # colored, host-only output that never pollutes the pipeline.
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
