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
    [CmdletBinding(PositionalBinding = $false)]
    param (
        ## Process timeout in milliseconds
        [Parameter()] [ValidateNotNull()] [System.Int32] $Timeout = 5000,
        [Parameter(ValueFromRemainingArguments = $true)] $parameters
    )
    begin {
        $originalCommandParameterString = $parameters -Join ' ';
    }
    process {
        if (-not ([string]::IsNullOrEmpty($MyInvocation.PSCommandPath)) -or -not ($Host.Name.Contains('ISE'))) {
            ## We're not running interactively or not in the ISE so launch native
            ## 'git' so that any existing tooling behaves as expected, e.g. posh-git etc.
            return Invoke-Expression -Command ('Git.exe {0}' -f $originalCommandParameterString);
        }
        elseif (TestPhatGitCommand -PhatGitCommands $PhatGitKnownCommands -Parameters $parameters) {
            ## We have a known problematic command.
            $gitKnownCommand = GetPhatGitCommand -PhatGitCommands $PhatGitKnownCommands -Parameters $parameters;
            if ($gitKnownCommand.Exists -eq $true) {
                Write-Warning -Message ($localizedData.KnownGitCommandWithParameterWarning -f $gitKnownCommand.Command, $gitKnownCommand.Parameter);
            }
            else {
                Write-Warning -Message ($localizedData.KnownGitCommandWarning -f $gitKnownCommand.Command);
            }
            if ($gitKnownCommand.MessageId) {
                Write-Warning -Message $localizedData.($gitKnownCommand.MessageId);
            }
            return;
        }
        
        ## Determine whether this is an ignored command before escaping all the parameters!
        $isIgnoredCommand = TestPhatGitCommand -PhatGitCommands $PhatGitIgnoredCommands -Parameters $parameters;

        ## Otherwise we're all good! Redirect output streams so they can be echoed nicely
        Write-Verbose $localizedData.RedirectingOutputStreams;
        ## Re-quote any parameters with spaces, e.g. git commit -m "commit message"
        for ($i = 0; $i -lt $parameters.Count; $i++) {
            ## Do not check integers, for example when running 'git log -n 2' instead of 'git log -n2'
            if ($parameters[$i] -is [System.String] -and $parameters[$i].Contains(' ')) {
                $parameters[$i] = '"{0}"' -f $parameters[$i];
            }
        } #end for
        $process = StartGitProcess -Parameters $parameters;
        Write-Debug ($localizedData.StartedProcess -f $process.Id);
        
        if ($isIgnoredCommand -or $Timeout -eq 0) {
            Write-Warning ($localizedData.DisablingProcessTimeoutWarning -f $parameters[0]);
            $process.WaitForExit();
        }
        else {
            ## Launch the process and wait for timeout
            $exitedCleanly = $process.WaitForExit($Timeout);
            if (-not $exitedCleanly) {
                Write-Warning ($localizedData.ProcessNotExitedCleanly -f $originalCommandParameterString, ($Timeout / 1000));
                Write-Warning ($localizedData.StoppingProcess -f $process.Id);
                Stop-Process -Id $process.Id -Force;
            }
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
    } # end process
} # end function Invoke-PhatGit

#region Private Functions

function StartGitProcess {
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param (
        [Parameter()] [AllowNull()] $Parameters
    )
    process {
        $processStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo';
        $processStartInfo.CreateNoWindow = $false;
        $processStartInfo.UseShellExecute = $false;
        $processStartInfo.FileName = 'git.exe';
        $processStartInfo.WorkingDirectory = (Get-Location -PSProvider FileSystem).Path;
        $processStartInfo.Arguments = $Parameters;
        $processStartInfo.RedirectStandardOutput = $true;
        $processStartInfo.RedirectStandardError = $true;
        return [System.Diagnostics.Process]::Start($processStartInfo);
    } #end process
} #end function StartGitProcess

function TestPhatGitCommand {
    <#
    .SYNOPSIS
        Tests whether the specified Git command matches the supplied PhatGitCommand rules.
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [System.Array] $PhatGitCommands,
        [Parameter(ValueFromRemainingArguments = $true)] [AllowNull()] $Parameters
    )
    process {
        if (GetPhatGitCommand -PhatGitCommands $PhatGitCommands -Parameters $Parameters) {
            return $true;
        }
        return $false;
    } #end process
} #end function TestPhatGitCommand

function GetPhatGitCommand {
    <#
    .SYNOPSIS
        Returns a Git command hashtable that matches the supplied PhatGitCommand rules.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [System.Array] $PhatGitCommands,
        [Parameter(ValueFromRemainingArguments = $true)] [AllowNull()] $Parameters
    )
    process {
        if ($Parameters -is [System.String]) {
            ## Coerce a single string into an array
            $Parameters = @($Parameters);
        }
        foreach ($gitCommand in $PhatGitCommands) {
            Write-Debug -Message ('Enumerating PhatGit command ''{0}'' with parameter ''{1}'' exists ''{2}''.' -f $gitCommand.Command, $gitCommand.Parameter, $gitCommand.Exists);
            if ($Parameters -and $gitCommand.Command -eq $Parameters[0]) {
                if ([System.String]::IsNullOrEmpty($gitCommand.Parameter)) {
                    ## No parameter specifed, but we have a matching command.
                    return $gitCommand;
                }
                elseif ($gitCommand.Exists -eq $true -and $parameters -contains $gitCommand.Parameter) {
                    ## Parameter specifed exists
                    return $gitCommand;
                }
                elseif ($gitCommand.Exists -eq $false -and $parameters -notcontains $gitCommand.Parameter) {
                    ## Parameter missing as specified
                    return $gitCommand;
                }
            } #end if Command match
            else {
                Write-Debug '!!';
            }
        } #end foreach Command
    } #end process
} #end function GetPhatGitCommand

#endregion Private Functions
