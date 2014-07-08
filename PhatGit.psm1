<#
.Synopsis
   Runs a Git command and redirects output to the PowerShell host.
.DESCRIPTION
   The standard Git.exe command sends output to the error stream which
   results in fubar'd ouput in the PowerShell ISE. This function runs
   the specified Git.exe command and rewrites output to the PowerShell
   host.

   This cmdlet only actions Git commands that are issued interactively.
   Therefore, existing tooling such as poshgit, will continue to function
   as expected.
#>
function Invoke-PhatGit
{
    [CmdletBinding()]
    [Alias("Git")]
    Param (
        [Parameter(ValueFromRemainingArguments=$true)] $parameters
    )

    Process {

        if (-not([string]::IsNullOrEmpty($MyInvocation.PSCommandPath)) -or
                -not($Host.Name.Contains('ISE'))) {
                    ## We're not running interactively or not in the ISE so launch native
                    ## 'git' so that any existing tooling behaves as expected, e.g. posh-git etc.
                    $commandParameters = $parameters -Join ' ';
                    Invoke-Expression "Git.exe $commandParameters";
        }
        else {

            ## Otherwise, redirect output streams so they can be echoed nicely
            Write-Verbose "Redirecting output streams.";

            ## Re-quote any parameters with spaces, e.g. git commit -m "commit message"
            for ($i = 0; $i -lt $parameters.Count; $i++) {
                if (-not([string]::IsNullOrEmpty($parameters[$i])) -and $parameters[$i].Contains(' ')) {
                    $parameters[$i] = "`"$($parameters[$i])`""; }
            }

            $processStartInfo = New-object System.Diagnostics.ProcessStartInfo;
            $processStartInfo.CreateNoWindow = $false;
            $processStartInfo.UseShellExecute = $false;
            $processStartInfo.FileName = 'git.exe';
            $processStartInfo.WorkingDirectory = (Get-Location).Path;
            $processStartInfo.Arguments = $parameters;
            $processStartInfo.RedirectStandardOutput = $true;
            $processStartInfo.RedirectStandardError = $true;

            $process = [System.Diagnostics.Process]::Start($processStartInfo);
            Write-Debug ("Started process '{0}'." -f $process.Id);

            ## Launch the process and wait for up to 3 seconds
            $exitedCleanly = $process.WaitForExit(3000);

            if (-not($exitedCleanly)) {
                Write-Warning ("Process 'git {0}' did not exit cleanly. Probably waiting for user input?" -f ($parameters -join ' '));
                Write-Warning ("Stopping process '{0}'." -f $process.Id);
                Stop-Process -Id $process.Id -Force;
            }
            else {

                ## Echo the redirected output streams.
                foreach ($standardOutput in $process.StandardOutput.ReadToEnd()) {
                    if (-not([string]::IsNullOrEmpty($standardOutput))) { Write-Host $standardOutput -NoNewline; }
                }

                foreach ($errorOutput in $process.StandardError.ReadToEnd()) {
                    $errorForegroundColor = $Host.PrivateData.ErrorForegroundColor | ConvertToConsoleColor;
                    if (-not([string]::IsNullOrEmpty($errorOutput))) { Write-Host $errorOutput -ForegroundColor $errorForegroundColor -NoNewline; }
                }
            }
        }
    }
}

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
function ConvertToConsoleColor {
    [CmdletBinding(DefaultParameterSetName='RGB')]
    [OutputType([System.String])]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0, ParameterSetName='RGB')]
        [ValidateNotNullOrEmpty()] [int] $R,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0, ParameterSetName='RGB')]
        [ValidateNotNullOrEmpty()] [int] $G,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0, ParameterSetName='RGB')]
        [ValidateNotNullOrEmpty()] [int] $B,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='Color')]
        [ValidateNotNull()] [System.Windows.Media.Color] $InputObject,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('Black','DarkBlue','DarkGreen','DarkCyan','DarkRed','DarkMagenta','DarkYellow','Gray','DarkGray','Blue','Green','Cyan','Red','Magenta','Yellow','White')]
        [string] $DefaultColor = 'Red'
    )

    Begin {
        Write-Debug ("Using parameter set '$($PSCmdlet.ParameterSetName)'.");
    }

    Process {

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
    }
}
