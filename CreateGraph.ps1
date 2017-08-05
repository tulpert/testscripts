Function CreateGraph {
    Param (
        $xArray = $false,
        $yArray = $false,
        $xyArray = $false,
        $Title = $false
        )

    if ($xyArray) {
        # Do sanity check of xyArray
    } elseif ($true) {
        $xyArray = New-Object hashtable
        if ($xArray.length -eq $yArray.length) {
            for ($i = 0; $i -lt $xArray.length; $i++) {
                $xyArray.Add($xArray[$i], $yArray[$i])
            }
        } else {
            Write-Warning "X and Y Axis are of different length. Cannot continue with graph."
            return 0
        }
    }

    # load the appropriate assemblies 
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
    Try {
        $Chart.Series["Data"].Points.DataBindXY($xyArray.Keys, $xyArray.Values)
        $Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor 
                    [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left 
        $Form = New-Object Windows.Forms.Form 
    } catch {
            # Write-Error "Some error has occured"
    }
    if ($Title) {
        $Form.Text = $Title
    } else {
        $Form.Text = "Graph"
    } 
    $Chart.
    $Form.Width = 600 
    $Form.Height = 600 
    $Form.controls.add($Chart) 
    $Form.Add_Shown({$Form.Activate()}) 
    $Form.ShowDialog()
}