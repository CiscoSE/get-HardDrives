<#
.NOTES
Copyright (c) 2019 Cisco and/or its affiliates.
This software is licensed to you under the terms of the Cisco Sample
Code License, Version 1.0 (the "License"). You may obtain a copy of the
License at
               https://developer.cisco.com/docs/licenses
All use of the material herein must be in accordance with the terms of
the License. All rights not expressly granted by the License are
reserved. Unless required by applicable law or agreed to separately in
writing, software distributed under the License is distributed on an "AS
IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
or implied.

.PARAMETER CimcIPs
This can be an IP or resolvable name for a Cisco Integerated Management Controller.
You can provide more then one server using this option by including multiple names 
or IPs separated by commas. Do not include any spaces between systems.

If you do not include this variable, you must include a path to a CSV.

.PARAMETER Cred
If you already have a PSCredential object with the user name and password, 
you can pass that using this variable. This is mostly used for developement
so I don't have to keep typing the user name and password every time I run
the script.

All servers to be assessed by this script must use the same user name and password
for access to the CIMC in order for this script to work.

If you do not provide this information as an argument, it will be requested
automatically.

.PARAMETER InventoryReportDir
By default this will create a directory named Report as a subdirectory of the folder
PowerShell was in when you ran the script. We check for the presence of that folder
and create it if it does not already exist.

.PARAMETER CSVFile
Allows for a CSV File to be provided. The only column that matters in the CSV is the
"Server" column. Any others will ignored. The Server column must contain a Ip 
address or a resolvable name to the CIMC of the server. 

.EXAMPLE
./verify-FN70545-Firmware.ps1 -CimcIPs 1.1.1.1

Get drive properties from a single stand-alone server where 1.1.1.1 is the IP address of
the CIMC for that server.

.EXAMPLE
./verify-FN70545-Firmware.ps1 -CimcIPs 1.1.1.1,1.1.1.2

Get drive properties from a two stand-alone servers where 1.1.1.1 and 1.1.1.2 are the IP addresses of
the CIMCs for those servers.

.EXAMPLE
./verify-FN70545-Firmware.ps1 -CVSFile ./ServerList.csv

Get drive information for all servers listed in the Serverlist.csv file.

.EXAMPLE
./verify-FN70545-Firmware.ps1 -CVSFile ./ServerList.csv -CimcIPs 1.1.1.1,1.1.1.2

Get drive information for all servers in the CSV, and also from 1.1.1.1 and 1.1.1.2

#>
[cmdletbinding()]
param(
    [parameter(mandatory=$false)][array]$CimcIPs,
    [parameter(mandatory=$true)][pscredential]$Cred,
    [parameter(mandatory=$false)][string]$InventoryReportDir = "./Report/",
    [parameter(mandatory=$false)][string]$CSVFile
)

#Built as XML object so that GoodFirmware can have many disks with many firmware.
$Global:ImpactedDiskModelList = [XML]'
<Disks>
    <Disk Name="SDLTODKM-400G-5CC1">
        <GoodFirmwareVersion>C405</GoodFirmwareVersion>
    </Disk>
    <Disk Name="SDLTODKM-016T-5CC1">
        <GoodFirmwareVersion>C405</GoodFirmwareVersion>
    </Disk>
</Disks>
'

$ErrorActionPreference = 'Continue'  #Other actions: Stop or SilentlyContinue

function write-screen {
    param(
        [parameter(mandatory=$false,position=0)]
            [ValidatePattern("INFO|FAIL|WARN")]
                                               [string]$type = "INFO",
        [parameter(mandatory=$true,Position=1)][string]$message
     )
    switch($type){
        "INFO" {$Color = "Green";  break}
        "FAIL" {$Color = "RED";    break}
        "WARN" {$Color = "Yellow"; break}
    }
    write-host " [ " -NoNewline
    write-host $type -ForegroundColor $color -NoNewline
    write-host " ]     " -NoNewline
    write-host $message
    if ($type -eq "FAIL") {
        exit
    }    
}

function validateDirectory {
    param(
        [parameter(mandatory=$true)][string]$Directory
    )
    begin {
        write-screen -type INFO -message "Checking $Directory Exists"
    }
    process{
        $error.clear()
        if ( -not (test-path $directory)){
            $result = md $directory
            if ($error[0]){
                write-screen -type WARN -message "Directory $Directory does not exist and could not be created"
                Write-screen -type FAIL -message "Directory $Directory must be created and writable to continue."
            }
            else{
                Write-screen -type INFO -message "Directory $Directory created"
            }
        }
        else{
            Write-Screen -type INFO -message "$Directory Directory Exists"
        }
    }
}

Function format-path {
    param(
        [parameter(mandatory=$true)][string]$FilePath,
        [parameter(mandatory=$true)][string]$FileName
    )
    begin{
        Write-Verbose "FilePath: $($FilePath)"
        Write-Verbose "FileName: $($FileName)"
    }
    process{
        if ($FilePath -match "\$"){
            return ($FilePath + $FileName)
        }
        Else{
            
            return ($FilePath + "\" + $FileName)
    
        }
    }
}

Function get-CIMC {
    param(
        [string]$CimcIP,
        [pscredential]$cred
    )

    $connect = connect-imc $CimcIP -Credential $cred -ErrorAction SilentlyContinue
    
    if ($DefaultIMC) {
        $ConnectionStatus = $true
        write-screen -type INFO -message "`tConnection Established to $($DefaultIMC.Name)"
        $DiskList = Get-ImcStorageLocalDisk
        $Catalog = @{}
        Get-ImcPidCatalogHdd | %{$catalog[$_.Disk]=$_}
        $DiskArray = [System.Collections.ArrayList]@()
        forEach ($Disk in $DiskList){
            $Disk | add-Member NoteProperty -Name "Server"      -Value $DefaultIMC.Name
            $Disk | add-Member NoteProperty -Name "Model"       -Value $DefaultIMC.Model
            $Disk | Add-Member NoteProperty -Name "Version"     -Value $DefaultIMC.Version
            $Disk | Add-Member NoteProperty -Name "Pid"         -Value $Catalog[$Disk.Id].Pid
            $Disk | Add-Member NoteProperty -Name "Description" -Value $Catalog[$Disk.Id].Description
            $Disk | Add-Member NoteProperty -Name "Controller"  -Value $Catalog[$Disk.Id].Controller
            $DiskArray.add($Disk) | Out-Null
        }
      
        $Disconnect = disconnect-imc
    }
    else{
        $ConnectionStatus = $False
        write-screen -type WARN -message "Failed to connect to $($CimcIP)"
    }
    
    return $ConnectionStatus, ($DiskArray|
        Select `
         @{Name='Server';             Expression={$_.Server}},
         @{Name='Server Model';       Expression={$_.Model}},
         @{Name='Server Firmware';    Expression={$_.Version}},
         @{Name='Description';        Expression={$_.Description}},
         @{Name='Disk Controller';    Expression={$_.Controller}},
         @{Name='Cisco Product ID';   Expression={$_.Pid}},
         @{Name='Vendor Drive Model'; Expression={$_.ProductId}},
         @{Name='Drive#';             Expression={$_.Id}},
         @{Name='Drive Vendor';       Expression={$_.Vendor}},
         @{Name='Drive Serial#';      Expression={$_.DriveSerialNumber}},
         @{Name='Drive Firmware';     Expression={$_.DriveFirmware}}
        )
}

function evaluate-disks {
    param(
        $DiskList
    )
    begin{
        Write-Verbose "Reviewing Disk List"
    }
    process{
        Foreach ($Disk in $DiskList){
            write-screen -type INFO -message "`t`tEvaluating $($Disk.'Vendor Drive Model')"
            $Impacted = $false
            forEach ($ImpactedDisk in $Global:ImpactedDiskModelList.Disks.Disk){
                $FirmwareFound = $False
                Write-Verbose "Checking for Disk: $($ImpactedDisk.Name)"
                Write-Verbose "Disk we are checking: $($Disk.'Vendor Drive Model')"
                If ($Disk.'Vendor Drive Model' -match $ImpactedDisk.Name){
                    $Impacted = $True
                    #Check Firmware Version
                    ForEach ($Firmware in $ImpactedDisk.GoodFirmwareVersion){
                        write-Verbose "Good Firmware we are looking for: $($Firmware)"
                        Write-Verbose "Firmware on the drive: $($Disk.'Drive Firmware')"
                        If ($Firmware -eq $Disk.'Drive Firmware'){
                            $FirmwareFound = $True
                            write-screen -type INFO -message "`t`t`tFirmware is a known good release - Firmware Found: $($Firmware)"
                        }
                    }
                }
            }
            if ($Impacted -eq $True){write-screen -type INFO -message "`t`t`tThis disk is an impacted model"}

            If ($impacted -eq $false){
                write-Screen -type INFO -message "`t`t`tDisk is not impacted by this field notice"
            }
            if ($impacted -eq $True -and $FirmwareFound -eq $False){
                write-screen -type WARN -message "`t`t`tA firmware update review for this disk is highly recommended"
                [array]$returnReport += $Disk
            }
        }
        if ($returnReport){
            return $true, $ReturnReport
        }
        else{
            return $False, ''
        }
    }

}

Function get-ServerList{
    Param(
        [parameter(Mandatory=$True)][string]$CSVFile
    )
    if (test-path $CSVFile){
        write-screen -type INFO "CSV File $($CSVFile) found."
        $Content = (get-content $CSVFile | Convertfrom-Csv).server
        If ($Content.count -gt 0){
            Return $Content
        } 
    }
    else{
        write-screen -type WARN "CSV File $($CSVFile) not found."
    }
    return
}

#Used for formatting in reports.
$CSS = @"
    <Title>Memory Error TAC Report</Title>
    <Style type='text/css'>
    SrvProp{
        boarder:20pt;
    }
    td, th { border:0px solid black; 
         border-collapse:collapse;
         white-space:pre; }
    th { color:white;
     background-color:black; }
    table, tr, td, th { padding: 2px; margin: 0px ;white-space:pre; }
    tr:nth-child(odd) {background-color: lightgray}
    table { width:95%;margin-left:5px; margin-bottom:20px;}
    </Style>
"@

#To avoid errors later, we disconnect the IMC before we do anything else
if ($DefaultImc){
    disconnect-imc
}

#Validate Report Directories Exist
validateDirectory -Directory $InventoryReportDir

#Get Date Time Stamp for Reports
$datetime = get-date -format yyyyMMdd-HHmmss
$FullDiskReportFileName = "$($datetime)-FullDiskReport.html"
$ImpactedDiskReportFileName ="$($datetime)-ImpactedDiskReport.html"

#Initialize report variables 
$FullDiskReportIndex = ''
$FullDiskReport = ''
$FullDiskReportFullPath = "$(format-path -FilePath $InventoryReportDir -FileName $FullDiskReportFileName)"

$ImpactedDiskResultIndex = ''
$ImpactedDiskReport =''
$ImpactedDiskReportFullPath = "$(format-path -FilePath $InventoryReportDir -FileName $ImpactedDiskReportFileName)"


if ($CimcIPs.count -gt 0){
    [array]$CIMCList += $CimcIPs
} 
If ($CSVFile){
    [array]$CIMCList += (get-ServerList -CSVFile $CSVFile)
}

if ($CIMCList -eq $null){
    write-screen -type FAIL -message "No machines recieved in the list to process"
}
Function formatReportData{
    param(
    [parameter(mandatory=$true)]$DiskList,
    [parameter(mandatory=$true)][string]$PreContent
    )
    return ($DiskList | select `
        'Description',
        'Disk Controller', 
        'Cisco Product ID', 
        'Vendor Drive Model', 
        'Drive#', 
        'Drive Vendor', 
        'Drive Serial#', 
        'Drive Firmware' |
            ConvertTo-Html -as table -fragment -PreContent ($PreContent -replace "<table>","<table style='width:50%'>"))

}
#Loop through servers.
forEach ($IP in $CimcList) {
    if ($DiskList) {Remove-Variable DiskList}
    write-screen -type INFO -message "Reviewing $IP Disks"
    $ConnectionStatus, $DiskList = get-CIMC -CimcIP $IP -Cred $Cred
    if ($ConnectionStatus = $True ) {
        $ServerPropertyHTML = $DiskList | select Server, 'Server Model', 'Server Firmware' -first 1 |
            ConvertTo-Html -as List -Fragment
        $IndexLine = "<H3><a href='#$($IP)'>$($IP)</a></h3>"
        $PreContentDeviceInfo = "<H2 id='$($IP)'>$IP Report</H2>$($ServerPropertyHTML)"
        $FullDiskReportIndex += $IndexLine
        $FullDiskReport += (formatReportData -DiskList $DiskList -PreContent $PreContentDeviceInfo)
        if ($DiskList -ne '') {
            $DiskEvaluationResult, $DiskEvaluationReport = evaluate-disks -DiskList $DiskList
            if ($DiskEvaluationResult){
                $ImpactedDiskResultIndex += $IndexLine
                $ImpactedDiskReport += (formatReportData -DiskList $DiskEvaluationReport -PreContent "$($PreContentDeviceInfo)")
            }
        }
    }
}

convertto-html -head $CSS -Body ($FullDiskReportIndex + $FullDiskReport)             -Title "Full Disk Report"     | out-file $FullDiskReportFullPath
if ($ImpactedDiskReport) {
    convertto-html -head $css -Body ($ImpactedDiskResultIndex + $ImpactedDiskReport) -Title "Impacted Disk Report" | out-file $ImpactedDiskReportFullPath
}

