$a = @{}; 
$PercentComplete = @{}
$sleeptime = 15
 
$stuff = (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17)

$stuff | ForEach-Object { 
   $b = Start-Process -PassThru -Verbose  sleep (Get-Random (1..$sleeptime))
   $a.add($_, $b) 
   $PercentComplete.add($_,0)
}

$fullcount = $stuff.Count
$blarp = 100/$fullcount


while ($a.Keys.Count -gt 0) {
    Write-Progress -Activity "Main" -id 0 -CurrentOperation " " -PercentComplete (($fullcount - $a.Count) * $blarp)

    $remove = @()
    
    $a.Keys | ForEach-Object {
        $_proc = Get-Process -id $a[$_].Id -ErrorAction SilentlyContinue
        if ( $_proc ) { 
            $sec = ((Get-Date) - $_proc.starttime).Seconds
            # "ProcessID [" + $_proc.id + "] has been running for " + $sec + " seconds"
            $percentcomplete[$_] = ($sec / $sleeptime * 100)
            
        } else { 
            if ($percentcomplete[$_] -ge 102) {
                $dontprint = $true
                "DONTPRINT : [" + $_ +"]"
            }
            $percentcomplete[$_] = 100
            $remove += $_
        }
        if ($percentcomplete[$_] -ge 100) {
            $percentcomplete[$_] ++
            Write-Progress -ParentId 0 -Activity " " -Id $_ -Completed
        } else {
           Write-Progress -ParentId 0 -Activity ("Process "+ $_)  -Id $_ -SecondsRemaining ($sleeptime - $sec) -CurrentOperation " " -PercentComplete $percentcomplete[$_]
        }
        "Status ["+$_+"]; " + $percentcomplete[$_]
    }

    $remove | ForEach-Object {
        $a.Remove($_)
    }
    sleep 1
}