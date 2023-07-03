<#
 .SYNOPSYS
  Generate random password and give the password strength score.

 .DESCRIPTION
  Generate random password, this function support multiple configuration.

 .PARAMETER MinimumLength
  The minimum length require for generating password. Minimum 4 char.(Mandatory)

 .PARAMETER IncludeUppercase
  Include minimum one uppercase in password (Default True)

 .PARAMETER IncludeLowercase
  Include minimum one lowercase in password (Default True)

 .PARAMETER IncludeNumbers
  Include minimum one number in password (Default True)

 .PARAMETER IncludeSymbols
  Include minimum one symbol in this set ("&@$!#?") in password (Default True)

 .PARAMETER IncludeOtherSymbols
  Include minimum one symbol in this set ("()[].*-") in password (Default True)

 .PARAMETER NoRepeat
  Specify if a char can be use more than once.

 .EXAMPLE
    $PasswordParameters = @{
        MinimumLength = $syncHash.Window.FindName("Slider_PwdLength").Value
        IncludeUppercase = $syncHash.Window.FindName("CHK_PwdOption_uppercase").IsChecked
        IncludeLowercase = $syncHash.Window.FindName("CHK_PwdOption_lowercase").IsChecked
        IncludeNumbers =  $syncHash.Window.FindName("CHK_PwdOption_number").IsChecked
        IncludeSymbols = $syncHash.Window.FindName("CHK_PwdOption_symbol").IsChecked
        IncludeOtherSymbols = $syncHash.Window.FindName("CHK_PwdOption_othersymbol").IsChecked
        NoRepeat = $syncHash.Window.FindName("CHK_PwdOption_unique").IsChecked
    }

    $result = Get-RandomPassword @PasswordParameters
    $CurrentPwd = $result.Password
    $CurrentPwdStrength = $result.Strength

 .EXAMPLE
    Get-RandomPassword -MinimumLength 12 -IncludeUppercase $true -IncludeLowercase $true -IncludeNumbers $false - IncludeSymbols $true -IncludeOtherSymbols $false -NoRepeat $false
    (Get-RandomPassword -MinimumLength 20 -NoRepeat $true).Password

 .NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  03/07/2023
  Purpose/Change: Initial script development

 .LINK
    Author : Letalys (https://github.com/Letalys)

 .LINK
    Fisher Yates Shuffles : https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle
#>
function Get-RandomPassword {
    param(
        [Parameter(Mandatory = $true)][int]$MinimumLength,
        [bool]$IncludeUppercase = $true,
        [bool]$IncludeLowercase = $true,
        [bool]$IncludeNumbers= $true,
        [bool]$IncludeSymbols= $true,
        [bool]$IncludeOtherSymbols= $true,
        [bool]$NoRepeat = $false
    )
    Process {
        $characterSet = ''

        if ($IncludeUppercase) {$characterSet += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"}
        if ($IncludeLowercase) {$characterSet += "abcdefghijklmnopqrstuvwxyz"}
        if ($IncludeNumbers) {$characterSet += "0123456789"}
        if ($IncludeSymbols) {$characterSet += "&@$!#?"}
        if ($IncludeOtherSymbols) {$characterSet += "()[].*-,"}

        $password = ''
        $random = New-Object System.Random

        if($characterSet -ne ''){
            while ($password.Length -lt $MinimumLength -or ($IncludeUppercase -and !($password -match "[A-Z]")) -or ($IncludeLowercase -and !($password -match "[a-z]")) -or ($IncludeNumbers -and !($password -match "[0-9]")) -or ($IncludeSymbols -and !($password -match "[&@$!#?]")) -or ($IncludeOtherSymbols -and !($password -match "[\(\)\[\.\]\*-]"))) {
                $password = ''

                if ($NoRepeat) {
                    #Fisher Yates Algorythm 
                    $availableCharacters = $characterSet.ToCharArray()
                    $characterCount = $availableCharacters.Length

                    for ($i = 0; $i -lt $characterCount; $i++) {
                        $randomIndex = $random.Next($i, $characterCount)
                        $temp = $availableCharacters[$randomIndex]
                        $availableCharacters[$randomIndex] = $availableCharacters[$i]
                        $availableCharacters[$i] = $temp
                    }

                    $password = -join $availableCharacters[0..($MinimumLength - 1)]

                    if($($password).length -lt $MinimumLength){
                        $OutLimit = $true
                        break
                    }
                }else {
                    for ($i = 1; $i -le $MinimumLength; $i++) {
                        $randomIndex = $random.Next(0, $characterSet.Length)
                        $password += $characterSet[$randomIndex]
                    }
                    $OutLimit = $false
                }
            }
        }else{
            $OutLimit = $true
            $password = ''
        }

        # Calculate password strength
        $lengthScore = [Math]::Min([Math]::Floor(($MinimumLength / 20) * 100), 100)

        $characterTypes = 0
        $characterTypeWeights = @{}  #Array to store character type weights

        # Define char weight for each type
        $characterTypeWeights["Uppercase"] = 4
        $characterTypeWeights["Lowercase"] = 2
        $characterTypeWeights["Numbers"] = 3
        $characterTypeWeights["Symbols"] = 5
        $characterTypeWeights["OtherSymbols"] = 5

        # Check presence of char type in password
        if ($IncludeUppercase -and $password -match "[A-Z]") {$characterTypes++}
        if ($IncludeLowercase -and $password -match "[a-z]") {$characterTypes++}
        if ($IncludeNumbers -and $password -match "[0-9]") {$characterTypes++}
        if ($IncludeSymbols -and $password -match "[&@$!#?]") {$characterTypes++}
        if ($IncludeOtherSymbols -and $password -match "[\(\)\[\.\]\*-,]") {$characterTypes++}

        # Calculate diversity score
        $diversityScore = 0

        foreach ($characterType in $characterTypeWeights.Keys) {
            $regexPattern = Get-CharacterTypeRegexPattern $characterType
            if ($password -match $regexPattern) {
                $diversityScore += $characterTypeWeights[$characterType]
            }
        }

        # Add Diversity score for Other Symbol char in password
        $otherSymbolsCount = ($password -split "\W" | Where-Object { $_ -ne "" }).Length
        $diversityScore += [Math]::Min(($otherSymbolsCount * $characterTypeWeights["OtherSymbols"]), $characterTypeWeights["OtherSymbols"])

        # Combinate score to get strength
        $strength = [Math]::Min(($lengthScore + $diversityScore), 100)

        if ($password -eq '') { $strength = 0 }

        # Auxiliary function to get the regex pattern corresponding to the character type
        function Get-CharacterTypeRegexPattern($characterType) {
            switch ($characterType) {
                "Uppercase" { return "[A-Z]" }
                "Lowercase" { return "[a-z]" }
                "Numbers" { return "[0-9]" }
                "Symbols" { return "[&@$!#?]" }
                "OtherSymbols" { return "[\(\)\[\.\]\*-,]" }
            }
        }

        [PSCustomObject]@{
            Password = $password
            Strength = $strength
            OutLimit = $OutLimit
        }
    }
}

Export-ModuleMember -Function Get-RandomPassword 