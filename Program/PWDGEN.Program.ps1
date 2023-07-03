<#
 .SYNOPSYS
  Password Generator UI based on module Password-Generator.psm1.

 .DESCRIPTION
  A user interface to generate random passwords while changing settings. 
  This interface is inspired by that of dashlane. ;)
 
 .NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  03/07/2023
  Purpose/Change: Initial script development

 .LINK
    Author : Letalys (https://github.com/Letalys)
#>

#region Define directory from current execution
        $PADirRoot = Split-Path -Path $PSScriptRoot -Parent
        $PADirProg = Join-Path -Path $PADirRoot -ChildPath "Program"
        $PADirUI = Join-Path -Path $PADirRoot -ChildPath "UI"
#endregion

#region load type 
    Add-Type -AssemblyName PresentationCore, PresentationFramework
    Add-Type -AssemblyName System.Windows.Forms
#endregion

#region create main runspace
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
#endregion

#region MainCode
$MainCode = {
    Param($PSScriptRoot)

    Set-Culture -CultureInfo fr-FR

    #region Define runspace directory
        $PADirRoot = Split-Path -Path $PSScriptRoot -Parent
        $PADirProg = Join-Path -Path $PADirRoot -ChildPath "Program"
        $PADirUI = Join-Path -Path $PADirRoot -ChildPath "UI"
        $PADirLib = Join-Path -Path $PADirRoot -ChildPath "Lib"
    #endregion
    #region Import Module Password Generator
        Import-Module "$PADirLib\Password-Generator.psm1" -Force
    #endregion
    #region Functions
        Function Export-PasswordConfiguration {
            param(
                    [int]$MinimumLength,
                    [bool]$IncludeUppercase,
                    [bool]$IncludeLowercase,
                    [bool]$IncludeNumbers,
                    [bool]$IncludeSymbols,
                    [bool]$IncludeOtherSymbols,
                    [bool]$NoRepeat
                )

            $settings = @{
                MinimumLength = $MinimumLength
                IncludeUppercase = $IncludeUppercase
                IncludeLowercase = $IncludeLowercase
                IncludeNumbers = $IncludeNumbers
                IncludeSymbols = $IncludeSymbols
                IncludeOtherSymbols = $IncludeOtherSymbols
                NoRepeat = $NoRepeat
            }

            $settings | ConvertTo-Json | Out-File -FilePath "$env:LOCALAPPDATA\PasswordSettings.json"
        }
        Function Import-PasswordConfiguration {
            if((Test-Path "$env:LOCALAPPDATA\PasswordSettings.json") -eq $true){

                $settings = Get-Content -Raw -Path "$env:LOCALAPPDATA\PasswordSettings.json" | ConvertFrom-Json

                $MinimumLength = $settings.MinimumLength
                $IncludeUppercase = $settings.IncludeUppercase
                $IncludeLowercase = $settings.IncludeLowercase
                $IncludeNumbers = $settings.IncludeNumbers
                $IncludeSymbols = $settings.IncludeSymbols
                $IncludeOtherSymbols = $settings.IncludeOtherSymbols
                $NoRepeat = $settings.NoRepeat
            }else{
                $MinimumLength = 12
                $IncludeUppercase = $true
                $IncludeLowercase = $true
                $IncludeNumbers = $true
                $IncludeSymbols = $true
                $IncludeOtherSymbols = $true
                $NoRepeat = $false
            }

            [PSCustomObject]@{
                MinimumLength = $MinimumLength
                IncludeUppercase = $IncludeUppercase
                IncludeLowercase = $IncludeLowercase
                IncludeNumbers = $IncludeNumbers
                IncludeSymbols = $IncludeSymbols
                IncludeOtherSymbols = $IncludeOtherSymbols
                NoRepeat = $NoRepeat
            }
    
        }
        Function Set-PasswordFromUI{
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

            $syncHash.Window.FindName("TBX_GeneratedPassword").text = $CurrentPwd
            $syncHash.Window.FindName("PB_Strength").Value = $CurrentPwdStrength

            
            $syncHash.Window.FindName("LBL_Strength").Content = $CurrentPwdStrength
            
            Switch($true){
                ($CurrentPwdStrength -ge 90){

                    $syncHash.Window.FindName("PB_Strength").Foreground ="#FF13FF00"
                    Break
                }
                (($CurrentPwdStrength -ge 80)-and ($CurrentPwdStrength -lt 90)){
                    $syncHash.Window.FindName("PB_Strength").Foreground ="#FF0E7B05"
                    Break
                }
                (($CurrentPwdStrength -ge 50)-and ($CurrentPwdStrength -lt 80)){
                    $syncHash.Window.FindName("PB_Strength").Foreground ="#FFFFA400"
                    Break
                }
                ($CurrentPwdStrength -lt 50){
                    $syncHash.Window.FindName("PB_Strength").Foreground ="#FFFF0000"
                    Break
                }
            }

            if(($result.OutLimit -eq $true) -and ($result.Password -ne '')){
                [System.Windows.Forms.MessageBox]::Show("The number of unique characters available is less than the number of characters requested. `nThe current password will not respect the length criterion.", "Password Generator", "OK", "Warning")
            }
        }
    #endregion
    #region XAML UI Design
        [xml]$XAML = [IO.File]::ReadAllText($(Join-Path -Path $Global:PADirUI -ChildPath "Pwd.UI.xml"),[Text.Encoding]::GetEncoding(65001))
    #endregion
    #region XAML UI Load
        #Creation of a Thread-Safe synchronization HashTable, allows retrieval of objects and properties by any RunSpace
        $syncHash = [hashtable]::Synchronized(@{})

        #Loading XAML code which is then added to the synchronization Hash table
        $XAMLReader=(New-Object System.Xml.XmlNodeReader $XAML)
        $syncHash.Window=[Windows.Markup.XamlReader]::Load($XAMLReader)
    #endregion
    #region XAML Events
        #region General Events
            $syncHash.Window.FindName("Form").Add_ContentRendered({
                $PassswordSettings = Import-PasswordConfiguration

                #[System.Windows.Forms.MessageBox]::Show($PassswordSettings.MinimumLength, "Message", "OK", "Information")

                $syncHash.Window.FindName("Slider_PwdLength").Value= $PassswordSettings.MinimumLength
                $syncHash.Window.FindName("CHK_PwdOption_uppercase").IsChecked= $PassswordSettings.IncludeUppercase
                $syncHash.Window.FindName("CHK_PwdOption_lowercase").IsChecked= $PassswordSettings.IncludeLowercase
                $syncHash.Window.FindName("CHK_PwdOption_number").IsChecked= $PassswordSettings.IncludeNumbers
                $syncHash.Window.FindName("CHK_PwdOption_symbol").IsChecked= $PassswordSettings.IncludeSymbols
                $syncHash.Window.FindName("CHK_PwdOption_othersymbol").IsChecked= $PassswordSettings.IncludeOtherSymbols
                $syncHash.Window.FindName("CHK_PwdOption_unique").IsChecked= $PassswordSettings.NoRepeat

                Set-PasswordFromUI
            })
            $syncHash.Window.FindName("B_GenerateNewPassword").Add_Click({
                Set-PasswordFromUI
            })
            $syncHash.Window.FindName("B_GenerateNewPassword").Add_Click({
                Set-Clipboard -Value $syncHash.Window.FindName("TBX_GeneratedPassword").Text
            })

            $syncHash.Window.FindName("Slider_PwdLength").Add_ValueChanged({
                Set-PasswordFromUI
            })
            $syncHash.Window.FindName("CHK_PwdOption_uppercase").Add_Click({
                Set-PasswordFromUI
            })
            $syncHash.Window.FindName("CHK_PwdOption_lowercase").Add_Click({
                Set-PasswordFromUI
            })
            $syncHash.Window.FindName("CHK_PwdOption_number").Add_Click({
                Set-PasswordFromUI
            })
            $syncHash.Window.FindName("CHK_PwdOption_symbol").Add_Click({
                Set-PasswordFromUI
            })
            $syncHash.Window.FindName("CHK_PwdOption_othersymbol").Add_Click({
                Set-PasswordFromUI
            })
            $syncHash.Window.FindName("CHK_PwdOption_unique").Add_Click({
                Set-PasswordFromUI
            })

            $syncHash.Window.FindName("B_RegisterOptions").Add_Click({
                $PasswordParameters = @{
                    MinimumLength = $syncHash.Window.FindName("Slider_PwdLength").Value
                    IncludeUppercase = $syncHash.Window.FindName("CHK_PwdOption_uppercase").IsChecked
                    IncludeLowercase = $syncHash.Window.FindName("CHK_PwdOption_lowercase").IsChecked
                    IncludeNumbers =  $syncHash.Window.FindName("CHK_PwdOption_number").IsChecked
                    IncludeSymbols = $syncHash.Window.FindName("CHK_PwdOption_symbol").IsChecked
                    IncludeOtherSymbols = $syncHash.Window.FindName("CHK_PwdOption_othersymbol").IsChecked
                    NoRepeat = $syncHash.Window.FindName("CHK_PwdOption_unique").IsChecked
                }

                Export-PasswordConfiguration @PasswordParameters
                [System.Windows.Forms.MessageBox]::Show("Param�tres sauvegard�s", "Message", "OK", "Information")
            })

            $syncHash.Window.FindName("B_GenerateMultiPassword").Add_Click({
                $maxGen = $syncHash.Window.FindName("TBX_NumberOfPwdToGenerate").Text

                $PasswordParameters = @{
                    MinimumLength = $syncHash.Window.FindName("Slider_PwdLength").Value
                    IncludeUppercase = $syncHash.Window.FindName("CHK_PwdOption_uppercase").IsChecked
                    IncludeLowercase = $syncHash.Window.FindName("CHK_PwdOption_lowercase").IsChecked
                    IncludeNumbers =  $syncHash.Window.FindName("CHK_PwdOption_number").IsChecked
                    IncludeSymbols = $syncHash.Window.FindName("CHK_PwdOption_symbol").IsChecked
                    IncludeOtherSymbols = $syncHash.Window.FindName("CHK_PwdOption_othersymbol").IsChecked
                    NoRepeat = $syncHash.Window.FindName("CHK_PwdOption_unique").IsChecked
                }

                # Create SaveFileDialog
                $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
                $saveFileDialog.Filter = "Fichiers CSV (*.csv)|*.csv"
                $saveFileDialog.Title = "Enregistrer le fichier"
                $saveFileDialog.InitialDirectory = $env:USERPROFILE

                # Showing  SaveFileDialog
                $resultSFD = $saveFileDialog.ShowDialog()

                # Get selected Filepath
                if ($resultSFD -eq 'OK') {
                    $Pwdlist = ''

                    for($i=1;$i -le $maxGen ;$i++){
                        $password = (Get-RandomPassword @PasswordParameters).Password
                        $Pwdlist += "$password`n"
                        #You have to put a timer otherwise the seed of the random number remains the same between the iterations.
                        Start-Sleep -Milliseconds 1
                    }
                    Set-Content -Path $saveFileDialog.FileName -Value $Pwdlist

                                        
                    [System.Windows.Forms.MessageBox]::Show("Password generation complete !", "Message", "OK", "Information")
                }
            })
        #endregion
    #endregion

    $syncHash.Window.ShowDialog()
    $Runspace.Close()
    $Runspace.Dispose()
}
#endregion

#region Gestion Runspace principal
    $PSInstanceMain = [powershell]::Create()
    $PSInstanceMain.AddScript($MainCode)
    $PSInstanceMain.AddArgument($PSScriptRoot)

    $PSInstanceMain.Runspace = $Runspace
    $Job = $PSInstanceMain.BeginInvoke()
	
	 #required for call from Shortcut and clean termination of the runspace
	 while (-not $Job.IsCompleted) {
	    Start-Sleep -Seconds 1
	 }

	 $runspaceresult = $PSInstanceMain.EndInvoke($Job)
#endregion