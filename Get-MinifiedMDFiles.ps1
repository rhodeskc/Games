param([string]$VaultLocation = "$PSScriptRoot")

Push-Location "$VaultLocation"
Write-Host "Before starting, make sure all files have been committed to repo just in case"
Read-Host -Prompt "Press enter to continue..."

# ms
$WaitTime = 50

$FileList = gci -Recurse -Filter *.md
Pop-Location

<#
If there are three LF's in a row, repeatedly replace them with just 2.
#>
function Remove-ExcessLFs($FullName) {
    $fore = "green"
    $oldCorrectedText = [IO.File]::ReadAllText($FullName)
    $CorrectedText = $oldCorrectedText -replace "`r`n", "`n"
    
    # File was touched to Unix format
    if( $oldCorrectedText -ne $CorrectedText ) {
        $fore = "yellow"
    }
    
    $oldCorrectedText = $CorrectedText
    $CorrectedText = $CorrectedText -replace  "`n`n`n", "`n`n"
    # File was stripped to no excess entries
    while( $oldCorrectedText -ne $CorrectedText) {
        # Repeat step until unchanging
        $oldCorrectedText = $CorrectedText
        $CorrectedText = $CorrectedText -replace "`n`n`n", "`n`n"
        $fore = "red"
    }
    
    # Write and output result.
    Start-Sleep -m $WaitTime
    [IO.File]::WriteAllText($FullName, $CorrectedText)
    Write-Host $FullName -fore $fore
}

<#
If the header is followed by a LF, remove that LF.
#>
function Correct-HeaderFormatting($FullName) {
    $FileContents = Get-Content $FullName
    $MaxIndex = $FileContents.Length-1
    $LineIndex = 0
    
    $NewFileContents = @()
    while($LineIndex -le $MaxIndex) {
        $ThisLine = $FileContents[$LineIndex]
        
        # Only process any lines starting with a # sign
        if( $ThisLine -match "^#" ){
            $NextLineIndex = $LineIndex + 1
            $NextLine = $FileContents[$NextLineIndex]
            
            while($NextLine -eq "" -and ($NextLineIndex -le $MaxIndex))
            {
                $NextLineIndex++
                $NextLine = $FileContents[$NextLineIndex]
            }
            
            # Advance next line pointer until a non-LF line is found or EOF. Should be just one additional line.
            # then reset pointer to that point.
            $NewFileContents += $ThisLine
            $NewFileContents += ""
            $LineIndex = $NextLineIndex
        }
        else {
            $NewFileContents += $ThisLine
            
            # Move pointer
            $LineIndex++
        }
    }
    
    Start-Sleep -m $WaitTime
    $NewFileContents | Set-Content -Path $FullName -Force
}

<#
If the navigational "Up" has a blank line above it, remove the lines until you get to a non-blank line.
#>
function Compress-UpLineToTop($FullName) {
    $UpLineMatch = Select-String -Path $FullName -Pattern "Up:" 
   
    if( $UpLineMatch ) {
        # Select string is 1 based, Get-Content is 0 based
        $OriginalLineNum = ($UpLineMatch | Select-Object -First 1 -ExpandProperty LineNumber) - 1
        $PrevLineNumber = $OriginalLineNum - 1
        if( ($PrevLineNumber ) -ge 0) {
            $FileContents = Get-Content $FullName
            
            while(($FileContents[$PrevLineNumber] -eq "") -and $PrevLineNumber -ge 0){
                $PrevLineNumber--
            }
        }
        
        $NewFileContents = @()
        $NewFileContents += $FileContents[0..$PrevLineNumber]
        $NewFileContents += $FileContents[$OriginalLineNum..($FileContents.Length-1)]
        
        Start-Sleep -m $WaitTime
        $NewFileContents | Set-Content -Path $FullName -Force
    }
    
}

function Compress-PreviousNextLinks($FullName) {
    $PreviousLineMatch = Select-String -Path $FullName -Pattern "\**Previous:\** *$"
    $NextLineMatch = Select-String -Path $FullName -Pattern "\**Next:\** *$"
    
    if( $PreviousLineMatch -Or $NextLineMatch ) {
        $FileContents = Get-Content $FullName
        $NewFileContents = 1..($FileContents.Count) | 
            ?{ $_ -ne $PreviousLineMatch.LineNumber -and 
                $_ -ne $NextLineMatch.LineNumber } | 
            %{ $_ - 1 } |
            %{ $FileContents[$_] }
        
        Start-Sleep -m $WaitTime
        $NewFileContents | Set-Content -Path $FullName -Force
    }
}

function Set-EOLtoUnix($FullName) {
    # Have to do this to convert it to LF due to Powershell limitations
    Start-Sleep -m $WaitTime
    $CorrectedText = [IO.File]::ReadAllText($FullName) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($FullName, $CorrectedText)
}

$FileList | %{
    Remove-ExcessLFs -FullName $_.FullName
    Compress-UpLineToTop -FullName $_.FullName
    Compress-PreviousNextLinks -FullName $_.FullName
    Correct-HeaderFormatting -FullName $_.FullName
    Set-EOLtoUnix -FullName $_.FullName
}
