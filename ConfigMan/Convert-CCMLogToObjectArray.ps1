## PowerShell function to convert a log formatted with the ConfigMgr log schema into an array of objects
# Parameters:
# - LogPath. The full path to the log file
# - LineCount. The number of log entries to return, starting from the BOTTOM up (ie most recent back). Default: 500.

function Convert-CCMLogToObjectArray {
    Param ($LogPath,$LineCount = 500)

    # Custom class to define a log entry
    class LogEntry {
        [string]$LogText
        [datetime]$DateTime 
        [string]$component
        [string]$context 
        [int]$type
        [int]$thread 
        [string]$file
    }

    # Function to extract the content between two strings in a string
    function Extract-String {
        param($String,$SearchStringStart,$SearchStringEnd)
        $Length = $SearchStringStart.Length
        $StartIndex = $LogLine.IndexOf($SearchStringStart,0) + $Length
        $EndIndex = $LogLine.IndexOf($SearchStringEnd,$StartIndex)
        return $LogLine.Substring($StartIndex,($EndIndex - $StartIndex))
    }

    If (Test-Path $LogPath)
    {
        $LogContent = (Get-Content $LogPath -Raw) -split "<!"
        $LogEntries = [System.Collections.ArrayList]::new()
        foreach ($LogLine in ($LogContent | Select -Last $LineCount))
        {
            If ($LogLine.Length -gt 0)
            {
                $LogEntry = [LogEntry]::new()
                $LogEntry.LogText = Extract-String -String $LogLine -SearchStringStart '[LOG[' -SearchStringEnd ']LOG'
                $time = Extract-String -String $LogLine -SearchStringStart '<time="' -SearchStringEnd '"'
                $date = Extract-String -String $LogLine -SearchStringStart 'date="' -SearchStringEnd '"'
                $DateTimeString = $date + " " + $time.Split('.')[0]          
                $LogEntry.DateTime = [datetime]::ParseExact($DateTimeString,"MM-dd-yyyy HH:mm:ss",[System.Globalization.CultureInfo]::InvariantCulture)
                $LogEntry.component = Extract-String -String $LogLine -SearchStringStart 'component="' -SearchStringEnd '"'
                $LogEntry.context = Extract-String -String $LogLine -SearchStringStart 'context="' -SearchStringEnd '"'
                $LogEntry.type = Extract-String -String $LogLine -SearchStringStart 'type="' -SearchStringEnd '"'
                $LogEntry.thread = Extract-String -String $LogLine -SearchStringStart 'thread="' -SearchStringEnd '"'
                $LogEntry.file = Extract-String -String $LogLine -SearchStringStart 'file="' -SearchStringEnd '"'
                [void]$LogEntries.Add($LogEntry)
            }
        }
        return $LogEntries
    }
}


## Examples
# Display the last 500 entries in the ccmsetup.log
$LogPath = "$env:windir\ccmsetup\Logs\ccmsetup.log"
Convert-CCMLogToObjectArray -LogPath $LogPath | Out-GridView

# Display any warnings or errors from the last 2000 entries in the CcmMessaging log
$LogPath = "$env:windir\CCM\Logs\CcmMessaging.log"
$Log = Convert-CCMLogToObjectArray -LogPath $LogPath -LineCount 2000
$Log | Where {$_.type -notin @(0,1)} | Out-GridView

# Get the return code for the ccmsetup process
$LogPath = "$env:windir\ccmsetup\Logs\ccmsetup.log"
$ReturnCodeEntry = Convert-CCMLogToObjectArray -LogPath $LogPath -LineCount 10 | Where-Object {$_.LogText -match "CcmSetup" -and $_.LogText -match "code"}
If ($ReturnCodeEntry)
{
    [PSCustomObject]@{
        ReturnCode = $ReturnCodeEntry.LogText.Split()[-1]
        Date = $ReturnCodeEntry.DateTime
        Age_Days = ([DateTime]::Now - $ReturnCodeEntry.DateTime).Days
    }
}