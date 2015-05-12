#requires -Module VirtualEngine.Build, VirtualEngine.Compression;
#requires -Version 3;

Properties {
    $currentDir = Resolve-Path -Path .;
    $basePath = $psake.build_script_dir;
    $buildDir = 'Build';
    $releaseDir = 'Release';
    $invocation = (Get-Variable MyInvocation -Scope 1).Value;
    $thumbprint = 'D10BB31E5CE3048A7D4DA0A4DD681F05A85504D3';
    $timeStampServer = 'http://timestamp.verisign.com/scripts/timestamp.dll';
    $company = 'Iain Brighton';
    $author = 'Iain Brighton';
    $githubTokenPath = '~\Github.apitoken';
    $githubOwner = 'iainbrighton';
    $chocolateyTokenPath = '~\Chocolatey.apitoken';
}

Task Default -Depends Build;
Task Build -Depends Clean, Setup, Test, Deploy;
Task Stage -Depends Build, Version, Sign, Zip;
Task Publish -Depends Stage, Release, Chocolatey;

Task Clean {
    ## Remove build directory
    $baseBuildPath = Join-Path -Path $psake.build_script_dir -ChildPath $buildDir;
    if (Test-Path -Path $baseBuildPath) {
        Write-Host (' Removing build base directory "{0}".' -f $baseBuildPath) -ForegroundColor Yellow;
        Remove-Item $baseBuildPath -Recurse -Force -ErrorAction Stop;
    }
}

Task Setup {
    # Properties are not available in the script scope.
    Set-Variable manifest -Value (Get-ModuleManifest) -Scope Script;
    Set-Variable buildPath -Value (Join-Path -Path $psake.build_script_dir -ChildPath "$buildDir\$($manifest.Name)") -Scope Script;
    Set-Variable releasePath -Value (Join-Path -Path $psake.build_script_dir -ChildPath $releaseDir) -Scope Script;
    Set-Variable version -Value (Get-GitVersionString) -Scope Script;

    Write-Host (' Building module "{0}".' -f $manifest.Name) -ForegroundColor Yellow;
    Write-Host (' Using Git version "{0}".' -f $version) -ForegroundColor Yellow;

    ## Create the build directory
    Write-Host (' Creating build directory "{0}".' -f $buildPath) -ForegroundColor Yellow;
    [Ref] $null = New-Item $buildPath -ItemType Directory -Force -ErrorAction Stop;
    
    ## Create the release directory
    if (!(Test-Path -Path $releasePath)) {
        Write-Host (' Creating release directory "{0}".' -f $releasePath) -ForegroundColor Yellow;
        [Ref] $null = New-Item $releasePath -ItemType Directory -Force -ErrorAction Stop;
    }  
}

Task Test {
    $testResultsPath = Join-Path $buildPath -ChildPath 'NUnit.xml';
    $testResults = Invoke-Pester -Path $basePath -OutputFile $testResultsPath -OutputFormat NUnitXml -PassThru -Strict;
    if ($testResults.FailedCount -gt 0) {
        Write-Error ('{0} unit tests failed.' -f $testResults.FailedCount);
    }
}

Task Deploy {
    ## Update license
    $licensePath = Join-Path -Path $buildPath -ChildPath LICENSE;
    Write-Host (' Creating license file "{0}".' -f $licensePath) -ForegroundColor Yellow;
    [Ref] $null = New-ModuleLicense -Path $licensePath -LicenseType MIT -FullName $company;
    ## Copy release files
    Write-Host (' Copying release files to build directory "{0}".' -f $buildPath) -ForegroundColor Yellow;
    $excludedFiles = @( '*.Tests.ps1','Build.PSake.ps1','.git*','*.png','Build','Release' );
    Get-ModuleFile -Exclude $excludedFiles | % {
        $destinationPath = '{0}{1}' -f $buildPath, $PSItem.FullName.Replace($basePath, '');
        [Ref] $null = New-Item -ItemType File -Path $destinationPath -Force;
        Copy-Item -Path $PSItem.FullName -Destination $destinationPath -Force;
    }   
}

Task Version {
    ## Version module manifest prior to build
    $manifestPath = Join-Path $buildPath -ChildPath "$($manifest.Name).psd1";
    Write-Host (' Versioning module manifest "{0}".' -f $manifestPath) -ForegroundColor Yellow;
    Set-ModuleManifestProperty -Path $manifestPath -Version $version -CompanyName $company -Author $author;
    ## Reload module manifest to ensure the version number is picked back up
    Set-Variable manifest -Value (Get-ModuleManifest -Path $manifestPath) -Scope Script -Force;
}

Task Sign {
    Get-ChildItem -Path $buildPath -Include *.ps* -Recurse -File | % {
        Write-Host (' Signing file "{0}":' -f $PSItem.FullName) -ForegroundColor Yellow -NoNewline;
        $signResult = Set-ScriptSignature -Path $PSItem.FullName -Thumbprint $thumbprint -TimeStampServer $timeStampServer -ErrorAction Stop;
        Write-Host (' {0}.' -f $signResult.Status) -ForegroundColor Green;
    }
}

Task Zip {
    ## Creates the release files in the $releaseDir
    $zipReleaseName = '{0}-v{1}.zip' -f $manifest.Name, $version;
    $zipPath = Join-Path -Path $releasePath -ChildPath $zipReleaseName;
    Write-Host (' Creating zip file "{0}".' -f $zipPath) -ForegroundColor Yellow;
    ## Zip the parent directory
    $zipSourcePath = Split-Path -Path $buildPath -Parent;
    $zipFile = New-ZipArchive -Path $zipSourcePath -DestinationPath $zipPath;
    Write-Host (' Zip file "{0}" created.' -f $zipFile.Fullname) -ForegroundColor Yellow;
}

Task Release {
    ## Create a Github release
    $githubApiKey = (New-Object System.Management.Automation.PSCredential 'OAUTH', (Get-Content -Path $githubTokenPath | ConvertTo-SecureString)).GetNetworkCredential().Password;
    Write-Host (' Creating new Github "{0}" release in repository "{1}/{2}".' -f $version, $githubOwner, $manifest.Name) -ForegroundColor Yellow;
    $release = New-GitHubRelease -Version $version -Repository $manifest.Name -Owner $githubOwner -ApiKey $githubApiKey;
    if ($release) {
        ## Creates the release files in the $releaseDir
        $zipReleaseName = '{0}-v{1}.zip' -f $manifest.Name, $version;
        $zipPath = Join-Path -Path $releasePath -ChildPath $zipReleaseName;
        Write-Host (' Uploading asset "{0}".' -f $zipPath) -ForegroundColor Yellow;
        $asset = Invoke-GitHubAssetUpload -Release $release -ApiKey $githubApiKey -Path $zipPath;
        Set-Variable -Name assetUri -Value $asset.Browser_Download_Url -Scope Script -Force;
    }
}

Task Chocolatey {
    Set-Variable chocolateyBuildPath -Value (Join-Path -Path $psake.build_script_dir -ChildPath "$buildDir\Chocolatey") -Scope Script;
    ## Create the Chocolatey folder
    Write-Host (' Creating Chocolatey directory "{0}".' -f $chocolateyBuildPath) -ForegroundColor Yellow;
    [Ref] $null = New-Item $chocolateyBuildPath -ItemType Directory -Force -ErrorAction Stop;
    $chocolateyToolsPath = New-Item "$chocolateyBuildPath\tools" -ItemType Directory -Force -ErrorAction Stop;

    ## Create the Chocolatey package
    $nuspecFilename = '{0}.nuspec' -f $manifest.Name;
    $nuspecPath = Join-Path -Path $chocolateyBuildPath -ChildPath $nuspecFilename;
    Write-Host (' Creating Nuget specification "{0}".' -f $nuspecPath) -ForegroundColor Yellow;
    (New-NuGetNuspec -InputObject $manifest).Save($nuspecPath);
    
    Write-Host ' Creating Chocolatey install files.' -ForegroundColor Yellow;
    New-ChocolateyInstallZipModule -Path $chocolateyToolsPath.FullName -PackageName $manifest.Name -Uri $assetUri;
    Write-Host (' Creating Nuget package from "{0}".' -f $nuspecPath) -ForegroundColor Yellow;
    $nugetOutput = Invoke-NuGetPack -Path $nuspecPath -DestinationPath $releasePath;
    if ($nugetOutput) {
        $nugetPackagePath = Join-Path -Path $releasePath -ChildPath ('{0}.{1}.nupkg' -f $manifest.Name.ToLower(), $version);
        Write-Host (' Chocolatey package "{0}" created.' -f $nugetPackagePath) -ForegroundColor Yellow;
        $chocolateyApiKey = (New-Object System.Management.Automation.PSCredential 'OAUTH', (Get-Content -Path $chocolateyTokenPath | ConvertTo-SecureString)).GetNetworkCredential().Password;
        Write-Host (' Pushing Chocolatey package "{0}".' -f $nugetPackagePath) -ForegroundColor Yellow;
    }
}
