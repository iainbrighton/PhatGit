## PhatGit
A PowerShell module that wraps Git functionality so that it plays nicely with the PowerShell ISE.

* Aliases Git in the PowerShell ISE with a new Invoke-PhatGit cmdlet.
* Captures and redirects interactive git.exe commands' standard and error output streams.
* Ensures any interactive Git commands do not hang the PowerShell ISE console.
* Works with <a href="https://github.com/dahlbyk/posh-git">posh-git</a>.

Requires Powershell 3.0.

If you find it useful, unearth any bugs or have any suggestions for improvements, feel free to add an <a href="https://github.com/iainbrighton/PhatGit/issues">issue</a> or place a comment at the project home page.

##### Screenshots
Native PowerShell ISE output:
![ScreenShot](./PhatGit-ISENative.png?raw=true)

PhatGit PowerShell ISE output:
![ScreenShot](./PhatGit-ISEModified.png?raw=true)

PhatGit interactive process timeout warning:
![ScreenShot](./PhatGit-Timeout.png?raw=true)

##### Installation

* Automatic:
 * Run 'Install_to_User_Modules.ps1'.
* Manual:
 * Ensure all the files are unblocked (properties of the file / General).
 * Create module directory "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\PhatGit".
 * Copy PhatGit.psm1 and PhstGit.psd1 files to $env:USERPROFILE\Documents\WindowsPowerShell\Modules\PhatGit.
 * Launch the PowerShell ISE.
 * Run 'Import-Module PhatGit'.
 * If you want it to be loaded automatically when ISE starts, add the line above to your ISE profile (see $profile).

#### Usage
Once loaded, it'll do it's "thing" with all git invocations.

##### Why?

Because I got fed up with the output provided by git.exe in the PowerShell ISE! By default, git.exe outputs some of its text via the error stream. In the PowerShell console this doesn't cause a problem, however in the PowerShell ISE the "error" is caught and displayed along with the default PowerShell error output.

Interactive Git commands would also hang the PowerShell ISE console. PhatGit will terminate these processes with an error message after a short timeout (3 seconds). Therefore, no more hung console when I forget to type a commit message :)

##### Implementation details
Written in PowerShell!