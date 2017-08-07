#Function Out-Graph {
<#

.SYNOPSIS
This is a Out pipeline which creates a Graph from two input sets. Input can also be an Object containing two values. If more values exists, only the first two will be used.

.DESCRIPTION
More detailed description here

.EXAMPLE
Get-Eventlog -Logname System -Newest 10 | Out-Graph

.NOTES
Put some notes here.

.LINK
A link here

#>


    Param (
        [parameter(Mandatory=$False, ValueFromPipeline=$True)] [PSObject]$InputObject,
        $xArray = $false,
        $yArray = $false,
        $xyArray = $false,
		[ValidateSet("Auto", "Days", "Hours", "Minutes", "Months", "Seconds", "Weeks", "Years")][String]$TimeLine = $false,
        $Title = $false
    )
    
    Begin {
		if ($PSBoundParameters['Debug']) {
		    $DebugPreference = 'Continue'
        	$Debug = $true
		} else {
			$Debug = $false
		}
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
                    $DataHash[$xValue]["Value"] = $DataHash[$xValue]["Value"] + 1
                } else {
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
			Write-Debug "-----"
			Write-Debug ("Key: "+$_)
			Write-Debug ("Label: "+$DataHash[$_].Label)
            Write-Debug ("Value: " + $DataHash[$_].Value)
            $xArray += $_
            $yArray += $DataHash[$_].Value
            $xyArray.Add($_, $DataHash[$_].Value)
        }

		# If the TimeLine variable is set, detect the first and last date in the x axis
		$FirstDate = $false
		$LastDate  = $false
		$Ticks     = $false
		if ($TimeLine) {
			Write-Debug "TimeLine is set. Will determine first and last time slots in x axis"
			Write-Debug "TimeLine flag is set. Will try to reorganize graph to display data correctly"
			$tmpSortedKeys = $DataHash.keys | Sort

			$FirstDate = $tmpSortedKeys | Select -First 1
			$LastDate = $tmpSortedKeys | Select -Last 1
			$TickResult = ((Get-Date $LastDate) - (Get-Date $FirstDate))
			if ($PSBoundParameters['Debug']) {
				$TickResult
			}

			$OptimalHigh = 300
			if ($TickResult.TotalDays -gt 1000) {
				$TimeLine = "Years"
			} elseif ( $TickResult.TotalDays -gt 140 ) {
				$TimeLine = "Months"
			} elseif ( $TickResult.TotalDays -gt 20 ) {
				$TimeLine = "Weeks"
			} elseif ( $TickResult.TotalDays -gt 5 ) {
				$TimeLine = "Days"
			} elseif ( $TickResult.TotalHours -gt 5 ) {
				$TimeLine = "Hours"
			} elseif ( $TickResult.TotalMinutes -gt 5 ) {
				$TimeLine = "Minutes"
			} elseif ( $TickResult.TotalSeconds -gt 5 ) {
				$TimeLine = "Seconds"
			} elseif ( $TickResult.TotalMilliseconds -gt 5 ) {
				$TimeLine = "Milliseconds"
			} else {
				$TimeLine = "Minutes"
			}



			# $LowestDiff = $false
			# "Days", "Hours", "Minutes", "Seconds", "Milliseconds" | Foreach-Object {
			# 	$flag = ("Total"+$_)
			# 	$flag
			# }

			switch ($TimeLine) {
				"Days" {
					"Days not implemented yet"
				}
				"Hours" {
					"Hours not implemented yet"
				}
				"Minutes" {
					"Minutes not implemented yet"
				}
				"Months" {
					"Months not implemented yet"
				}
				"Seconds" {
					"Seconds not implemented yet"
				}
				"Years" {
					"Years not implemented yet"
				}
				default {
					"Default is not implemented yet"
				}
			}
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
