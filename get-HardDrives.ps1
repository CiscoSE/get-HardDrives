#$AuthToken = (Invoke-WebRequest -uri https://10.83.16.90/redfish/v1/SessionService/Sessions -SkipCertificateCheck -Method Post -ContentType 'application/json; charset=utf-8' -body '{"UserName": "admin", "Password": "password"}').headers.'X-Auth-Token'
#$Headers = @{'Authorization' = $($AuthToken)#}
#$headers
#Invoke-WebRequest -uri https://10.83.16.90/redfish/v1/managers -Method Get -headers $Headers -verbose
[cmdletbinding()]
param(
    [parameter(mandatory=$false)][string]$Server = '10.83.16.90'
)
function get-rest {
    param(
        [parameter(mandatory=$true)][string]$uri,
        [parameter(mandatory=$false)][string]$method = 'Get',
        [parameter(mandatory=$true)][PSCredential]$MyCred
    )
    begin {}
    process{
        Invoke-RestMethod -method $Method -Authentication Basic -SkipCertificateCheck -Credential $MyCred -uri $URI
    }

}
Function get-SystemElements {
    param(
        $SystemPaths,
        $MyCred,
        $baseURI
    )
    begin {
        Write-Verbose "BaseURI: $BaseURI"
        Write-Verbose "System Paths: $SystemPaths"
    }
    process{
        $SystemResult = get-rest -MyCred $MyCred -uri "$($baseURI)$($SystemPaths)"
        ForEach ($System in $SystemResult.members ){
            $SystemElements = get-rest -MyCred $MyCred -uri "$($baseURI)$($System.'@odata.id')"
            forEach ($Element in $SystemElements.Storage){
                if ($element.'@odata.id') {
                    get-StorageElements -MyCred $MyCred -baseUri $baseURI -StoragePaths $Element.'@odata.id'

                }
            }

        }
    }
}

Function get-StorageElements {
    param (
        $StoragePaths,
        $MyCred,
        $baseURI
    )
    begin{
        write-Verbose "Storage Path: $StoragePaths"
    }
    process{
        $StorageElements = get-rest -MyCred $MyCred -uri "$($baseURI)$($StoragePaths)"
        forEach ($element in $StorageElements.Members) {
            get-StorageController -MyCred $MyCred -baseURI $BaseURI -StorageController $element.'@odata.id'

        }

    }
}

function get-StorageController {
    param(
        $StorageController,
        $MyCred,
        $baseURI
    )
    begin{
        write-verbose "Storage Controller: $StorageController"
    }
    process{
        $StorageController = get-rest -MyCred $MyCred -uri "$($baseURI)$($StorageController)"
        foreach ($Element in $StorageController.Drives){
            get-DiskElements -myCred $MyCred -baseURI $baseURI -DiskPaths $Element.'@odata.id'
        }
    }
}

Function get-DiskElements {
    param(
        $DiskPaths,
        $MyCred,
        $baseURI
    )
    begin{
        write-verbose "Disk Path: $DiskPaths"
    }
    process{
        get-rest -MyCred $MyCred -uri "$($baseURI)$($DiskPaths)"
    }
}

#If Credentials already exist, we don't need to get them.
if (-not($MyCred)){
    $MyCred = (Get-Credential)
}

# Key Variables.
$baseURI = "https://$($server)"

Get-SystemElements -MyCred $MyCred -baseURI $baseURI -SystemPaths "/redfish/v1/Systems"

#$URI = "$($baseURI)/redfish/v1/Systems"
#$SystemURI = ((get-rest -uri $URI -MyCred $MyCred).Members)

#ForEach ($System in $SystemURI){
#   (get-rest -uri "https://$($server)$($System.'@odata.id')/Storage" -MyCred $MyCred)
  
#}



#$URI = "https://10.83.16.90/redfish/v1/Systems/WZP22040XQK/Storage/MRAID"
#$DriveList = (get-rest -uri $URI -MyCred $MyCred | select Drives)
#$DriveList.Drives | %{
#    $URI = "https://10.82.16.90/redfish/v1/Systems/"
#}
