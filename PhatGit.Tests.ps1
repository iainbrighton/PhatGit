$here = Split-Path -Parent $MyInvocation.MyCommand.Path;
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests.', '.');
. "$here\$sut";

Describe 'GetPhatGitCommand' {
    
    It 'should return $true when git command without a single parameter is found.' {
        $gitCommandName = 'test';
        $gitParameters = @($gitCommandName);
        $PhatGitIgnoredCommands = @(
            @{ Command = $gitCommandName; Parameter = ''; }
        );
        TestPhatGitCommand -PhatGitCommands $PhatGitIgnoredCommands -Parameters $gitParameters | Should Be $true;
    }

    It 'should return $false when git command without a single parameter is not found.' {
        $gitCommandName = 'test';
        $gitParameters = @($gitCommandName);
        $PhatGitIgnoredCommands = @( @{ Command = 'nonexistent'; Parameter = ''; } );
        TestPhatGitCommand -PhatGitCommands $PhatGitIgnoredCommands -Parameters $gitParameters | Should Be $false;
    }

    It 'should return $true when git command with a single parameter is found.' {
        $gitCommandName = 'test';
        $gitParameters = @($gitCommandName, 'testparameter');
        $PhatGitIgnoredCommands = @(
            @{ Command = $gitCommandName; Parameter = 'testparameter'; Exists = $true }
        );
        TestPhatGitCommand -PhatGitCommands $PhatGitIgnoredCommands -Parameters $gitParameters | Should Be $true;
    }

    It 'should return $false when git command with a single parameter is not found.' {
        $gitCommandName = 'test';
        $gitParameters = @($gitCommandName, 'testparameter');
        $PhatGitIgnoredCommands = @(
            @{ Command = $gitCommandName; Parameter = 'testparameter'; Exists = $false; }
        );
        TestPhatGitCommand -PhatGitCommands $PhatGitIgnoredCommands -Parameters $gitParameters | Should Be $false;
    }

    It 'should return $true when git command with a single parameter is found within multiple parameters.' {
        $gitCommandName = 'test';
        $gitParameters = @($gitCommandName, 'randomparameter1','testparameter','randomparameter2');
        $PhatGitIgnoredCommands = @(
            @{ Command = $gitCommandName; Parameter = 'testparameter'; Exists = $true }
        );
        TestPhatGitCommand -PhatGitCommands $PhatGitIgnoredCommands -Parameters $gitParameters | Should Be $true;
    }

    It 'should return $false when git command with a single parameter is not found within multiple parameters.' {
        $gitCommandName = 'test';
        $gitParameters = @($gitCommandName, 'randomparameter1','testparameter','randomparameter2');
        $PhatGitIgnoredCommands = @(
            @{ Command = $gitCommandName; Parameter = 'testparameter'; Exists = $false; }
        );
        TestPhatGitCommand -PhatGitCommands $PhatGitIgnoredCommands -Parameters $gitParameters | Should Be $false;
    }

} #end describe GetPhatGitCommand

## Cannot test Invoke-PhatGit as $MyInvocation.PSCommandPath is empty and Invoke-Expression is invoked immediately?
