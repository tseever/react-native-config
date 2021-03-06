param([string]$ProjectDir = '')

# Allow utf-8 charactor in config value
# For example, APP_NAME=中文字符
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$defaultEnvFile = ".env"

# pick a custom env file if set
$customEnvPath = Join-Path $env:temp "envfile"
"Checking for custom env from {0}" -f $customEnvPath | Write-Host
if ([IO.File]::Exists($customEnvPath)) {
    $custom_env = 1
    $file = Get-Content -Path $customEnvPath
    $file = $file -replace '"', "" #strip quotes
} else {
    $custom_env = 0
    $file = if ($env:ENVFILE) { $env:ENVFILE } else { $defaultEnvFile }
}

"Reading env from {0}" -f $file | Write-Host

Function dotenv($ProjectDir, $file, $defaultEnvFile)
{
    $h = @{}

    # https://regex101.com/r/cbm5Tp/1
    # switched alphanumeric charset to \w for powershell
    $dotenv_pattern = "^(?:export\s+|)(?<key>\w+)=((?<quote>[""'])?(?<val>.*?[^\\])\k<quote>?|)$"

    # find that above node_modules/react-native-config/windows/ReactNativeConfig
    $rootOffsetFromProject = "..\..\..\..\"
    $envFilePath = "{0}{1}" -f $rootOffsetFromProject, $file
    $path = Join-Path $ProjectDir $envFilePath

    if ([IO.File]::Exists($path)) {
        $raw = Get-Content -Path $path
    } elseif ([IO.File]::Exists($file)) {
        $raw = Get-Content -Path $file
    } else {
        $defaultEnvPath = Join-Path -Path $ProjectDir -ChildPath $rootOffsetFromProject | Join-Path -ChildPath $defaultEnvFile

        if (![IO.File]::Exists($defaultEnvPath)) {
            # try as absolute path
            $defaultEnvPath = $defaultEnvFile
        }

        if (![IO.File]::Exists($defaultEnvPath)) {
            Write-Warning @"

**************************
*** Missing .env file ****
**************************
"@
            return @{} # return  dotenv as an empty hash
        }

        # finally, pre-pend if it exists
        $defaultRaw = Get-Content -Path $defaultEnvPath
        if ($defaultRaw) {
            $raw = $defaultRaw + "`r`n" + $raw
        }
    }

    $raw = $raw -Split [System.Environment]::NewLine
    $raw | ForEach-Object -Process {
        $allmatches = [regex]::Matches($_, $dotenv_pattern)
        if ($allmatches.Count -gt 0) {
            $key = if ($null -eq $allmatches[0].Groups['key']) { "" } else { $allmatches[0].Groups['key'] }
            $val = if ($null -eq $allmatches[0].Groups['val']) { "" } else { $allmatches[0].Groups['val'] }

            # Ensure string (in case of empty value) and escape any quotes present in the value.
            $val = [string]$val -replace '"', ''

            if ($null -ne $key -and $key -ne "") {
                $h.Add($key, $val)
            }
        }
    }
    return $h
}

$file = if ($null -ne $file) { "$file" } else { "" }
$defaultEnvFile = if ($null -ne $defaultEnvFile) { "$defaultEnvFile" } else { "" }
$dotenv_hash = dotenv -ProjectDir $ProjectDir -file $file -defaultEnvFile $defaultEnvFile

# create partial class file that sets DOT_ENV as a Dictionary<string,string>
$template = @"
// This file is auto-generated by ReactNativeConfig.
// Any direct changes will be lost. Update the appropriate .env file instead
using System.Collections.Generic;
using ReactNative;
using ReactNative.Bridge;

namespace ReactNativeConfig
{{
    partial class ReactNativeConfigModule : NativeModuleBase
    {{
        protected Dictionary<string,object> DOT_ENV = new Dictionary<string,object>()
        {{
{0}
        }};
    }}
}}
"@

if ($dotenv_hash.Count -gt 0) {
    $dotenv_csdict = (($dotenv_hash.Keys | Foreach-Object {
        "            {""$($_)"", @""$($dotenv_hash[$_])""}"
    })) -Join ",`r`n"
} else {
    $dotenv_csdict = ""
}
$dotenv_csdict = $template -f $dotenv_csdict

# write it so that ReactNativeConfigModule.cs can return it
$path = Join-Path $ProjectDir -ChildPath "GeneratedDotEnv.cs"
Out-File -FilePath $path -InputObject $dotenv_csdict -Encoding 'UTF8'

if ($custom_env) {
    [IO.File]::Delete($customEnvPath)
}

"Wrote generated config to {0}" -f $path | Write-Host
