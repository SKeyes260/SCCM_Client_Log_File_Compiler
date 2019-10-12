
# SCCM Client Log File Parser
# Copy this script to the CCM\Logs folder and run it
Param(
    [string]$ClientLogsFolder,
    [string]$SiteServer,   #fqdn
    [string]$SiteCode, 
    [string]$SQLServer, 
    [string]$SQLDBName , 
    [string]$DateStart,  
    [string]$InstanceName
) 

Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "LOG (*.log)| *.log"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

Function Log-Append () {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLogFileName,
    [Parameter(Position=2)] $strLogText )
    
    $Result = Out-File -InputObject $strLogText.ToString() -FilePath $strLogFileName -Append -NoClobber
}


Function Invoke-SQL {
PARAM(
     [Parameter(Position=1)] $SQLServer,
     [Parameter(Position=2)] $SQLDBName,
     [Parameter(Position=3)] $SQLSelect 
)

    $connectionString = "Data Source=$SQLServer; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$SQLDBName"

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($SQLSelect,$connection)
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    $dataSet.Tables

}


Function Get-LogText() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 

    If ( $strLine.IndexOf('<![LOG[') -eq -1  -AND $strLine.IndexOf(']LOG]!>' ) -eq -1 ) { $strLine }

    If ( $strLine.IndexOf('<![LOG[') -ne -1  -AND $strLine.IndexOf(']LOG]!>' ) -ne -1 ) { $strLine.Substring( $strLine.IndexOf('<![LOG[')+7, $strLine.IndexOf(']LOG]!>',0) -7 ) }
    
    If ( $strLine.IndexOf('<![LOG[') -ne -1  -AND $strLine.IndexOf(']LOG]!>' ) -eq -1 ) { $strLine.Substring( $strLine.IndexOf('<![LOG[',0) +7, $strLine.Length - $strLine.IndexOf('<![LOG[',0)-7 ) }

    If ( $strLine.IndexOf('<![LOG[') -eq -1  -AND $strLine.IndexOf(']LOG]!>' ) -ne -1 ) { $strLine.Substring( 0, $strLine.IndexOf(']LOG]!>',0) ) }

}


Function Get-LogTime() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 
    
   If ( $strLine.IndexOf('time="') -ne -1 ) {   
    $LogTime = $strLine.Substring( $strLine.IndexOf('time="')+6, $strLine.IndexOf('"',$strLine.IndexOf('time="')+6)  - $strLine.IndexOf('time="')-6) 
    $global:LastLogTime = $LogTime
    $LogTime
    } Else { $global:LastLogTime }
}


Function Get-LogDate() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 
    If ( $strLine.IndexOf('date="') -ne -1 ) {
        $LogDate = $strLine.Substring( $strLine.IndexOf('date="')+6, $strLine.IndexOf('"',$strLine.IndexOf('date="')+6)  - $strLine.IndexOf('date="')-6)
        $global:LastLogDate = $LogDate
        $LogDate
    } Else { $global:LastLogDate }
}

Function Get-LogComponent() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 
    If ( $strLine.IndexOf('component="') -ne -1 ) {
        $LogComponent = $strLine.Substring( $strLine.IndexOf('component="')+11, $strLine.IndexOf('"',$strLine.IndexOf('component="')+11)  - $strLine.IndexOf('component="')-11)
        $global:LastLogComponent = $LogComponent
        $LogComponent
    } Else { $global:LastLogComponent }
}


Function Get-LogContext() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 
    If ( $strLine.IndexOf('context="') -ne -1 ) {
        $strLine.Substring( $strLine.IndexOf('context="')+9, $strLine.IndexOf('"',$strLine.IndexOf('context="')+9)  - $strLine.IndexOf('context="')-9)
    }
    Else { 'Null' }
    
}


Function Get-LogType() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 
    If ( $strLine.IndexOf('type="') -ne -1 ) {
        $strLine.Substring( $strLine.IndexOf('type="')+6, $strLine.IndexOf('"',$strLine.IndexOf('type="')+6)  - $strLine.IndexOf('type="')-6)
    }
    Else { 'Null' }
}


Function Get-LogThread() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 
    If ( $strLine.IndexOf('thread="') -ne -1 ) {
        $LogThread = $strLine.Substring( $strLine.IndexOf('thread="')+8, $strLine.IndexOf('"',$strLine.IndexOf('thread="')+8)  - $strLine.IndexOf('thread="')-8) 
        $global:LastLogThread = $LogThread
        $LogThread
    } Else { $global:LastLogThread }
}


Function Get-LogFile() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 
    If ( $strLine.IndexOf('file="') -ne -1 ) {
        $strLine.Substring( $strLine.IndexOf('file="')+6, $strLine.IndexOf('"',$strLine.IndexOf('file="')+6)  - $strLine.IndexOf('file="')-6)
    }
    Else { 'Null' }
}


Function Parse-LogLine() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   ) 

    If ( $strLine.IndexOf('date="') -eq -1 ) { 
        $LogDate = $global:LastLogDate
        $LogTime = $global:LastLogTime
    }
    Else {
        $LogDate      = Get-LogDate  $strLine
        $LogTime      = Get-LogTime  $strLine
    }
    $global:LastLogDate = $LogDate
    $global:LastLogTime = $LogTime
    $LogDateTime  = Get-date ($Logdate + " " + $LogTime.SubString(0,8))  -Format "yyyy-MM-dd hh:mm:ss.fff" 
     
    If ( (Get-Date($LogDate)) -ge (Get-date($global:DateStart)) )  { 
        $LogText      = Get-LogText      $strLine
        $LogComponent = Get-LogComponent $strLine
        If (!$LogContext) { $LogContext = 'Null' }     
        $LogType      = Get-LogType      $strLine
        $LogThread    = Get-LogThread    $strLine
        $LogFile      = Get-LogFile      $strLine

        If ( $LogComponent -eq "ContentAccess")          { $Notes        = Get-CASNotes $strLine }
        If ( $LogComponent -eq "ContentTransferManager") { $Notes        = Get-ContentTransferManagerNotes $strLine }
        If ( $LogComponent -eq "WUAhandler")             { $Notes        = Get-WUAHandlerNotes $strLine }
        If ( $LogComponent -eq "UpdatesHandler")         { $Notes        = Get-UpdatesHandlerNotes $strLine }
        If ( $LogComponent -eq "DataTransferService")    { $Notes        = Get-DataTransferServiceNotes $strLine }
        If ( $LogComponent -eq "UpdatesDeploymentAgent") { $Notes        = Get-UpdatesDeploymentNotes $strLine }

        Log-Append -strLogFileName $strOutputFile -strLogText ($LogDateTime  + "`t" + $LogComponent  + "`t" + $LogThread + "`t" + $Notes  + "`t" + $LogText  + "`t" + $LogFile + "`t" + $LogType)
        $LogDateTime  + "`t " + $LogComponent  + "`t " + $LogThread + "`t " + $Notes  + "`t " + $LogText  + "`t " + $LogFile + "`t " + $LogType  
    }
}


Function Load-SCCMLogs() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLogFolder   )



    Write-Host 'Processing UpdatesHandler.log  ...'
    $LogFile = get-content ($strLogFolder+'\UpdatesHandler.log')  -ErrorAction SilentlyContinue
    If ( $LogFile ) {
        foreach ($Line in $LogFile){ 
            $Line = $Line.Replace("`n","")
            $Line = $Line.Replace("`t","")
            Parse-LogLine $Line 
        }
    }

    Write-Host 'Processing DataTransferService.log  ...'
    $LogFile = get-content ($strLogFolder+'\DataTransferService.log') -ErrorAction SilentlyContinue
    If ( $LogFile ) {
        foreach ($Line in $LogFile){
            $Line = $Line.Replace("`n","")
            $Line = $Line.Replace("`t","")
            Parse-LogLine $Line
        }
    }


    Write-Host 'Processing ContentTransferManager.log  ...'
    $LogFile = get-content ($strLogFolder+'\ContentTransferManager.log')  -ErrorAction SilentlyContinue
    If ( $LogFile ) {
        foreach ($Line in $LogFile){
            $Line = $Line.Replace("`n","")
            $Line = $Line.Replace("`t","")
            Parse-LogLine $Line
        }
    }



    Write-Host 'Processing CAS.log  ...'
    $LogFile = get-content ($strLogFolder+'\CAS.log') -ErrorAction SilentlyContinue
    If ( $LogFile ) {
        foreach ($Line in $LogFile){
            $Line = $Line.Replace("`n","")
            $Line = $Line.Replace("`t","")
            Parse-LogLine $Line
        }
    }




    Write-Host 'Processing UpdatesDeployment.log  ...'
    $LogFile = get-content ($strLogFolder+'\UpdatesDeployment.log')  -ErrorAction SilentlyContinue
    If ( $LogFile ) {
        foreach ($Line in $LogFile){
            $Line = $Line.Replace("`n","")
            $Line = $Line.Replace("`t","")
            Parse-LogLine $Line
        }
    }
    

    Write-Host 'Processing WUAHandler.log  ...'
    $LogFile = get-content ($strLogFolder+'\WUAHandler.log') -ErrorAction SilentlyContinue
    If ( $LogFile ) {
        foreach ($Line in $LogFile){
            $Line = $Line.Replace("`n","")
            $Line = $Line.Replace("`t","")
            Parse-LogLine $Line
        }
    }



    $LogFile
}


Function Get-ContentTransferManagerNotes() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   )

    $Notes = $Null

    If ( $strLine.IndexOf("http://") -ge 0 )  { $ServerName = ($strLine.SubString($strLine.IndexOf("http://")+7, $strline.IndexOf(".",$strLine.IndexOf("http://")+7) - ($strLine.IndexOf("http://")+7))) }
    If ( $strLine.IndexOf("https://") -ge 0 ) { $ServerName = ($strLine.SubString($strLine.IndexOf("https://")+8, $strline.IndexOf(".",$strLine.IndexOf("https://")+8) - ($strLine.IndexOf("https://")+8))) }
    If ( $strLine.IndexOf("download.windowsupdate.com") -ge 0 ) { $ServerName = ("download.windowsupdate.com") }
   
    If ( $strLine.IndexOf("(BOUNDARYGROUP)") -ge 0 ) { $Notes += ("Checking Boundary Group DP " + $ServerName + " for") }
    If ( $strLine.IndexOf("(SITE)") -ge 0)  { $Notes += ("Checking Default Site DP " + $ServerName + " for")  }
    If ( $strLine.IndexOf("(WUMU)") -ge 0)  { $Notes += ("Checking WUMU " + $ServerName )  }

    If ( $strLine.IndexOf("Persisted location") -eq 0)  { $Notes += ("Located at " + $ServerName )  }
    
    If ( $strLine.IndexOf("CCM_DOWNLOADSTATUS_WAITING_CONTENTLOCATIONS") -ge 0)  { $Notes += ("Getting locations for package" )  }

    If ( $strLine.IndexOf("Modifying provider to 'NomadBranch'") -ge 0)  { $Notes += ("Attempting to download using NOMAD" ) }

    If ( $strLine.IndexOf("skipping provider 'NomadBranch''") -ge 0)  { $Notes += ("Not enabled for NOMAD use" ) }

    If ( $strLine.IndexOf("Received empty location update for CTM Job'") -ge 0)  { $Notes += ("No locations found" ) }

    If ( $strLine.IndexOf("successfully processed download completion") -ge 0 ) { $Notes += ("End download " ) }

    If ( $strLine.IndexOf("No progress for CTM job") -ge 0 ) { $Notes += ("Nothing is downloading, switching locations " ) }

    If ( $strLine.IndexOf("Suspended") -ge 0 ) { $Notes += ("Download job suspended " ) }

    If ( $strLine.IndexOf("ModifyDownload - next location") -ge 0 ) { $Notes += ("Modifying download location to $ServerName " ) }

    If ( $strLine.IndexOf("Created CTM job") -ge 0 ) { $Notes += ("Preparing to download new content " ) }

    #If ( $strLine.IndexOf("CCTMJob::_GetNextLocation failed with code 0x87d00215") -ge 0 ) { $Notes += ("Failed to find content at this location " ) }

    If ( $strLine.IndexOf("CCTMJob::UpdateLocations - Recieved no suitable locations in location update for CTM Job") -ge 0 ) { $Notes += ("Content not available on any assigned DP " ) }

    If ( $strLine.IndexOf("CCTMJob::ProcessProgress - Downloaded chunksize") -ge 0 ) { $Notes += ("Download in progress..." ) }

    If ( $strLine.IndexOf("ProcessDownloadSuccess") -ge 0 ) { $Notes += ("Download success" ) }

    If ( $strLine.IndexOf("Refresh locations initiated for") -ge 0 ) { $Notes += ("Refresh DP<->Package availability") }

    If ( $strLine.IndexOf("80004004") -ge 0 ) { $Notes += ("Error 0x80004004 Operation aborted") }

    #If ( $strLine.IndexOf("87d00215") -ge 0 ) { $Notes += ("Item not found ( generic result, probably a non error )") }

    If ( $strLine.IndexOf("switched to location") -ge 0 ) { $Notes += ("Downloading from new location " + $ServerName ) }

    If ( $strLine.IndexOf("UpdateLocations - Received empty location update for CTM Job") -ge 0 ) { $Notes += ("No location found for CTM job") }

    If ( $strLine.IndexOf("suspended") -ge 0 ) { $Notes += ("Job Suspended") }

    If ($Notes ) { $Notes += " " }

#    If ( $strLine.IndexOf('SMS_DP_SMSPKG$/',0) -ne -1 ) { 
#         $Notes += Get-NameFromPkgID($strLine.SubString($strLine.IndexOf('SMS_DP_SMSPKG$/')+15,8))
#         $Notes += Get-ShortNameFromGUID($strLine.SubString($strLine.IndexOf('SMS_DP_SMSPKG$/')+15,36))
#    }


    ############ Turn this into a function
    If ( $strLine.IndexOf('SMS_DP_SMSPKG$/',0) -ne -1 ) {
        If ( $SiteCode -eq  $strLine.SubString($strLine.IndexOf('SMS_DP_SMSPKG$/',0)+15,3) ) {
            
            $PackageID = $strLine.SubString($strLine.IndexOf('SMS_DP_SMSPKG$/',0)+15,8)
            If ( $Lookups.("$PackageID")) { $Notes += ('(' + $PackageID + ') ' + $Lookups.("$PackageID") ) }
            Else {
                $Package = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query ("SELECT * FROM SMS_Package WHERE PackageID = '" + $PackageID + "'")
                $Result = $Lookups.Add($PackageID, $Package.Name + " " + $Package.Version + " " + $Package.Language )                
                If ($Notes ) { $Notes += " " }
                $Notes += ('(' + $PackageID + ') ' + $Package.Name + " " + $Package.Version + " " + $Package.Language )
            }

        }
        Else {
            $GUID = $strLine.SubString($strLine.IndexOf('SMS_DP_SMSPKG$/',0)+15,36)
            If ( $Lookups.("$GUID")) { $Notes += ( $Lookups.("$GUID") ) }
            Else { $Notes += Get-NameFromGUID $GUID }
        }
    }

    # CTM job {33624B2E-61A7-428C-A6EC-B0CDFBC8B8A5} (corresponding DTS job {57F233B6-BC00-49E7-BA3A-C467E86F6B12}) started download from 'http://fhiscmdpp01.pharma.aventis.com/SMS_DP_SMSPKG$/2404bd0d-9da0-4c18-8afe-b5f3eb57849b' for full content download.
    If ( $strLine.IndexOf("started download from ") -ge 0 ) { 
        $LogText = Get-LogText $strLine
        $Notes += ($LogText.SubString($LogText.IndexOf(" started download from "),($LogText.length - $LogText.IndexOf(" started download from "))) ) 
    }


    If ($Notes) { Write-Host $Notes.Trim()}
    $Notes.trim()
}




Function Get-CASNotes() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   )

    $Notes = $Null

    If ( $strLine.IndexOf("http://") -ge 0 )  { $ServerName = ($strLine.SubString($strLine.IndexOf("http://")+7, $strline.IndexOf(".",$strLine.IndexOf("http://")+7) - ($strLine.IndexOf("http://")+7))) }
    If ( $strLine.IndexOf("https://") -ge 0 ) { $ServerName = ($strLine.SubString($strLine.IndexOf("https://")+8, $strline.IndexOf(".",$strLine.IndexOf("https://")+8) - ($strLine.IndexOf("https://")+8))) }
    If ( $strLine.IndexOf("download.windowsupdate.com") -ge 0 ) { $ServerName = ("download.windowsupdate.com") }
    If ( $strLine.IndexOf("Matching DP location found") -ge 0 ) { $Notes = $strLine.Substring(   $strLine.IndexOf('-')+2    ,$strLine.Length - ($strLine.IndexOf('-')+2)) }
    #If ( $strLine.IndexOf("Successfully created download  request ") -ge 0 ) { $Notes = "Created download request for " + ( Get-AssignmentFromGUID ( $strLine.Substring($strLine.IndexOf(' for content ')+13, 38 ) )  ) }


    If ( $strLine.IndexOf("Requesting locations synchronously for content ") -ge 0 ) { $Notes = ("Checking locations for " + ( Get-UpdatesFromContentID($strLine.Substring($strLine.IndexOf('for content ')+12, 36 )))) }
    If ( $strLine.IndexOf("location services for ") -ge 0 ) { $Notes = "Requesting locations for" + (Get-UpdatesFromContentID($strLine.Substring($strLine.IndexOf('location services for ')+22, 36 ))) }

    # Calling back with the following distribution points
    If ( $strLine.IndexOf("Calling back with the following distribution points") -ge 0 ) {$Notes = Get-LogText $strLine }

    # The number of discovered DPs(including Branch DP and Multicast) is 2
    If ( $strLine.IndexOf("The number of discovered DPs") -ge 0 ) {$Notes = Get-LogText $strLine }

    # Distribution Point='http://fhiscmdpp01.pharma.aventis.com/SMS_DP_SMSPKG$/0d90cc80-19c6-465c-936d-ac74a23b9c46', Locality='LOCAL'
    If ( $strLine.IndexOf("Distribution Point=") -ge 0 ) {$Notes = Get-LogText $strLine }

    # do this one. lots of info
    # Reply Message Body : <ContentLocationReply SchemaVersion="1.00"><BoundaryGroups BoundaryGroupListRetrieveTime="2019-10-08T18:35:59.080"><BoundaryGroup GroupID="167" GroupGUID="039BE065-8433-4764-BE1B-5D05D8CBDA30"/></BoundaryGroups><ContentInfo PackageFlags="0"><ContentHashValues/></ContentInfo><Sites><Site><MPSite SiteCode="P01" MasterSiteCode="P01" SiteLocality="LOCAL" IISPreferedPort="80" IISSSLPreferedPort="443"/><LocationRecords><LocationRecord><URL Name="http://fhiscmdpp01.pharma.aventis.com/SMS_DP_SMSPKG$/0d90cc80-19c6-465c-936d-ac74a23b9c46" Signature="http://fhiscmdpp01.pharma.aventis.com/SMS_DP_SMSSIG$/0d90cc80-19c6-465c-936d-ac74a23b9c46.1.tar" Capability="0"/><URL Name="http://fhiscmdpp01.pharma.aventis.com/SMS_DP_SMSPKG$/0d90cc80-19c6-465c-936d-ac74a23b9c46" Signature="http://fhiscmdpp01.pharma.aventis.com/SMS_DP_SMSSIG$/0d90cc80-19c6-465c-936d-ac74a23b9c46.1.tar" Capability="0"/><ADSite Name="US-FHI"/><IPSubnets><IPSubnet Address="155.65.183.0"/><IPSubnet Address=""/></IPSubnets><Metric Value=""/><Version>8692</Version><Capabilities SchemaVersion="1.0"><Property Name="SSLState" Value="0"/></Capabilities><ServerRemoteName>fhiscmdpp01.pharma.aventis.com</ServerRemoteName><DPType>SERVER</DPType><Windows Trust="1"/><Locality>LOCAL</Locality></LocationRecord></LocationRecords></Site><Site><MPSite SiteCode="P01" MasterSiteCode="P01" SiteLocality="LOCAL"/><LocationRecords/></Site></Sites><RelatedContentIDs/></ContentLocationReply>

    # <![LOG[===== CacheManager: Content P000224B.1 of size (693K) was found in cache with an empty exclude file list.=====]LOG]!><time="08:48:00.831+240" date="05-15-2019" component="ContentAccess" context="" type="1" thread="6392" file="cachemanager.cpp:899">
    If ( $strLine.IndexOf(" was found in cache ") -ge 0 ) {$Notes = ((Get-LogText($strLine)) + " " + ( Get-NameFromPkgID( $strLine.SubString($strLine.IndexOf("CacheManager: Content ")+22, 8 ) ) ) ) }

    # Saved Content ID Mapping P000224B.1, C:\Windows\ccmcache\4x
    If ( $strLine.IndexOf("Saved Content ID Mapping ") -ge 0 ) {$Notes = ((Get-LogText($strLine)) + " " + ( Get-NameFromPkgID( $strLine.SubString($strLine.IndexOf("Saved Content ID Mapping ")+25, 8 ) ) ) ) }

    # CacheManager: All references to cached Content P000224B.1 have been removed, content is tombstoned and may be removed during future grooming operations.
    If ( $strLine.IndexOf("content is tombstoned ") -ge 0 ) {$Notes = ((Get-LogText($strLine)) + " " + ( Get-NameFromPkgID( $strLine.SubString($strLine.IndexOf("cached Content ")+15, 8 ) ) ) ) }

    # ===== CacheManager: Checking if content 0d90cc80-19c6-465c-936d-ac74a23b9c46.1 is in the cache. =====
    If ( $strLine.IndexOf("CacheManager: Checking if content ") -ge 0 ) {$Notes = ((Get-LogText($strLine)) + " " + ( Get-NameFromGUID( $strLine.SubString($strLine.IndexOf("Checking if content ")+20, 36 ) ) ) ) }

    # ===== CacheManager: Content for 0d90cc80-19c6-465c-936d-ac74a23b9c46.1 was NOT found cache. =====
    If ( $strLine.IndexOf("CacheManager: Content for ") -ge 0 ) {$Notes = ((Get-LogText($strLine)) + " " + ( Get-NameFromGUID( $strLine.SubString($strLine.IndexOf("CacheManager: Content for ")+26, 36 ) ) ) ) }

    # CacheManager: Target location for content 80b1e5c9-f3a0-4f38-a8cb-ef8c8862d85b.1 is C:\Windows\ccmcache\61
    If ( $strLine.IndexOf("CacheManager: Target location for content ") -ge 0 ) {$Notes = ((Get-LogText($strLine)) + "... for ... " + ( Get-NameFromGUID( $strLine.SubString($strLine.IndexOf("for content ")+12, 36 ) ) ) ) }

    # ContentLocationRequest : <ContentLocationRequest SchemaVersion="1.00" ExcludeFileList=""><Package ID="UID:0d90cc80-19c6-465c-936d-ac74a23b9c46" Version="1"/><AssignedSite SiteCode="P01"/><ClientLocationInfo LocationType="SMSUpdate" DistributeOnDemand="0" UseAzure="0" AllowWUMU="0" UseProtected="0" AllowCaching="0" BranchDPFlags="0" UseInternetDP="0" AllowHTTP="1" AllowSMB="1" AllowMulticast="1"><ADSite Name="US-FHI"/><Forest Name="aventis.com"/><Domain Name="pharma.aventis.com"/><IPAddresses><IPAddress SubnetAddress="155.65.154.0" Address="155.65.154.23"/></IPAddresses></ClientLocationInfo></ContentLocationRequest>
    If ( $strLine.IndexOf("UID:") -ge 0 ) { $Notes += (Get-UpdatesFromContentID($strLine.Substring($strLine.IndexOf('UID:')+4, 36 ))) } 

    # Download succeeded for download request {2D4CB9A6-735D-474E-BC79-53A100DADA79}



    If ( $strLine.IndexOf("Download started for content") -ge 0 ) { $Notes = "Download started for content " + ( Get-UpdatesFromContentID ( $strLine.Substring($strLine.IndexOf('Download started for content ')+29, 36 ) ) )  }
    If ( $strLine.IndexOf("Download completed for content") -ge 0 ) { $Notes = Get-LogText $strLine }
    If ( $strLine.IndexOf("**** Received request for content") -ge 0 ) { 
        If (Get-UpdatesFromContentID $strLine.SubString(41,36)) {
            $ReqName = (Get-UpdatesFromContentID $strLine.SubString(41,36))
        }
        Else {
            If (Get-NameFromPkgID $strLine.SubString(41,8)) { 
               $ReqName = (Get-NameFromPkgID $strLine.SubString(41,8))
            }
        }
        $Notes += "Content Request " + $ReqName
    }

    If ($Notes) { Write-Host $Notes }  
    $Notes
}



Function Get-WUAHandlerNotes() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   )

    $Notes = $Null

    If ( $strLine.IndexOf("http://") -ge 0 )  { $ServerName = ($strLine.SubString($strLine.IndexOf("http://")+7, $strline.IndexOf(".",$strLine.IndexOf("http://")+7) - ($strLine.IndexOf("http://")+7))) }
    If ( $strLine.IndexOf("https://") -ge 0 ) { $ServerName = ($strLine.SubString($strLine.IndexOf("https://")+8, $strline.IndexOf(".",$strLine.IndexOf("https://")+8) - ($strLine.IndexOf("https://")+8))) }
    If ( $strLine.IndexOf("download.windowsupdate.com") -ge 0 ) { $ServerName = ("download.windowsupdate.com") }
    
    If ( $strLine.IndexOf("87d00215") -ge 0 ) { $Notes += ("Test Result : Not Found ") }
    #If ( $strLine.IndexOf("80070002") -ge 0 ) { $Notes += ("Test Result: The system cannot find the item specified.") }

    If ( $strLine.IndexOf("Enabling WUA Managed server policy to use server") -ge 0 ) { $Notes = ("Assigning WU server to $ServerName") }
    If ( $strLine.IndexOf("Failed to Add Update Source for WUAgent") -ge 0 )          { $Notes = ("Failed to add WU server to local settings, possible GPO conflict") }
    If ( $strLine.IndexOf("Its a completely new WSUS Update Source.") -ge 0 )         { $Notes = ("Adding WSUS Source ... probably a new provision") }

    If ( $strLine.IndexOf("Update (Missing):") -ge 0 )                                { $Notes = (Get-LogText $strLine.SubString(0,$strLine.Length-45))  }
    If ( $strLine.IndexOf("configuration policy has not been received.") -ge 0 )      { $Notes = ("Probably a new client") }
    If ( $strLine.IndexOf("Existing WUA Managed server was already set") -ge 0 )      { $Notes = ("Use existing WUA Managed server: " + $ServerName) }
    If ( $strLine.IndexOf("Windows Update for Business is not enabled") -ge 0 )       { $Notes = ("Windows Update for Business is not enabled") }

    # Found top-level bundle update (158c74f0-a837-4cb5-8e7e-f8f24ce280c2:201) for leaf update: cbf90fa9-75d6-4f2f-8808-5783586d9bc2:201
    # Leaf: 1357d50f-8a49-4863-a70b-c4a9c10779a0, 101   Status: Missing

    If ( $strLine.IndexOf("Leaf: ") -ge 0 -AND $strLine.IndexOf("Status: Missing") -ge 0   )  { 
         $GUID = $strLine.SubString($strLine.IndexOf("Leaf: ")+6, $strline.IndexOf(",",$strLine.IndexOf("Leaf: ")+7) - ($strLine.IndexOf("Leaf: ")+6)) 
         $Notes += ("MISSING: " + (Get-ShortNameFromGUID $GUID) + " ... Source: " +  (Get-SourcePathFromGUID $GUID))
    }

    If ( $strLine.IndexOf("Unable to read existing WUA Group Policy object") -ge 0 ) { 
        $Notes += ("Possible corrupt POL file")
    }

    If ( $strLine.IndexOf('SMS_DP_SMSPKG$/',0) -ne -1 ) {
        If ( $SiteCode -eq  $strLine.SubString($strLine.IndexOf('SMS_DP_SMSPKG$/',0)+15,3) ) {
            
            $PackageID = $strLine.SubString($strLine.IndexOf('SMS_DP_SMSPKG$/',0)+15,8)
            If ( $Lookups.("$PackageID")) { $Notes += $PackageID + " = " + $Lookups.("$PackageID") }
            Else {
                $Package = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query ("SELECT * FROM SMS_Package WHERE PackageID = '" + $PackageID + "'")
                $Result = $Lookups.Add($PackageID, $Package.Name + " " + $Package.Version + " " + $Package.Language )                
                If ($Notes ) { $Notes += " " }
                $Notes += ( '(' + $PackageID + ') ' + $Package.Name + " " + $Package.Version + " " + $Package.Language )
            }
        }
        Else {
            $GUID = $strLine.SubString($strLine.IndexOf('SMS_DP_SMSPKG$/',0)+15,36)
            $Notes += (Get-SourcePathFromGUID $GUID)      
        }
    }

    If ($Notes) { 
        Write-Host $Notes
    }

    $Notes
}


Function Get-UpdatesHandlerNotes() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   )
    
    $Notes = $Null

    If ( $strLine.IndexOf("http://") -ge 0 )  { $ServerName = ($strLine.SubString($strLine.IndexOf("http://")+7, $strline.IndexOf(".",$strLine.IndexOf("http://")+7) - ($strLine.IndexOf("http://")+7))) }
    If ( $strLine.IndexOf("https://") -ge 0 ) { $ServerName = ($strLine.SubString($strLine.IndexOf("https://")+8, $strline.IndexOf(".",$strLine.IndexOf("https://")+8) - ($strLine.IndexOf("https://")+8))) }
    If ( $strLine.IndexOf("download.windowsupdate.com") -ge 0 ) { $ServerName = ("download.windowsupdate.com") }

    If ( $strLine.IndexOf("Error = 0x87d00669") -ge 0 ) { $Notes += ("ERROR: Not able to get software updates content locations at this time for update: " + (Get-ShortNameFromGUID($strLine.SubString($strLine.IndexOf("Failed to download update (") + 27 ,36))) + " ... Source: " + (Get-SourcePathFromGUID($strLine.SubString($strLine.IndexOf("Failed to download update (") + 27 ,36)))) }

    # If ( $strLine.IndexOf("87d00215") -ge 0 ) { $Notes += ("Item not found ( generic result, probably a non error )") }

    # <![LOG[CAtomicUpdate::SetState - Entered SetState - Update 7cef7e24-9114-4f32-a309-f0011e89838c, Current State (member) = INIT,  Passed in state = DOWNLOAD_READY]LOG]!><time="12:04:48.835+240" date="10-08-2019" component="UpdatesHandler" context="" type="0" thread="1536" file="atomicupdate.cpp:1001">
    # <![LOG[CAtomicUpdate::SetState - Entered SetState - Update 0d90cc80-19c6-465c-936d-ac74a23b9c46, Current State (member) = INIT,  Passed in state = DOWNLOAD_READY]LOG]!><time="13:03:15.215+240" date="09-24-2019" component="UpdatesHandler" context="" type="0" thread="3344" file="atomicupdate.cpp:1001">
    # <![LOG[CAtomicUpdate::SetState - Entered SetState - Update 0d90cc80-19c6-465c-936d-ac74a23b9c46, Current State (member) = DOWNLOAD_READY,  Passed in state = WAIT_CONTENTS]LOG]!><time="14:35:58.738+240" date="10-08-2019" component="UpdatesHandler" context="" type="0" thread="3344" file="atomicupdate.cpp:1001">
    If ( ($strLine.IndexOf("State Transition - Update ") -ge 0) -OR ($strLine.IndexOf("Passed in state ") -ge 0) ) { 
        $State = $strLine.SubString($strLine.ToUpper().IndexOf("STATE = ")+8, $strLine.IndexOf("]") - ($strLine.ToUpper().IndexOf("STATE = ")+8 ) )
        $Notes += ("Change state to $State for " + (Get-SourcePathFromGUID($strLine.SubString($strLine.IndexOf("Update ") + 7 ,36)))) 
    } 

    If ( $strLine.IndexOf("SetJobTimeoutOptions failed. Error = 0x87d00215") -ge 0 ) { $Notes += ("Job Timeout Failure, Possible WMI issue") }
    If ( $strLine.IndexOf("Updates scan completion received, result = 0x80004005") -ge 0 ) { $Notes += ("Scan failed to complete") }

    If ( $strLine.IndexOf("Updates scan completion received, result = 0x0") -ge 0 ) { $Notes += ("Scan completed successfully") }
    If ( $strLine.IndexOf("Successfully initiated scan") -ge 0 ) { $Notes += ("Scan started successfully") }
  
   # too much output, checks every update in deployment not just applicable ones
   # If ( $strLine.IndexOf("Starting applicability checking") -ge 0 ) { $Notes += ("Starting applicability checking") }

    If ( $strLine.IndexOf("State = StateDownloading") -ge 0 ) {$Notes += ("Downloading ... " + (Get-SourcePathFromGUID($strLine.SubString(19,36)))) }
    If ( $strLine.IndexOf( "-Added update (" ) -ge 0 ) { $Notes += (" Added update: " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf('-Added update (',0)+15,36)) ) }
    
    If ( $strLine.IndexOf("started download from ") -ge 0 ) { $Notes += ("Started Download from " + $ServerName + " for ") }
    If ( $strLine.IndexOf( "an update of bundle (" ) -ge 0 ) { $Notes = $Notes + (" ... From bundle:  " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf('an update of bundle (',0)+21,36)) ) }

    If ( $strLine.IndexOf( "Getting update (" ) -ge 0 ) { $Notes += ("Getting update ... " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf('Getting update (',0)+16,36))) }
    If ( $strLine.IndexOf("Failed to download update ") -ge 0 ) { $Notes += ("Failed to download update: " + (Get-ShortNameFromGUID $strLine.SubString($strLine.IndexOf('Failed to download update',0)+27,36)) + " ... " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf('Failed to download update',0)+27,36)))  }
    
    If ( ($strLine.IndexOf("execution completed with state ") -ge 0) ) { 
        $State = $strLine.SubString($strLine.IndexOf("state ")+6, ($strLine.IndexOf("]", $strLine.IndexOf("State ")+7 ) - ($strLine.IndexOf("state ")+6)) )
        $Notes += ("Execution Completed: " + (Get-ShortNameFromGUID($strLine.SubString($strLine.IndexOf("Update (") + 8 ,36))) + " *** STATE: " + $State) 
    } 

    If ( $strLine.IndexOf("Failed to populate progress info for the update ") -ge 0 ) { $Notes += ("No Progress, Possible disk space issue for update " + (Get-ShortNameFromGUID $strLine.SubString($strLine.IndexOf('Failed to populate progress info for the update ',0)+48,36))) }

    If ( ($strLine.IndexOf("StateCore - bundle update (") -ge 0) ) { 
        $Notes += Get-ShortNameFromGUID($strLine.SubString($strLine.IndexOf("StateCore - bundle update (")+27, 36 ))
        $Notes += " " + $strLine.SubString($strLine.IndexOf("state changed from"), ($strLine.IndexOf("]") - $strLine.IndexOf("state changed from")) )
    } 

    # <![LOG[Starting download on action (INSTALL) for Update (41c8255a-e03e-44c5-8ee7-2f325818defb)]LOG]!><time="23:04:34.387+240" date="10-09-2019" component="UpdatesHandler" context="" type="1" thread="42312" file="update.cpp:461">
    If ( ($strLine.IndexOf("Starting download on action (INSTALL) for Update (") -ge 0) ) { $Notes += ("Starting download for " + (Get-SourcePathFromGUID($strLine.SubString($strLine.IndexOf("for Update (")+12, 36 )))) }
         

    If ( $strLine.IndexOf("Bundle update (") -ge 0 -AND $strLine.IndexOf("requesting download") -ge 0 ) {$Notes += ("Download Request: " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf('Bundle update (',0)+15,36))) }

    # <![LOG[CAtomicUpdate::SetState - Entered SetState - Update f2b35924-5e42-4547-a14e-00583232846c, Current State (member) = INIT,  Passed in state = DOWNLOAD_READY]LOG]!><time="13:03:15.231+240" date="09-24-2019" component="UpdatesHandler" context="" type="0" thread="3344" file="atomicupdate.cpp:1001">
    If ( $strLine.IndexOf("CAtomicUpdate::SetState") -ge 0 ) { $Notes = ( "STATE: " + $strLine.SubString($strLine.IndexOf("in state ")+9, ($strLine.IndexOf("]" ) - ($strLine.IndexOf("in state = ")+9)) ) + " ... For update: " + (Get-SourcePathFromGUID($strLine.SubString($strLine.IndexOf("- Update ")+9, 36 )))   )}
    
    If ( $strLine.IndexOf("Download already completed") -ge 0 -OR $strLine.IndexOf("Download  completed") -ge 0 ) { $Notes += Get-LogText $strLine  }

    # <![LOG[Starting download on action (INSTALL) for Update (baa9fb26-5f2f-4f75-8223-002dd4465020)]LOG]!><time="23:04:35.880+240" date="10-09-2019" component="UpdatesHandler" context="" type="1" thread="42312" file="update.cpp:461">
    If ( $strLine.IndexOf("for Update (") -ge 0 -AND !$Notes ) {$Notes += ("Update Name: " + (Get-ShortNameFromGUID $strLine.SubString($strLine.IndexOf('for Update (')+12,36))) }

    If ( $strLine.IndexOf("SUM_") -ge 0 -AND !$Notes ) { $Notes = ( "Update: " + (Get-ShortNameFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) ) + " ... Source: " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) ) )}

    If ($Notes) { Write-Host $Notes.Trim() }
    $Notes.Trim()
}


Function Get-DataTransferServiceNotes() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   )
    
    $Notes = $Null
    $State = $Null
    $ServerName = $Null

    If ( $strLine.IndexOf("http://") -ge 0 )  { $ServerName = ($strLine.SubString($strLine.IndexOf("http://")+7, $strline.IndexOf(".",$strLine.IndexOf("http://")+7) - ($strLine.IndexOf("http://")+7))) }
    If ( $strLine.IndexOf("https://") -ge 0 ) { $ServerName = ($strLine.SubString($strLine.IndexOf("https://")+8, $strline.IndexOf(".",$strLine.IndexOf("https://")+8) - ($strLine.IndexOf("https://")+8))) }
    If ( $strLine.IndexOf("download.windowsupdate.com") -ge 0 ) { $ServerName = ("download.windowsupdate.com") }

    If ( ($strLine.IndexOf("in state '") -ge 0) ) {
        $State = $strLine.SubString($strLine.IndexOf("in state '")+10, $strLine.IndexOf("'",  ($strLine.IndexOf("in state '")+11)) - ($strLine.IndexOf("in state '")+10) )
        $Notes += ("Changed State to $State ")  
    }

    If ( $strLine.IndexOf("Transferred Bytes: ") -ge 0 ) { 
        $TotalBytes = $strLine.SubString($strLine.IndexOf("Total Bytes: ")+13, $strLine.IndexOf(",",  ($strLine.IndexOf("Total Bytes: ")+14)) - ($strLine.IndexOf("Total Bytes: ")+13) )
        $TransferredBytes = $strLine.SubString($strLine.IndexOf("Transferred Bytes: ")+19, $strLine.IndexOf("]",  ($strLine.IndexOf("Transferred Bytes: ")+20)) - ($strLine.IndexOf("Transferred Bytes: ")+19) )
        $Notes += ("Total Bytes: " + $TotalBytes + "   Transferred Bytes: " + $TransferredBytes)  
    }

    # DTSJob {E2F286C3-48BF-4273-91EE-1BD44B5FCB93} created to download from 'http://fhiscmdpp01.pharma.aventis.com:80/SMS_DP_SMSPKG$/24a2e897-ace3-47b0-9b2b-1be952067bd8' to 'C:\Windows\ccmcache\5p'.
    If ( $strLine.IndexOf("created to download from") -ge 0 ) { $Notes += ("Download Job Found on server " + $ServerName + " for update: " + (Get-UpdatesFromContentID($strLine.Substring($strline.IndexOf("SMS_DP_SMSPKG$/")+15, 36) )))  }

    If ( $strLine.IndexOf("Starting BITS download") -ge 0 ) { $Notes += ("Starting BITS download " + $ServerName)  }
    If ( $strLine.IndexOf("successfully completed download") -ge 0 ) { $Notes += ("Successfully completed BITS download.")  }
    If ( $strLine.IndexOf("BITS compatible pathBITSHelper: Full source path to be transferred =") -ge 0 ) { $Notes += ("BITS Full Source Download: " + $ServerName)  }
  # If ( $strLine.IndexOf("remote name = ") -ge 0 ) { $Notes += ("Remote Name: " + $ServerName)  }
    If ( $strLine.IndexOf("SUM_") -ge 0 ) { $Notes += (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) ) }

    # GetDirectoryList_HTTP('http://fhiscmdpp01.pharma.aventis.com:80/SMS_DP_SMSPKG$/b3eb5ef6-e38f-4be5-9e58-3b50e56842bd') failed with code 0x800704cf.
    If ( $strLine.IndexOf(" failed with code ") -ge 0  ) { $Notes += Get-Logtext $strLine  }

    # <![LOG[Failed to send request to /SMS_DP_SMSPKG$/47a361aa-e9ad-4be2-9acc-dbc0dd7ccb9b at host fhiscmdpp01.pharma.aventis.com, error 0x2efd]LOG]!><time="01:40:28.864+240" date="07-15-2019" component="DataTransferService" context="" type="2" thread="3180" file="ccmhttpget.cpp:1892">
    If ( $strLine.IndexOf("[Failed to send request to") -ge 0  ) { $Notes += Get-Logtext $strLine  }

    # <![LOG[[CCMHTTP] ERROR: URL=http://fhiscmdpp01.pharma.aventis.com:80/SMS_DP_SMSPKG$/47a361aa-e9ad-4be2-9acc-dbc0dd7ccb9b, Port=80, Options=480, Code=12029, Text=ERROR_WINHTTP_CANNOT_CONNECT]LOG]!><time="01:40:28.864+240" date="07-15-2019" component="DataTransferService" context="" type="1" thread="3180" file="ccmhttperror.cpp:297">
    If ( $strLine.IndexOf("] ERROR: ") -ge 0 )  { $Notes += Get-Logtext $strLine  }

    # <![LOG[Error sending DAV request. HTTP code 600, status '']LOG]!><time="01:40:28.864+240" date="07-15-2019" component="DataTransferService" context="" type="3" thread="3180" file="util.cpp:703">
    If ( $strLine.IndexOf("[Error sending DAV request.") -ge 0  ) { $Notes += Get-Logtext $strLine  }
    
    # <![LOG[GetDirectoryList_HTTP mapping original error 0x80072efd to 0x800704cf.]LOG]!><time="01:40:28.864+240" date="07-15-2019" component="DataTransferService" context="" type="3" thread="3180" file="util.cpp:718">
    If ( $strLine.IndexOf("mapping original error") -ge 0  ) { $Notes += Get-Logtext $strLine  }

    # <![LOG[Error retrieving manifest (0x800704cf).  Will attempt retry 140 in 3600 seconds.]LOG]!><time="01:40:28.864+240" date="07-15-2019" component="DataTransferService" context="" type="2" thread="3180" file="dtsjob.cpp:1402">
    If ( $strLine.IndexOf("[Error retrieving manifest") -ge 0 )  { $Notes += Get-Logtext $strLine  }    

    # <![LOG[GET: Host=fhiscmdpp01.pharma.aventis.com, Path=/SMS_DP_SMSPKG$/7e5069d3-680d-4775-834a-fb4f60b9d0fb, Port=80, Protocol=http, Flags=645, Options=480]LOG]!><time="10:25:45.821+240" date="07-02-2019" component="DataTransferService" context="" type="0" thread="4352" file="ccmhttpget.cpp:1635">
    If ( $strLine.IndexOf("GET:") -ge 0  ) { $Notes += $strLine.SubString($strLine.IndexOf("GET: ")+5, $strLine.IndexOf(", Port")-($strLine.IndexOf("GET: ")+5)) }


    # GET: Host=fhiscmdpp01.pharma.aventis.com, Path=/SMS_DP_SMSPKG$/8f5b2560-6b8d-4374-b925-558839a600aa, Port=80, Protocol=http, Flags=645, Options=480
    If ( $strLine.IndexOf("Host=") -ne -1 )  { 
        $DP = $strLine.Substring($strline.IndexOf("Host=")+5, $strLine.IndexOf(",") - ($strline.IndexOf("Host=")+5))
        $GUID = $strLine.Substring($strline.IndexOf("SMS_DP_SMSPKG$/")+15, 36)
        $Notes = ("DP = " + $DP  + " ... Package: " + (Trim-SourcePath((Get-NameFromGUID($GUID))) ) )
    }

    If ( $strLine.IndexOf("(source=.sms_pol?") -ge 0 ) { 
        If ( $strLine.IndexOf("AuthList_") -ge 0 ) { $Notes +=  " SUG Assignment: " +  (Get-AssignmentFromGUID  $strLine.SubString($strLine.IndexOf("(source=.sms_pol?")+16, 105 ) ) }
        ELSE { 
           If ( Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("(source=.sms_pol?")+17, 38 )) ) { $Notes += " Direct Assignment: " + (Get-AssignmentFromGUID  $strLine.SubString($strLine.IndexOf("(source=.sms_pol?")+17, 38 ) )  }
        }
    }

    If ( $strLine.IndexOf("Added (source=.sms_pol?ScopeId_") -ge 0 ) {
        $AuthListID = $strLine.SubString($strLine.IndexOf("Added (source=.sms_pol?")+23, 90)
        If ( Get-AuthListFromGUID $AuthListID ) { $Notes +=  'SUG = ' + (Get-AuthListFromGUID $AuthListID )  }
    }

    If ( $strLine.IndexOf("QUEUE: Active job count incremented, value = ") -ge 0 ) { $Notes += Get-LogText($stLine) }

    If ($Notes) { Write-Host $Notes }

    $Notes.Trim()
}


Function Get-UpdatesDeploymentNotes() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strLine   )
    
    $Notes = $Null

    If ( $strLine.IndexOf("http://") -ge 0 )  { $ServerName = ($strLine.SubString($strLine.IndexOf("http://")+7, $strline.IndexOf(".",$strLine.IndexOf("http://")+7) - ($strLine.IndexOf("http://")+7))) }
    If ( $strLine.IndexOf("https://") -ge 0 ) { $ServerName = ($strLine.SubString($strLine.IndexOf("https://")+8, $strline.IndexOf(".",$strLine.IndexOf("https://")+8) - ($strLine.IndexOf("https://")+8))) }
    If ( $strLine.IndexOf("download.windowsupdate.com") -ge 0 ) { $ServerName = ("download.windowsupdate.com") }

    If ( ($strLine.IndexOf("StateName = ") -ge 0) ) { 
        $State = $strLine.SubString($strLine.IndexOf("StateName = ")+12, ($strLine.IndexOf("]", $strLine.IndexOf("StateName = ")+13 ) - ($strLine.IndexOf("StateName = ")+12)) )
        $Notes += ("Current STATE = $State ") 
    }

    # Below removed because it looks up all updates in the SUG not just the applicable ones
    # If ( ($strLine.IndexOf("added to the targeted list of deployment (") -ge 0)  ) { $Notes = "Added to deployment: " + (Get-AssignmentFromGUID $strLine.SubString($strLine.IndexOf("added to the targeted list of deployment (")+43, 36 ) )  }
    
    # EnumerateUpdates for action (UpdateActionInstall) - Total actionable updates = 64
    If ( ($strLine.IndexOf("EnumerateUpdates for action") -ge 0)  ) { $Notes += Get-LogText $strLine    }


    $Notes = ("Update: " + $strLine.SubString($strLine.IndexOf(") Name (")+8, $strLine.IndexOf(") ArticleID (") - ($strLine.IndexOf(") Name (")+8)) + " ... Added from deployment: " + ( Get-AssignmentFromGUID $strLine.Substring($strLine.IndexOf("of deployment (")+15,38) ) )

    If ( ($strLine.IndexOf("superseded, no install attempt required") -ge 0)  ) { $Notes += "--- SUPERSEDED --- "   }

    If ( ($strLine.IndexOf("GetActionableUpdates:") -ge 0)  )            { $Notes += "GetActionableUpdates: " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) )  }
    If ( ($strLine.IndexOf("Raised assignment ({") -ge 0)  )                { $Notes = ( "Raised assignment: " + (Get-AssignmentFromGUID $strLine.SubString($strLine.IndexOf("Raised assignment ({")+19, 38 ) ) + " ... " + $Notes )  }
    If ( ($strLine.IndexOf("No current service window available to run updates assignment with time required = 1") -ge 0)  ) { $Notes += "No service window available or outside of assigned business hours" }
    If ( ($strLine.IndexOf("We will attempt to install any scheduled updates") -ge 0)  ) { $Notes += Get-LogText($strLine) }
        
    If ( ($strLine.IndexOf("Deadline received for assignment (") -ge 0)  ) { $Notes += "Deadline received for assignment: " + (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("Deadline received for assignment (") + 34, 38  )))  }
    If ( ($strLine.IndexOf("Updates scan completion received, result = 0x80004005") -ge 0)  ) { $Notes += "Deployment scan phase failed"   }
    If ( ($strLine.IndexOf("instance of SMS_SUMAgentAssignmentError_EvaluationJob_Mom") -ge 0)  ) { $Notes += "Raising Failure Event with the following data"   }
    If ( ($strLine.IndexOf("Attempting to install") -ge 0)  )            { $Notes += (Get-LogText $strLine)  }
    If ( ($strLine.IndexOf("Updates will not be made available") -ge 0)  )  { $Notes += "Error: Updates will not be made available"  }
    If ( ($strLine.IndexOf("No actionable updates for install task. No attempt required.") -ge 0)  ) { $Notes += ( Get-LogText $strLine )  }
    If ( ($strLine.IndexOf("GetActions() did not succeed. 80070490") -ge 0)  ) { $Notes += (Get-LogText $strLine)   }

    If ( ($strLine.IndexOf("Job error (0x80004005) received for assignment ({") -ge 0)  ) { $Notes += ("Job Error for assignment: "  +  (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("Job error (0x80004005) received for assignment ({")+48, 38 )))) }
    If ( ($strLine.IndexOf("Started evaluation for assignment ({") -ge 0)  ) { $Notes += ("Evaluating assignment: "  + (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("Started evaluation for assignment (")+35, 38 )))) }

    If ( ($strLine.IndexOf("Win32ErrorCode = 2147500037") -ge 0)  ) { $Notes += ("Win32ErrorCode = 2147500037 corresponds to a corrupt SCCM client WMI. Remove the client, reboot and reinstall the client") }

    If ( $strLine.IndexOf("Assignment {") -ge 0  ) { $Notes += ( "AssignmentName: " + (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("Assignment {")+11, 38 )))) }
    If ( $strLine.IndexOf("AssignmentId = ") -ge 0  ) { $Notes += ( "AssignmentName: " + (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("AssignmentId = ")+15, 38 )))) }

    If ( ($strLine.IndexOf("NotifyAssignmentAdd") -ge 0)  -AND  ($strLine.IndexOf("already refers to the assignment") -eq -1 )  ) { 
        $Notes = "Asigned update - " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) )  
    }

    # too much output ?
    #If ( ($strLine.IndexOf("Raising client SDK event for class CCM_SoftwareUpdate, instance CCM_SoftwareUpdate.UpdateID=") -ge 0)  )   { $Notes += (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) )  }

    If ( $strLine.IndexOf("InstallUpdates Initiated by user") -ge 0 ) { $Notes = "InstallUpdates Initiated by user" }

    If ( $strLine.IndexOf("0x80070002") -ge 0 ) { $Notes += ("The system cannot find the item specified. ") + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) )  }

    If ( $strLine.IndexOf("Cannot get SDM CI for update") -ge 0 ) { $Notes += ("No local assignment for " +(Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) ) ) }

    # Too much output
    # If ( $strLine.IndexOf("Started evaluation for assignment") -ge 0 ) { $Notes += ("Started evaluation for assignment ") }
     
    If ( $strLine.IndexOf("Loaded CIInfo for update ") -ge 0 ) { $Notes += ("Loaded CIInfo for update ") }
   
   # Evaluation initiated for (45) assignments.
    If ( $strLine.IndexOf("Evaluation initiated for (") -ge 0 ) { $Notes = Get-LogText $strLine }

    # too much output
    # If ( $strLine.IndexOf("NotifyAssignmentAdd") -ge 0 ) { $Notes += ("Adding to assignment -  " + (Get-SourcePathFromGUID $strLine.SubString($strLine.IndexOf("SUM_")+4, 36 ) )) }

    If ( $strLine.IndexOf("will be retried once the service window is available") -ge 0 ) { $Notes += ("This assignment will b retried when the service window is available : " + (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("{"),38  )  )   )) }

    If ( $strLine.IndexOf("started for assignment (") -ge 0 ) { $Notes += ("Download CI Contents started: " + (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("started for assignment (")+24,38 ))))  }

    If ( $strLine.IndexOf("Progress received for assignment (") -ge 0 ) { $Notes += (("Progress received for assignment: " + (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("Progress received for assignment (")+34,38 )))))  }

    If ( $strLine.IndexOf("DownloadJob completion received for assignment (") -ge 0 ) { $Notes += ((Get-LogText($strLine)) + " " + (Get-AssignmentFromGUID($strLine.SubString($strLine.IndexOf("for assignment (")+16,38 ))))  }


# Update (Site_8448F551-57A5-4567-AC55-FF5B4E9F188A/SUM_131c93ce-765a-4fe3-8cca-3c7674361a8c) Name (Security Update for SQL Server 2016 Service Pack 2 GDR (KB4505220)) ArticleID (4505220) added to the targeted list of deployment ({60ffb63a-7a6d-4e48-81cb-583b3fd31538})
If ( $strLine.IndexOf("added to the targeted list of deployment ") -ge 0 ) {      
    $UID = $strLine.SubString($strLine.IndexOf("SUM_")+4,36)
    $UpdateName = $strLine.SubString($strLine.IndexOf(") Name (")+6,($strLine.IndexOf(" added to the targeted") -$strLine.IndexOf(") Name (")+6 ))
    $DeploymentID = $strLine.SubString($strLine.IndexOf("of deployment (")+15, ($strLine.IndexOf("})")+1 ) - ($strLine.IndexOf("of deployment (")+15 ))
    If ( $Deployments.("$DeploymentID")) { $Notes = $Deployments.("$DeploymentID")  }
    ELSE {
        $Deployments.Add($DeploymentID,$UpdateName + " ( " + $UID + " )")
    }
    $Notes = $DeploymentID,$UpdateName + " ( " + $UID + " )"
}






# Detection job ({B91457C7-ACCD-415F-B117-549D5DB50E6B}) started for assignment ({7b0a95f1-59ac-434e-9463-8463f1b40ee6})



    If ( $strLine.IndexOf("Total Pending reboot updates = ") -ge 0 ) { 
        $Notes += "Updates pending reboot = " + $strLine.SubString(($strLine.IndexOf("Total Pending reboot updates = ") + 31), ($strLine.IndexOf(" ", ($strLine.IndexOf("Total Pending reboot updates = ") + 31) ) - ($strLine.IndexOf("Total Pending reboot updates = ") + 31) - 31) )   
    }

    If ( $strLine.IndexOf(") Name (") -ge 0 ) { 
       # $Notes += ($strLine.SubString($strLine.IndexOf(") Name (") + 8, $strLine.IndexOf(")", $strLine.IndexOf(") Name (") +9  ) - ($strLine.IndexOf(") Name (") + 8) +1))
    }

    If ($Notes) { Write-Host $Notes.Trim()}
    $Notes.Trim()
}


Function Get-AuthListFromGUID() {
[CMDLETBinding()]
PARAM
(   [Parameter(Position=1)] $strGUID   )

    If ( $Lookups.("$strGUID")) { $Lookups.("$strGUID")  }
    Else {
        $WQLSelect = "SELECT LocalizedDisplayName FROM SMS_AUTHORIZATIONLIST WHERE CI_UniqueID = '$strGUID'"
        $AuthList = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query $WQLSelect
        $Result = $Lookups.Add($strGUID,$AuthList.LocalizedDisplayName) 
        $AuthList.LocalizedDisplayName
    }
}


Function Get-UpdatesFromContentID() {
[CMDLETBinding()]
PARAM
(   [Parameter(Position=1)] $strContentUniqueID   )

    If ( $Lookups.("$strContentUniqueID")) { $Lookups.("$strContentUniqueID")  }
    Else {

        $Updates = @()
        $WQLSelect = "SELECT DISTINCT CI_UniqueID FROM SMS_CIToContent Where ContentUniqueID = '$strContentUniqueID'"
        $Updates = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query $WQLSelect
        ForEach ( $Update in $Updates ) {
            $strUpdates += (" " + (Get-ShortNameFromGUID($Update.CI_UniqueID)))
        }
        $Result = $Lookups.Add($strContentUniqueID,$strUpdates) 
        $strUpdates
    }
}

Function Get-NameFromPkgID() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strPkgID   )

    If ( $Lookups.("$strPkgID")) { $Lookups.("$strPkgID")  }
    Else {
        $WQLSelect = "SELECT * FROM SMS_Package where PackageID = '$strPkgID'"
        $Pkg = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query $WQLSelect
        $Result = $Lookups.Add($strPkgID,($Pkg.name + " " + $Pkg.Version + " " + $Pkg.Language)) 
        $Pkg.name + " " + $Pkg.Version + " " + $Pkg.Language
    }
}



Function Get-SourcePathFromGUID() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strGUID   )
    #If ( $Lookups.("$strGUID")) { $Lookups.("$strGUID")  }
    If ( $LookupPaths.("$strGUID")) { $LookupPaths.("$strGUID")  }
    Else { 
        $SQLSelect = ("SELECT dbo.v_UpdateCIs.ContentSourcePath, dbo.v_UpdateCIs.ArticleID, dbo.v_UpdateCIs.DatePosted, dbo.v_LocalizedCIProperties.DisplayName
                       FROM dbo.v_UpdateCIs 
                       INNER JOIN dbo.v_LocalizedCIProperties ON dbo.v_UpdateCIs.CI_ID = dbo.v_LocalizedCIProperties.CI_ID
                       WHERE (dbo.v_UpdateCIs.CI_UniqueID = N'$strGUID') AND (dbo.v_LocalizedCIProperties.LocaleID = 9)")

        $UpdateInfo = Invoke-SQL -SQLServer $SQLServer  -SQLDBName $SQLDBName  -SQLSelect $SQLSelect
        If ( $UpdateInfo.DisplayName ) { 
            $Result = $Lookups.Add($strGUID,$UpdateInfo.DisplayName + " " + $UpdateInfo.DatePosted ) 
            $Result = $UpdateInfo.DisplayName
        }

        $WQLSelect = (   "SELECT DISTINCT SMS_Content.ContentSource FROM SMS_CIToContent JOIN SMS_Content ON SMS_Content.ContentUniqueID = SMS_CIToContent.ContentUniqueID  WHERE SMS_CIToContent.CI_UniqueID = '$strGUID'")
        $ContentFiles = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query ($WQLSelect)

        If ($ContentFiles.ContentSource ) { 
            If (!$LookupPaths.($strGUID) ) { $Result = $LookupPaths.Add($strGUID,(Trim-SourcePath($ContentFiles.ContentSource))) }
            Trim-SourcePath($ContentFiles.ContentSource) 
        }
        Else { 
            $WQLSelect = (   "SELECT DISTINCT SMS_Content.ContentSource FROM SMS_CIToContent JOIN SMS_Content ON SMS_Content.ContentUniqueID = SMS_CIToContent.ContentUniqueID  WHERE SMS_CIToContent.ContentUniqueID = '$strGUID'")
            $ContentFiles = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query ($WQLSelect)
            If ($ContentFiles.ContentSource ) { 
                If (!$LookupPaths.($strGUID) ) { 
                    $Result = $LookupPaths.Add($strGUID,(Trim-SourcePath($ContentFiles.ContentSource))) 
                    Trim-SourcePath $ContentFiles.ContentSource 
                }
                Else {
                    $Result = $LookupPaths.Add($strGUID,"Error: Could not find content source !")
                    "Error: Could not find content source !" 
                }
             }
        }
    }
}
 
Function Trim-SourcePath() {
[CmdletBinding()]
PARAM ( $SourcePath )
    If ( $SourcePath.ToUpper().IndexOf(("\\Resswdmlp01\dml$\Windows\").ToUpper()) -ge 0 ) {
        $SourcePath.SubString(("\\Resswdmlp01\dml$\Windows\").Length,$SourcePath.Length - ("\\Resswdmlp01\dml$\Windows\").Length)
    } 
    ELSE { $SourcePath  }
}


Function Get-ShortNameFromGUID() {
[CmdletBinding()]   
PARAM 
(   [Parameter(Position=1)] $strGUID   )
    If ( $Lookups.("$strGUID")) { $Lookups.("$strGUID")  }
    Else { 
        $SQLSelect = ("SELECT dbo.v_LocalizedCIProperties.DisplayName
                       FROM dbo.v_UpdateCIs 
                       INNER JOIN dbo.v_LocalizedCIProperties ON dbo.v_UpdateCIs.CI_ID = dbo.v_LocalizedCIProperties.CI_ID
                       WHERE (dbo.v_UpdateCIs.CI_UniqueID = N'$strGUID') AND (dbo.v_LocalizedCIProperties.LocaleID = 9)")

        $UpdateInfo = Invoke-SQL -SQLServer $SQLServer  -SQLDBName $SQLDBName  -SQLSelect $SQLSelect
        If ( $UpdateInfo.DisplayName ) { 
            $Result = $Lookups.Add($strGUID,$UpdateInfo.DisplayName) 
            $UpdateInfo.DisplayName
        }
    }
}


Function Get-AssignmentFromGUID() {
[CMDLETBinding()]
PARAM
(   [Parameter(Position=1)] $strAssignmentUniqueID   )  # with braces

    If ( $Lookups.("$strAssignmentUniqueID")) { $Lookups.("$strAssignmentUniqueID")  }
    Else {
        $WQLSelect = "SELECT AssignmentName FROM SMS_UpdateGroupAssignment where AssignmentUniqueID = '$strAssignmentUniqueID'"
        $Assignment = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query $WQLSelect
        If ( !$Assignment.AssignmentName ) {  
            $WQLSelect = "SELECT AssignmentName FROM SMS_UpdatesAssignment where AssignmentUniqueID = '$strAssignmentUniqueID'"
            $Assignment = get-WMIObject -ComputerName $SiteServer  -Namespace "root/SMS/Site_$SiteCode" -Query $WQLSelect
        }
        If (!$Lookups.("$strAssignmentUniqueID") ) { $Result = $Lookups.Add($strAssignmentUniqueID, $Assignment.AssignmentName ) }
        $Assignment.AssignmentName 
    }
}






############################################################
#                          MAIN
############################################################

$ErrorActionPreference = "SilentlyContinue"
#$ErrorActionPreference = "Stop"

# Initialize Variables
If (!$ClientLogsFolder) { $ClientLogsFolder =  $PSScriptRoot           }
If (!$SiteServer)       { $SiteServer       =  'XSPW10W200P'           }
If (!$SiteCode)         { $SiteCode         =  'P00'                   }
If (!$SQLServer)        { $SQLServer        =  'XSPW10W207S'           }
If (!$SQLDBName)        { $SQLDBName        =  'SCCM_' + $SiteCode     }
If (!$DateStart)        { 
    $NumDaysBack = Read-Host "How many days back in the log files should be searched?"
    $DateStart = (Get-Date).AddDays(-$NumDaysBack) 
    #$NumDays = Read-Host "How many days of logs should be searched?  ( Enter for current date )"
    #If (!$NumDays) { $NumDays = $NumDaysBack  } 
    #$DateEnd = (Get-Date).AddDays(-$NumDaysBack).AddDays($NumDays)
    $DateEnd = (Get-Date)
}  
$StartTime = Get-Date
Write-Host 'Script Started  ' $StartTime

$LastLogDate = $Null
$LastLogTime = $Null
$LastLogComponent = $Null 
$LastLogThread = $Null
$Lookups = @{}  
$LookupPaths = @{}
$Deployments = @{}

# Initialize Constants
$strOutputFile = ($ClientLogsFolder + '\SCCM_Client_Log_File_Parser.txt')
If ( Get-Item $strOutputFile -ErrorAction SilentlyContinue  ) { Remove-Item  $strOutputFile }

$Result = Log-Append -strLogFileName $strOutputFile -strLogText ('LogDateTime'  + "`t" + 'LogComponent'  + "`t" + 'LogThread' + "`t" + 'Notes'  + "`t" + 'LogText'  + "`t" + 'LogFile' + "`t" + 'LogType')

$Result = Load-SCCMLogs $ClientLogsFolder

$EndTime = get-Date
Write-Host 'Script Complete.'  $StartTime    $EndTime 
pause

