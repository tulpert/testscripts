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
		[AllowNull()][ValidateSet("Auto", "Days", "Hours", "Minutes", "Months", "Seconds", "Weeks", "Years")][String]$TimeSpan = "Auto",
		[AllowNull()][ValidateSet("Bar", "Pie", "Line", "3DBar", "3DPie")][String]$Style = $null,
		[AllowNull()][Switch]$TimeLine,
		[AllowNull()][Switch]$HideEmpty,
        $Title = $false,
		[Int]$Width = 500,
		[Int]$Height = 400,
		[Int]$XAxisInterval = 1
    )
    
    Begin {

        if ($TimeSpan.length -eq 0) {
            Remove-Variable TimeSpan
        }

		if ($PSBoundParameters['Debug']) {
		    $DebugPreference = 'Continue'
        	$Debug = $true
		} else {
			$Debug = $false
		}
        $DataHash = New-Object hashtable
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
                $maxLength = 77
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

		# If the TimeSpan variable is set, detect the first and last date in the x axis
		$FirstDate  = $false
		$LastDate   = $false
		$Ticks      = $false
        $SortedKeys = $DataHash.Keys | Sort

		if ( $TimeSpan ) {
			Write-Debug "TimeSpan is set. Will determine first and last time slots in x axis"
			Write-Debug "TimeSpan flag is set. Will try to reorganize graph to display data correctly"

			$FirstDate = $SortedKeys | Select -First 1
			$LastDate  = $SortedKeys | Select -Last 1
            Write-Debug ("FirstDate: "+ $FirstDate)
            Write-Debug ("LastDate: " + $LastDate)
			$TickResult = ((Get-Date $LastDate) - (Get-Date $FirstDate))
			# if ($PSBoundParameters['Debug']) {
			# 	$TickResult
			# }

            if ( $TimeSpan -eq "Auto" ) {
		        $OptimalHigh = 45

		        if ($TickResult.TotalDays -gt (($OptimalHigh / 12) * 365)) {
		        	$TimeSpan = "Years"
		        } elseif ( $TickResult.TotalDays -gt (($OptimalHigh / 7) * 52) ) {
		        	$TimeSpan = "Months"
		        } elseif ( $TickResult.TotalDays -gt 20 ) {
		        	$TimeSpan = "Weeks"
		        } elseif ( $TickResult.TotalDays -gt 5 ) {
		        	$TimeSpan = "Days"
		        } elseif ( $TickResult.TotalHours -gt 5 ) {
		        	$TimeSpan = "Hours"
		        } elseif ( $TickResult.TotalMinutes -gt 5 ) {
		        	$TimeSpan = "Minutes"
		        } elseif ( $TickResult.TotalSeconds -gt 5 ) {
		        	$TimeSpan = "Seconds"
		        } elseif ( $TickResult.TotalMilliseconds -gt 5 ) {
		        	$TimeSpan = "Milliseconds"
		        } else {
		        	$TimeSpan = "Minutes"
		        }
				Write-Debug ("Autodetected resolution of: " + $TimeSpan)
            }
		}



        $xArray = @()
        $yArray = @()
        $xyArray = @{}
        $tmpLastDateTime = $false
        $PreviousKey = $false
        $PreviousIndex = 0
        $SortedKeys  | Foreach-Object {
            $OriginalKey = $_

		    switch ($TimeSpan) {
		    	"Days" {
					$TimeFormat = "ddd dd/MMM/yyyy"
                    $NewKey = Get-Date $OriginalKey -Format $TimeFormat
                    if ($LastWasNew) {
                        $TimeTicksHasPast = ((Get-Date $NewKey) - (Get-Date $PreviousKey)).Days
                        for ($i = 1; $i -lt $TimeTicksHasPast; $i++) {
                            $NextTimeSlot = (Get-Date $PreviousKey).AddDays($i)
							if ( $HideEmpty ) {
								$xArray += ""
							} else {
                            	$xArray += [string](Get-Date $NextTimeSlot -Format $TimeFormat)
							}
                            $yArray += 0
                        }
                    }
		    	}
		    	"Hours" {
					$TimeFormat = "ddd dd/MMM/yyyy HH:00"
                    $NewKey = Get-Date $OriginalKey -Format $TimeFormat
                    if ($LastWasNew) {
                        $TimeTicksHasPast = ((Get-Date $NewKey) - (Get-Date $PreviousKey)).Hours
                        for ($i = 1; $i -lt $TimeTicksHasPast; $i++) {
                            $NextTimeSlot = (Get-Date $PreviousKey).AddHours($i)
							if ( $HideEmpty ) {
								$xArray += ""
							} else {
                            	$xArray += [string](Get-Date $NextTimeSlot -Format $TimeFormat)
							}
                            $yArray += 0
                        }
                    }
		    	}
		    	"Minutes" {
					$TimeFormat = "ddd dd/MMM/yyyy HH:mm"
                    $NewKey = Get-Date $OriginalKey -Format $TimeFormat
                    if ($LastWasNew) {
                        $TimeTicksHasPast = ((Get-Date $NewKey) - (Get-Date $PreviousKey)).Minutes
                        for ($i = 1; $i -lt $TimeTicksHasPast; $i++) {
                            $NextTimeSlot = (Get-Date $PreviousKey).AddMinutes($i)
							if ( $HideEmpty ) {
								$xArray += ""
							} else {
                            	$xArray += [string](Get-Date $NextTimeSlot -Format $TimeFormat)
							}
                            $yArray += 0
                        }
                    }
		    	}
		    	"Months" {
					$TimeFormat = "MMM yyyy"
                    $NewKey = Get-Date $OriginalKey -Format $TimeFormat
                    if ($LastWasNew) {
                        $TimeTicksHasPast = ((Get-Date $NewKey) - (Get-Date $PreviousKey)).Month
                        for ($i = 1; $i -lt $TimeTicksHasPast; $i++) {
                            $NextTimeSlot = (Get-Date $PreviousKey).AddMonths($i)
							if ( $HideEmpty ) {
								$xArray += ""
							} else {
                            	$xArray += [string](Get-Date $NextTimeSlot -Format $TimeFormat)
							}
                            $yArray += 0
                        }
                    }
		    	}
		    	"Seconds" {
					$TimeFormat = "ddd dd/MMM/yyyy HH:mm:ss"
                    $NewKey = Get-Date $OriginalKey -Format $TimeFormat
                    if ($LastWasNew) {
                        $TimeTicksHasPast = ((Get-Date $NewKey) - (Get-Date $PreviousKey)).Seconds
                        for ($i = 1; $i -lt $TimeTicksHasPast; $i++) {
                            $NextTimeSlot = (Get-Date $PreviousKey).AddSeconds($i)
							if ( $HideEmpty ) {
								$xArray += ""
							} else {
                            	$xArray += [string](Get-Date $NextTimeSlot -Format $TimeFormat)
							}
                            $yArray += 0
                        }
                    }
		    	}
		    	"Years" {
					Write-Warning ("Year function has not been tested properly. Please verify results manually")
					$TimeFormat = "yyyy"
                    $NewKey = Get-Date $OriginalKey -Format $TimeFormat
                    if ($LastWasNew) {
                        $TimeTicksHasPast = ((Get-Date ("01/01/"+$NewKey)) - (Get-Date ("01/01/"+$PreviousKey))).Years
                        for ($i = 1; $i -lt $TimeTicksHasPast; $i++) {
                            $NextTimeSlot = (Get-Date $PreviousKey).AddYears($i)
							if ( $HideEmpty ) {
								$xArray += ""
							} else {
                            	$xArray += [string](Get-Date $NextTimeSlot -Format $TimeFormat)
							}
                            $yArray += 0
                        }
                    }
		    	}
		    	default {
		    		"Default is not implemented yet"
		    	}
		    }

            if ($NewKey -eq $PreviousKey) {
               $yArray[$PreviousIndex] += $DataHash[$OriginalKey].Value
            	$LastWasNew = $false
            } else {
				if ($TimeLine) {
                	$LastWasNew = $true
				}

              	$xArray += [string]$NewKey
              	$yArray += $DataHash[$OriginalKey].Value
              	$PreviousIndex = ($yArray.count -1)
              	$xyArray.Add($xArray, $yArray)
            }
            $PreviousKey = $NewKey
        }
		


        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
        
        # create chart object 
		$LeftMargin = 20
		$TopMargin = 30
        $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
        $Chart.Width = $Width
        $Chart.Height = $Height
        $Chart.Left = $LeftMargin	 
        $Chart.Top = ($TopMargin /2)
		$Chart.BackColor = [System.Drawing.Color]::Transparent
        


        # create a chartarea to draw on and add to chart 
        $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 
		$ChartArea.Name = "AutoGraph"

        $Chart.ChartAreas.Add($ChartArea)
        
        # add data to chart 
        [void]$Chart.Series.Add("Data") 

        $Chart.Series["Data"].Points.DataBindXY($xArray, $yArray)
        # $Chart.Series["Data"].Points.DataBindXY($xyArray.Keys, $xyArray.Values)
        
		if ($Style) {
		
			Switch ($Style) {
				"Line" {
					$Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
				}
				"3DBar" {
		  			$Chart.Series["Data"]["DrawingStyle"] = "Cylinder"
				}
				"Pie" {
					$Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
				}
				"3DPie" {
					$Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
					$Chart.Series["Data"]["PieLabelStyle"] = "Outside" 
					$Chart.Series["Data"]["PieLineColor"] = "Black" 
					$Chart.Series["Data"]["PieDrawingStyle"] = "Concave" 
					# ($Chart.Series["Data"].Points.FindMaxByValue())["Exploded"] = $true
				}
				default {
					# Default is standard bar chart
				}
			}
		
		}

		$Chart.ChartAreas[0].AxisX.Interval=[int]$XAxisInterval
		$Chart.ChartAreas[0].AxisX.MajorGrid.LineDashStyle = "NotSet"
		$Chart.ChartAreas[0].AxisY.MajorGrid.LineColor = "LightGray"

        # display the chart on a form 
        $Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor 
        [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left 
        $Form = New-Object Windows.Forms.Form 
        $Form.Text = "PowerShell Chart" 
        $Form.Width = ($Width + ($LeftMargin *2))
        $Form.Height = ($Height + ($TopMargin * 2))
        $Form.controls.add($Chart) 
        $Form.Add_Shown({$Form.Activate()}) 
        $Form.ShowDialog()

   # $Chart
    }
#}
