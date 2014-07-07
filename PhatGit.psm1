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

# SIG # Begin signature block
# MIIaogYJKoZIhvcNAQcCoIIakzCCGo8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUw8Wqxu21ZgLpQnTIcTC3lGV7
# hM2gghXYMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggaUMIIFfKADAgECAhAG8BXYFUYj6XmzRgEaZJSVMA0GCSqGSIb3DQEBBQUAMG8x
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBLTEwHhcNMTMwNDE3MDAwMDAwWhcNMTUwNzE2MTIwMDAwWjBg
# MQswCQYDVQQGEwJHQjEPMA0GA1UEBxMGT3hmb3JkMR8wHQYDVQQKExZWaXJ0dWFs
# IEVuZ2luZSBMaW1pdGVkMR8wHQYDVQQDExZWaXJ0dWFsIEVuZ2luZSBMaW1pdGVk
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1dxm3r1cUKp7rYZBDAeo
# Lm0iLIgYuzeg7tC2mt7kEJfvGiSVx4/d3pYw2/GpDB08JjsoAYIfhWOuGtUf0RRy
# 5QcyrfWDCmLfUApf83/GJZrATWs1OPzdYEsLzVrx7ZtvcCVvlEIyG4RJmhSG2mZS
# 6P0D68a2/U4QmcNEGpnbTyszHds8BnVL1D3oQP+rcXN2jDP83/rECmGgYGexvRkV
# K/+HHrporgkT4KRMbrWXMRPrLQazIFeg1mnm1UtjxTXN7IPaY97qwxhxPqwpL3DH
# PdF/6+rC1ZQZ27akf5qporAlsftUe3URHFmmJ8NrLivANrwco9BY3If4iAvz9ipl
# mQIDAQABo4IDOTCCAzUwHwYDVR0jBBgwFoAUe2jOKarAF75JeuHlP9an90WPNTIw
# HQYDVR0OBBYEFNQ3nxxDKFobighYZExYqzXq8SQTMA4GA1UdDwEB/wQEAwIHgDAT
# BgNVHSUEDDAKBggrBgEFBQcDAzBzBgNVHR8EbDBqMDOgMaAvhi1odHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vYXNzdXJlZC1jcy0yMDExYS5jcmwwM6AxoC+GLWh0dHA6
# Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9hc3N1cmVkLWNzLTIwMTFhLmNybDCCAcQGA1Ud
# IASCAbswggG3MIIBswYJYIZIAYb9bAMBMIIBpDA6BggrBgEFBQcCARYuaHR0cDov
# L3d3dy5kaWdpY2VydC5jb20vc3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsG
# AQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABD
# AGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABh
# AGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQBy
# AHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBn
# ACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABs
# AGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABp
# AG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBl
# AGYAZQByAGUAbgBjAGUALjCBggYIKwYBBQUHAQEEdjB0MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTAYIKwYBBQUHMAKGQGh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENvZGVTaWduaW5nQ0Et
# MS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQUFAAOCAQEAPsyUuxkYkEGE
# 1bl4g3Muy5QxQq8frp34BPf+Sm6E9J915eBizW72ofbm08O9NkQvszbT4GTZaO/o
# SExSDbLIxHI98zi7AavVPuRpmVnfoF55yVomh/BYAU8vu0M7FvUeIhSAUfz0Q8PK
# wT5U+SdNoE7+xgxd4zHjBA3kUo3TZ+R/+MDd2Hzv6vrgxUfGeQfBCwafdEjD4pHr
# 0kvXcPq6VnQpsv92P3wvgsCrsTKIgtaNIfkGe5eCcTQ7pYTBauZl+XmyFvyiADKo
# 6Dng4jyuxYRP3EdCGVlZK7sEmiz1Y2f3zh0xoF58B3xXDnRJxo8ArlEAG8KzXn6w
# ryaA1vbgITCCBqMwggWLoAMCAQICEA+oSQYV1wCgviF2/cXsbb0wDQYJKoZIhvcN
# AQEFBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJl
# ZCBJRCBSb290IENBMB4XDTExMDIxMTEyMDAwMFoXDTI2MDIxMDEyMDAwMFowbzEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEuMCwGA1UEAxMlRGlnaUNlcnQgQXNzdXJlZCBJRCBDb2Rl
# IFNpZ25pbmcgQ0EtMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJx8
# +aCPCsqJS1OaPOwZIn8My/dIRNA/Im6aT/rO38bTJJH/qFKT53L48UaGlMWrF/R4
# f8t6vpAmHHxTL+WD57tqBSjMoBcRSxgg87e98tzLuIZARR9P+TmY0zvrb2mkXAEu
# sWbpprjcBt6ujWL+RCeCqQPD/uYmC5NJceU4bU7+gFxnd7XVb2ZklGu7iElo2NH0
# fiHB5sUeyeCWuAmV+UuerswxvWpaQqfEBUd9YCvZoV29+1aT7xv8cvnfPjL93Sos
# MkbaXmO80LjLTBA1/FBfrENEfP6ERFC0jCo9dAz0eotyS+BWtRO2Y+k/Tkkj5wYW
# 8CWrAfgoQebH1GQ7XasCAwEAAaOCA0MwggM/MA4GA1UdDwEB/wQEAwIBhjATBgNV
# HSUEDDAKBggrBgEFBQcDAzCCAcMGA1UdIASCAbowggG2MIIBsgYIYIZIAYb9bAMw
# ggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3LmRpZ2ljZXJ0LmNvbS9zc2wtY3Bz
# LXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUHAgIwggFWHoIBUgBBAG4AeQAgAHUA
# cwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGMA
# bwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBjAGUAcAB0AGEAbgBjAGUAIABvAGYA
# IAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMAUAAvAEMAUABTACAAYQBuAGQA
# IAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEAcgB0AHkAIABBAGcAcgBlAGUA
# bQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBtAGkAdAAgAGwAaQBhAGIAaQBsAGkA
# dAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBjAG8AcgBwAG8AcgBhAHQAZQBkACAA
# aABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBlAHIAZQBuAGMAZQAuMBIGA1UdEwEB
# /wQIMAYBAf8CAQAweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6
# MHgwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3Vy
# ZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwHQYDVR0OBBYEFHtozimqwBe+SXrh
# 5T/Wp/dFjzUyMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqG
# SIb3DQEBBQUAA4IBAQB7ch1k/4jIOsG36eepxIe725SS15BZM/orh96oW4AlPxOP
# m4MbfEPE5ozfOT7DFeyw2jshJXskwXJduEeRgRNG+pw/alE43rQly/Cr38UoAVR5
# EEYk0TgPJqFhkE26vSjmP/HEqpv22jVTT8nyPdNs3CPtqqBNZwnzOoA9PPs2TJDn
# dqTd8jq/VjUvokxl6ODU2tHHyJFqLSNPNzsZlBjU1ZwQPNWxHBn/j8hrm574rpyZ
# lnjRzZxRFVtCJnJajQpKI5JA6IbeIsKTOtSbaKbfKX8GuTwOvZ/EhpyCR0JxMoYJ
# mXIJeUudcWn1Qf9/OXdk8YSNvosesn1oo6WQsQz/MYIENDCCBDACAQEwgYMwbzEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEuMCwGA1UEAxMlRGlnaUNlcnQgQXNzdXJlZCBJRCBDb2Rl
# IFNpZ25pbmcgQ0EtMQIQBvAV2BVGI+l5s0YBGmSUlTAJBgUrDgMCGgUAoHgwGAYK
# KwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU
# kNBF8QRLwGFMqkg6sxcoyLCSu20wDQYJKoZIhvcNAQEBBQAEggEAnqDnKAz+cIdK
# g2eXShcTC5nQKNDhZk6UI+GlM+u77r8tGRWH/RNWQwLQKUUIUn3g+ZU1Krv0J8/j
# 28LcJ0ICYooID2jol9RUsR/Sjg4NQihDhce0iGZqmyWJs5ZZcoN7tE5kr2S+o22W
# kjfmLZuFH2e5sz5vSohbUfIQGat1QvB71ZtJZlMHm9OZmMt3ExTZRfOs7OTTpRc1
# n8y4syFM637lGkiFeCHQTGoSV4M3ubcSRbvHBexDSjANbqRYcOvU8K3DKF6CX6qs
# vTX6dvpN3jB9EleE2HTqLy3PJDs1Nom6YEDtOmCG88BQl5VOSnFLEAtfe2YrVeVg
# bgIq7X+hFaGCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIBATByMF4xCzAJBgNV
# BAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEwMC4GA1UEAxMn
# U3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcyAhAOz/Q4yP6/
# NW4E2GqYGxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcB
# MBwGCSqGSIb3DQEJBTEPFw0xNDA3MDcyMDU3MDhaMCMGCSqGSIb3DQEJBDEWBBS1
# XQ/A5QYX89qj2C7xaei9Bh5u9DANBgkqhkiG9w0BAQEFAASCAQBRCo7PDPNCvb+f
# 5l2VzuObqltjyAveb6SQVc/mlVEWfFsMV/BLEY3vaWRyUYkhbo7eWolleBZoWIuz
# r0yHAyBNiySjB+oSFmHJKHLSfaVGgE7XSTAoXtupmZKQinfupZu4UqphQW2Ek+lP
# gBcUSvsDCwo/YguWFhnFV5ghTe3yjAeuUmPXSM3j+kps8O4XcKyFGmJj/lQ02PJw
# NcZ1M+KYa2AiNdOIViZCbTiKF2NWziU0rbU9qVYyrMxAd7DCaexvJe06Vq6jg5ax
# F5AeRjLmhCpGo5VIxroIpdRbvEN3cKeBDVeUZw1VZK6ly/QtExwisihPO8O1jJ7H
# 3C9lW3H3
# SIG # End signature block
