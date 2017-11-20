param (
    [Parameter(Mandatory=$True, ValueFromPipeline=$True)] [Object]$InputObject
)

$String     = ($InputObject | Out-String)

$ci         = 0                  # Current Indentation. Used to keep track of where we are in the YAML file
$cispaces   = 4                  # How many spaces pr indentetion
$jsonspaces = 1
$counter    = 0
$splitArray = $String.Split("`n")

$Out       += (" "*($cispaces*$ci)) + "[`n"
$ci++
$Out       += (" "*($cispaces*$ci)) + "{`n"
$ci++

$js         = (" "*$jsonspaces)

Write-Host $String
$IndentArray = New-Object System.Collections.ArrayList
$ContentArray = $String.Split("`n")
$ContentArray  | % {

    # YAML element can contain either
    # String
    # Array (by using '-' prefix)
    # Multiline list (by using '|' argument)
    # Singleline as text group (by using '>' argument)

    $line   = $_.Split(':')
    $indent = ([regex]::matches(($line[0] -Replace "\s*$", "")," ").count)
    if ( $IndentArray.Count -eq 0 ) {
        $tmp = $IndentArray.Add($Indent)
    }
    $LastIndent = $IndentArray.Item(($IndentArray.Count)-1)
    if ( $Indent -gt $LastIndent ) {
        $tmp = $IndentArray.Add($Indent) 
    # } elseif ( $Indent -eq $LastIndent ) {
    } else {
        While ( $Indent -lt $LastIndent ) {
            $tmp = $IndentArray.RemoveAt(($IndentArray.Count)-1)
            $LastIndent = $IndentArray.Item(($IndentArray.Count)-1)
        }
    }
    if ( $_ -Match "^\s*\S+\s*:" ) {
        $Key = ([string]$indent+(" "*$indent)+'"'+($line[0].Trim())+'":')
        if ( $line[1].Trim() -Contains "|" ) {
            $BuildString = $Key + $js + '"'
            $BuildString += 'MAGIX HERE\n'
            $BuildString += '"'
            Write-Host ($BuildString)
        } elseif ( $line[1].Trim() -Contains ">" ) {
            $BuildString = $Key + $js + '"'
            $BuildString += 'MAGIX HERE\n'
            $BuildString += '"'
            Write-Host ($BuildString)
        } elseif ( $line[1].Trim().Length -eq 0 ) {
            # Check if the next line is an array (starting with '-') or just a collection of key/value pairs (normal 'word:' string)
            if ( $ContentArray.Count -ge ($Counter+1) ) {
                if ( $ContentArray[$Counter+1].Trim() -Match "^\-\s+") {
                    Write-Host ($Key + $js + '[' + "`n") # + $ContentArray[$Counter+1])
                } else {
                    Write-Host ($Key + $js + '{' + "`n") 
                }
            }
            
        } else {
            Write-Host ($Key + $js + '"' + $line[1].Trim() + '"')
        }
    }

























if ( $lkasf  ) {
        if ( $indent -gt ($spaces.length-($ci*$cispaces)) ) {
            # This line is indented from the previous one
            $ci++
        } elseif ( $indent -lt ($spaces.length-($ci*$cispaces))) {
        "askflkaslfk"
            $ci-- 
        }
        # $spaces = (" "*($ci*$cispaces)) + (" "*$indent)
        $spaces = (" "*($ci*$cispaces)) 
        $Key    = $spaces + '"'+$indent + ($line[0].Trim() -Replace "\s*:$", "") + '":'
        $line   = $line.Trim()
    
        if ( $line.Count -gt 1 ) {
            if ( $line[1].Trim() -Contains '|' ) {
                $Out        += $Key + (" "*$cispaces) + "{`n"
                $Out        += (" "*$spaces) + "}`n"
            } elseif ( $line[1].Trim() -Contains '>' ) {
                Write-Host "ALIGATOR"
            } else {
                $ValueString = ""
                for ($i = 1; $i -lt $line.count; $i++) {
                    $ValueString += $line[$i]
                }
                if ( $ValueString.Trim().Length -gt 0 ) {
                    $ValueString = '"' + $ValueString + '"'
                } else {
                    $ValueString = '{'
                }
                $Out        += $Key + (" "*$jsonspaces) + $ValueString + "`n"
            }
        }
    }

    $counter++
}

$ci--
$out        += (" "*($cispaces*$ci)) + "}`n"
$ci--
$out        += (" "*($cispaces*$ci)) + "]"

return $out



