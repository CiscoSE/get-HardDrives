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
    $Result = connect-imc $CimcIP -Credential $cred
    $DiskList = Get-ImcPidCataloghdd |
       Select `
            @{Name='Server';          Expression={$DefaultImc.Name}},
            @{Name='Server Model';    Expression={$DefaultImc.Model}},
            @{Name='Server Firmware'; Expression={$DefaultImc.Version}},
            @{Name='Disk Controller'; Expression={$_.Controller}},
            @{Name='Drive Model';     Expression={$_.Model}},
            @{Name='Drive#';          Expression={$_.Disk}},
            @{Name='Drive Vendor';    Expression={$_.Vendor}},
            @{Name='Drive Serial#';   Expression={$_.SerialNumber}}

    $DiskList | ft -AutoSize
    disconnect-imc
}



#To avoid errors later, we disconnect the IMC before we do anything else
if ($DefaultImc){
    disconnect-imc
}

forEach ($IP in $CimcIPs) {
    
    get-CIMC -CimcIP $IP -Cred $Cred

}

