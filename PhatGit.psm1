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
        if (-not ([string]::IsNullOrEmpty($MyInvocation.PSCommandPath)) -or
            -not ($Host.Name.Contains('ISE'))) {
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
            $processStartInfo = New-object System.Diagnostics.ProcessStartInfo;
            $processStartInfo.CreateNoWindow = $false;
            $processStartInfo.UseShellExecute = $false;
            $processStartInfo.FileName = 'git.exe';
            $processStartInfo.WorkingDirectory = (Get-Location).Path;
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
            else {
                ## Echo the redirected output streams.
                foreach ($standardOutput in $process.StandardOutput.ReadToEnd()) {
                    if (-not([string]::IsNullOrEmpty($standardOutput))) { Write-Output $standardOutput.Trim(); }
                }
                foreach ($errorOutput in $process.StandardError.ReadToEnd()) {
                    $errorForegroundColor = $Host.PrivateData.ErrorForegroundColor | ConvertToConsoleColor;
                    if (-not([string]::IsNullOrEmpty($errorOutput))) { Write-Host $errorOutput -ForegroundColor $errorForegroundColor -NoNewline; }
                }
            }
        } # end else
    } # end process
} # end function Invoke-PhatGit

function ConvertToConsoleColor {
    <#
    .SYNOPSIS
        Converts RGB color to the PowerShell Write-Host equivalent.
    .DESCRIPTION
        This cmdlet converts the specified RGB color to an equivalent that can be used
        with the Write-Host cmdlet. As the Write-Host cmdlet only supports a finite
        number of colors. If no match is found, a default color string of 'Red' is returned.
    .NOTES
        This is an internal function not intended to be called from outside this
        module.
    #>
    [CmdletBinding(DefaultParameterSetName='RGB')]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0, ParameterSetName = 'RGB')]
        [ValidateNotNullOrEmpty()] [System.Int32] $R,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0, ParameterSetName = 'RGB')]
        [ValidateNotNullOrEmpty()] [System.Int32] $G,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0, ParameterSetName = 'RGB')]
        [ValidateNotNullOrEmpty()] [System.Int32] $B,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Color')]
        [ValidateNotNull()] [System.Windows.Media.Color] $InputObject,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Black','DarkBlue','DarkGreen','DarkCyan','DarkRed','DarkMagenta','DarkYellow','Gray','DarkGray','Blue','Green','Cyan','Red','Magenta','Yellow','White')]
        [System.String] $DefaultColor = 'Red'
    )
    begin {
        Write-Debug ($localizedData.UsingParameterSet -f $PSCmdlet.ParameterSetName);
    }
    process {
        foreach ($consoleColor in [enum]::GetValues([System.ConsoleColor])) {
            $color = [System.Drawing.Color]::$consoleColor;
            switch ($PSCmdlet.ParameterSetName) {
                {$_ -eq 'Color'} {
                    $R = $InputObject.R;
                    $G = $InputObject.G;
                    $B = $InputObject.B;
                }
            } # end switch
            ## Do we have a match (not checking the 'A' value)?
            if (($color.R -eq $R) -and
                    ($color.G -eq $G) -and
                        ($color.B -eq $B)) {
                return $color.Name;
            }
        } # end foreach
        ## Check for DarkYellow as this isn't a [System.ConsoleColor] enum?!
        if (($color.R -eq 128) -and
                ($color.G -eq 128) -and
                    ($color.B -eq 0)) {
            return "DarkYellow";
        }
        ## If we've got here we don't have a match so return the default.
        return $DefaultColor;
    } # end process
} # end function ConvertToConsoleColor

New-Alias -Name Git -Value Invoke-PhatGit;
Export-ModuleMember -Function Invoke-PhatGit -Alias Git;
