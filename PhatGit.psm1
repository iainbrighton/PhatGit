Import-LocalizedData -BindingVariable localizedData -FileName Resources.psd1;

function Invoke-PhatGit {
    <#
    .SYNOPSIS
       Runs a Git command and redirects output to the PowerShell host.
    .DESCRIPTION
       The standard Git.exe command sends output to the error stream which
       results in fubar'd ouput in the PowerShell ISE. This function runs
       the specified Git.exe command and rewrites the error output stream
       to the PowerShell host.

       This cmdlet only actions Git commands that are issued interactively.
       Therefore, existing tooling such as poshgit, will continue to function
       as expected.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromRemainingArguments = $true)] $parameters
    )
    process {
        if (-not ([string]::IsNullOrEmpty($MyInvocation.PSCommandPath)) -or -not ($Host.Name.Contains('ISE'))) {
                ## We're not running interactively or not in the ISE so launch native
                ## 'git' so that any existing tooling behaves as expected, e.g. posh-git etc.
                $commandParameters = $parameters -Join ' ';
                Invoke-Expression -Command ('Git.exe {0}' -f $commandParameters);
        }
        else {
            ## Otherwise, redirect output streams so they can be echoed nicely
            Write-Verbose $localizedData.RedirectingOutputStreams;
            ## Re-quote any parameters with spaces, e.g. git commit -m "commit message"
            for ($i = 0; $i -lt $parameters.Count; $i++) {
                ## Do not check integers, for example when running 'git log -n 2' instead of 'git log -n2'
                if (-not [System.String]::IsNullOrEmpty($parameters[$i]) -and $parameters[$i] -is [System.String]) {
                    $parameters[$i] = '"{0}"' -f $parameters[$i];
                }
            } #end for
            $processStartInfo = New-object -TypeName 'System.Diagnostics.ProcessStartInfo';
            $processStartInfo.CreateNoWindow = $false;
            $processStartInfo.UseShellExecute = $false;
            $processStartInfo.FileName = 'git.exe';
            $processStartInfo.WorkingDirectory = (Get-Location -PSProvider FileSystem).Path;
            $processStartInfo.Arguments = $parameters;
            $processStartInfo.RedirectStandardOutput = $true;
            $processStartInfo.RedirectStandardError = $true;
            $process = [System.Diagnostics.Process]::Start($processStartInfo);
            Write-Debug ($localizedData.StartedProcess -f $process.Id);
            ## Launch the process and wait for up to 3 seconds
            $exitedCleanly = $process.WaitForExit(3000);
            if (-not($exitedCleanly)) {
                Write-Warning ($localizedData.ProcessNotExitedCleanly -f ($parameters -join ' '));
                Write-Warning ($localizedData.StoppingProcess -f $process.Id);
                Stop-Process -Id $process.Id -Force;
            }
  
            ## Echo the redirected (or what we have if timed out) output stream.
            foreach ($standardOutput in $process.StandardOutput.ReadToEnd()) {
                if (-not [string]::IsNullOrEmpty($standardOutput)) {
                    Write-Output $standardOutput.Trim();
                }
            } #end foreach standardOutput
            
            ## Echo the redirected error stream
            foreach ($errorOutput in $process.StandardError.ReadToEnd()) {
                if (-not [string]::IsNullOrEmpty($errorOutput)) {
                    if ($process.ExitCode -eq 0) {
                        Write-Output $errorOutput.Trim();
                    }
                    else {
                        Write-Error -Message $errorOutput.Trim() -Category InvalidOperation;
                    }
                }
            } #end foreach errorOutput
        } # end else
    } # end process
} # end function Invoke-PhatGit

New-Alias -Name Git -Value Invoke-PhatGit;
Export-ModuleMember -Function Invoke-PhatGit -Alias Git;
