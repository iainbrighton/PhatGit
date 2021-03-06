@{
    RootModule = 'PhatGit.psm1';
    ModuleVersion = '1.2.0.0';
    GUID = '4dc26e6d-3273-43a1-9942-347fe19fd276';
    Author = 'Iain Brighton';
    CompanyName = 'Iain Brighton';
    Copyright = '(c) 2015 Iain Brighton. All rights reserved.';
    Description = 'This Powershell module wraps the native Git output streams so that they play nicely in an interactive PowerShell ISE session.'
    PowerShellHostName = 'Windows PowerShell ISE Host';
    PowerShellHostVersion = '3.0';
    FunctionsToExport = 'Invoke-PhatGit';
    AliasesToExport = 'Git';
    FileList = @('PhatGit.psm1','PhatGit.ps1','Resources.psd1');
    PrivateData = @{
        PSData = @{
            Tags = @('VirtualEngine','Powershell','ISE','Git');
            LicenseUri = 'https://raw.githubusercontent.com/iainbrighton/PhatGit/master/LICENSE';
            ProjectUri = 'https://github.com/iainbrighton/PhatGit';
            IconUri = 'https://raw.githubusercontent.com/iainbrighton/PhatGit/b0d3234d050d9be087a088afd95a15c744d76cea/PhatGit.png';
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
