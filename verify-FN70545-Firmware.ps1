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
This can be an IP or resolvable name. You can provide more then one server using
this option by including multiple names or IPs separated by commas. Do not 
include any spaces between systems.

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
PowerShell was in when you ran the script. We check for the presense of that folder
and create it if it does not already exist.
#>


[cmdletbinding()]
param(
    [parameter(mandatory=$false)][array]$CimcIPs,
    [parameter(mandatory=$true)][pscredential]$Cred,
    [parameter(mandatory=$false)][string]$InventoryReportDir = "./Report/"
)
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

Function get-CIMC {
    param(
        [string]$CimcIP,
        [pscredential]$cred
    )
    $DiskList = ''
    $connect = connect-imc $CimcIP -Credential $cred -ErrorAction SilentlyContinue
    if ($DefaultIMC) {
        $ConnectionStatus = $true
        write-screen -type INFO -message "`tConnection Established to $($DefaultIMC.Name)"
            $DiskList = Get-ImcPidCataloghdd |
               Select `
                    @{Name='Server';             Expression={$DefaultImc.Name}},
                    @{Name='Server Model';       Expression={$DefaultImc.Model}},
                    @{Name='Server Firmware';    Expression={$DefaultImc.Version}},
                    @{Name='Disk Controller';    Expression={$_.Controller}},
                    @{Name='Cisco Product ID';   Expression={$_.Pid}},
                    @{Name='Vendor Drive Model'; Expression={$_.Model}},
                    @{Name='Drive#';             Expression={$_.Disk}},
                    @{Name='Drive Vendor';       Expression={$_.Vendor}},
                    @{Name='Drive Serial#';      Expression={$_.SerialNumber}}
        $Disconnect = disconnect-imc
    }
    else{
        $ConnectionStatus = $False
        write-screen -type WARN -message "Failed to connect to $($CimcIP)"
    }

    return $ConnectionStatus, $DiskList
    
}

function evaluate-disks {
    param(
        $DiskList
    )
    begin{}
    process{
        
    }

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

#Initialize report variables 
$FullDiskReportIndex = ''
$FullDiskReport = ''

#TODO We should allow import of system IPs or names from a CSV file or from the command line... Check each and make sure we loop through either or both if they exist.


#Loop through servers.
forEach ($IP in $CimcIPs) {
    if ($DiskList) {Remove-Variable DiskList}
    write-screen -type INFO -message "Reviewing $IP Disks"
    $ConnectionStatus, $DiskList = get-CIMC -CimcIP $IP -Cred $Cred
    if ($ConnectionStatus = $True ) {
        $FullDiskReportIndex += "<H3><a href='#$($IP)'>$($IP)</a></h3>"
        $FullDiskReport += $DiskList | 
            ConvertTo-Html -as Table -Fragment -PreContent "<H2 id='$($IP)'>$IP Report</H2>"
    }
    Else {
        Write-Host -ForegroundColor Red "Unable to connect to $($CimcIPs)"
    }
    #TODO Produce report of systems that could not be reviewed because they were not accessible or returned no disks. 

}
$FullDiskReportIndex
convertto-html -head $CSS -Body ($FullDiskReportIndex + $FullDiskReport) -Title "Disk Report" | out-file ./TestReport.html


