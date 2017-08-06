#Function Out-Graph {

    Param (
        [parameter(ValueFromPipeline=$True)] [PSObject]$InputObject,
        $xArray = $false,
        $yArray = $false,
        $xyArray = $false,
        $Title = $false
    )
    
    Begin {
        $Debug = $true
        $DataHash = New-Object hashtable
        $MultipleWarning = @()
    }
    Process {
        if ($InputObject) {
            # This means that we've been piped or an object has been added as a parameter
            $InputObject | ForEach-Object {
                $xAxisItem  = $_.PSObject.Properties.Name[0]
                $yAxisItem  = [String]$_.PSObject.Properties.Name[1]
                $xValue = $_.$xAxisItem
                $yValue = $_.$yAxisItem

                # Check if the element contains any newlines
                if ($yValue.Contains("`n")) {
                    $yValue = $yValue.SubString(0,($yValue.IndexOf("`n")))
                }
                # Also ensure that the field is no longer than maxLength
                $maxLength = 70
                if ( $yValue.Length -gt $maxlength ) {
                    $yValue = $yValue.Substring(0,$maxlength) + "..."
                }
                $xValue = [string]$xValue

                # Now populate the DataHash
                if ( ($DataHash.Count -gt 0) -and ($DataHash.ContainsKey($xValue)) ) {
                    # Write-Warning ("Key [" + $xValue + "] is registered multiple times. Results may be inaccurate. Please verify input values.")
                    $DataHash[$xValue]["Value"] = $DataHash[$xValue]["Value"] + 1
                } else {
                    # Write-Host (")))))))>>> " + [string]$xValue)
                    $DataHash.Add([string]$xValue, (New-Object hashtable))
                    $DataHash[$xValue].Add("Value", 1)
                    $DataHash[$xValue].Add("Label", $yValue)
                }

            }
        }
    }
    End {
        # "End loop"
        $xArray = @()
        $yArray = @()
        $xyArray = @{}
        $DataHash.Count
        $DataHash.Keys | Foreach-Object {
            if ($Debug) {
                Write-Host ("--------")
                Write-Host ("Label: " + $DataHash[$_].Label)
                Write-Host ("Value: " + $DataHash[$_].Value)
            }
            $xArray += $_
            $yArray += $DataHash[$_].Value
            $xyArray.Add($_, $DataHash[$_].Value)
        }

        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
        
        # create chart object 
        $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
        $Chart.Width = 500 
        $Chart.Height = 400 
        $Chart.Left = 40 
        $Chart.Top = 30
        
        # create a chartarea to draw on and add to chart 
        $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 
        $Chart.ChartAreas.Add($ChartArea)
        
        # add data to chart 
        [void]$Chart.Series.Add("Data") 
        $Chart.Series["Data"].Points.DataBindXY($xyArray.Keys, $xyArray.Values)
        
        
        
        # display the chart on a form 
        $Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor 
        [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left 
        $Form = New-Object Windows.Forms.Form 
        $Form.Text = "PowerShell Chart" 
        $Form.Width = 600 
        $Form.Height = 600 
        $Form.controls.add($Chart) 
        $Form.Add_Shown({$Form.Activate()}) 
        $Form.ShowDialog()

    }
#}
