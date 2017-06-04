 $a = @{}; 
 $sleeptime = 15
 
 1,2,3 | ForEach-Object { 
    $b = Start-Process -PassThru -Verbose  sleep $sleeptime
    $a.add($_, $b) 
 }


while ($a.Keys.Count -gt 0) {
    $remove = @()
    
    $a.Keys | ForEach-Object {
        $_proc = Get-Process -id $a[$_].Id -ErrorAction SilentlyContinue
        if ( $_proc ) { 
            $sec = ((Get-Date) - $_proc.starttime).Seconds
            # "ProcessID [" + $_proc.id + "] has been running for " + $sec + " seconds"
            Write-Progress -Activity ("Process "+ $_proc.id)  -Id $_proc.id -SecondsRemaining ($sleeptime - $sec) -PercentComplete ($sec / $sleeptime * 100)
        } else { $remove += $_}
    }

    $remove | ForEach-Object {
        $a.Remove($_)
    }

}