[cmdletbinding()]
param(
    [parameter(mandatory=$true)][array]$CimcIPs,
    [parameter(mandatory=$true)][pscredential]$Cred
)

Function get-CIMC {
    param(
        [string]$CimcIP,
        [pscredential]$cred
    )
    $DiskList = ''
    $connect = connect-imc $CimcIP -Credential $cred -ErrorAction SilentlyContinue
    if ($DefaultIMC) {
        $ConnectionStatus = $true
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

#Initialize report variables 
$FullDiskReportIndex = ''
$FullDiskReport = ''

#TODO We should allow import of system IPs or names from a CSV file or from the command line... Check each and make sure we loop through either or both if they exist.


#Loop through servers.
forEach ($IP in $CimcIPs) {
    if ($DiskList) {Remove-Variable DiskList}
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


