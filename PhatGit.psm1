## Import PhatGit.ps1
$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path;
. (Join-Path -Path $moduleRoot -ChildPath 'PhatGit.ps1');

## Set default global known commands. These can be overridden in a user's profile as required.
## NOTE: It's important to specify matching command parameters BEFORE missing parameters!
$knownGitCommands = @(
    @{ Command = 'commit'; Parameter = '--interactive'; Exists = $true; MessageId = 'InteractiveCommitMessageWarning'; }
    @{ Command = 'commit'; Parameter = '-m'; Exists = $false; MessageId = 'MissingCommitMessageWarning'; }
)
$ignoredGitCommands = @(
    @{ Command = 'push'; }
    @{ Command = 'pull'; }
    @{ Command = 'clone'; }
)
## Set the variables in the parent scope.
Set-Variable -Name PhatGitKnownCommands -Value $knownGitCommands -Scope 1 -Visibility Public;
Set-Variable -Name PhatGitIgnoredCommands -Value $ignoredGitCommands -Scope 1 -Visibility Public;

New-Alias -Name Git -Value Invoke-PhatGit;
Export-ModuleMember -Function Invoke-PhatGit -Alias Git;
