<# ----- About: ----
    # Bulk Set SW Backup GUI Password 
    # Revision v12 - 2021-09-13
    # Author: Eric Harless, Head Backup Nerd - N-able 
    # Twitter @Backup_Nerd  Email:eric.harless@n-able.com
    # Modifications: Christopher Bledsoe, Tier II Tech - IPM Computers
    # Email: cbledsoe@ipmcomputers.com
    # Reddit https://www.reddit.com/r/Nable/
# -----------------------------------------------------------#>  ## About

<# ----- Legal: ----
    # Sample scripts are not supported under any N-able support program or service.
    # The sample scripts are provided AS IS without warranty of any kind.
    # N-able expressly disclaims all implied warranties including, warranties
    # of merchantability or of fitness for a particular purpose. 
    # In no event shall N-able or any other party be liable for damages arising
    # out of the use of or inability to use the sample scripts.
# -----------------------------------------------------------#>  ## Legal

<# ----- Compatibility: ----
    # For use with the Standalone edition of N-able Backup
# -----------------------------------------------------------#>  ## Compatibility

<# ----- Behavior: ----
    # Check / Get / Store secure credentials 
    # Authenticate to https://backup.management console
    # Check partner level / Enumerate partners/ GUI select partner
    # Enumerate devices / GUI select devices
    # Prompt / Set / Wipe GUI password via Remote commands
    #
    # Use the -AllPartners switch parameter to skip GUI partner selection
    # Use the -AllDevices switch parameter to skip GUI device selection
    #
    # Use the -SetGUIPassword (default) parameter to be prompted to enter a Secure GUI Password to be applied
    # Use the -RestoreOnly parameter with the -SetGUIPassword parameter to allow restores when GUI password is set
    # Use the -WipeGUIPassword parameter to clear the GUI password from selected devices
    # Use the -ClearCredentials parameter to remove stored API credentials at start of script

    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/json-api/home.htm
    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/console/remote-commands.htm
# -----------------------------------------------------------#>  ## Behavior

#[CmdletBinding(DefaultParameterSetName="SetGUIPW")]
#    Param (
#        [Parameter(ParameterSetName="WipeGUIPW",Mandatory=$False)] [Switch]$WipeGUIPassword,  ## Clear GUI Password   
#        [Parameter(ParameterSetName="SetGUIPW",Mandatory=$False)] [switch]$SetGUIPassword,    ## Specify GUI Password to set
#        [Parameter(ParameterSetName="SetGUIPW",Mandatory=$False)] [Switch]$RestoreOnly,       ## Allow Restore Only GUI Access
#        [Parameter(ParameterSetName="SetGUIPW",Mandatory=$False)] 
#        [Parameter(ParameterSetName="WipeGUIPW",Mandatory=$False)][Switch]$AllPartners,       ## Skip partner selection
#        [Parameter(ParameterSetName="SetGUIPW",Mandatory=$False)] 
#        [Parameter(ParameterSetName="WipeGUIPW",Mandatory=$False)] [Switch]$AllDevices,       ## Skip device selection             
#        [Parameter(Mandatory=$False)] [switch] $ClearCredentials,                             ## Remove Stored API Credentials at start of script
#        
#    )

#region ----- Environment, Variables, Names and Paths ----
  $Script:strLineSeparator = "  ---------"
  $urlJSON = 'https://api.backup.management/jsonapi'
  $mxbPath = ${env:ProgramData} + "\MXB\Backup Manager"
  $CurrentDate = Get-Date -format "yyy-MM-dd_hh-mm-ss"
  # ALL PARTNERS / ALL DEVICES BOOLEANS
  $AllDevices = [bool]$i_AllDevices
  $AllPartners = [bool]$i_AllPartners

  #Clear-Host
  $ErrorActionPreference = 'Continue'
  Write-Host "  Bulk Set GUI Password `n"
  #$Syntax = Get-Command $PSCommandPath -Syntax ; Write-Host "Script Parameter Syntax:`n`n  $Syntax"
  Write-Host "  Current Parameters:"
  Write-Host "  -AllPartners     = $AllPartners"
  Write-Host "  -AllDevices      = $AllDevices"
  Write-Host "  -SetGUIPassword  = $SetGUIPassword"
  Write-Host "  -RestoreOnly     = $RestoreOnly"
  Write-Host "  -WipeGUIPassword = $WipeGUIPassword"
  
  #$scriptpath = $MyInvocation.MyCommand.Path
  #$dir = Split-Path $scriptpath
  #Push-Location $dir
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000

  # GENERATE RANDOMIZED PASSWORD UP TO LEN($I_GUILENGTH)
  if (($i_GUIlength -eq 0) -or ($i_GUIlength -lt 8)) {
    $i_GUIlength = 8
  }
  if (($i_GUIpassword -eq $null) -or ($i_GUIpassword -eq "NULL")) {
    $password = -join ((33..33) + (35..38) + (42..42) + (50..57) + (63..72) + (74..75) + (77..78) + (80..90) + (97..104) + (106..107) + (109..110) + (112..122) | Get-Random -Count $i_GUIlength | ForEach-Object {[char]$_})
  } else {
    $password = $i_GUIpassword
  }
  $SecurePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
  # SET PASSWORD WIPE
  if ($i_BackupCMD -eq "-WipeGUIPassword") {
    $WipeGUIPassword = $True
  }
#endregion ----- Environment, Variables, Names and Paths ----

#region ----- Functions ----
#region ----- Data Conversion ----
  Function Convert-UnixTimeToDateTime($inputUnixTime){
    if ($inputUnixTime -gt 0 ) {
      $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
      $epoch = $epoch.ToUniversalTime()
      $epoch = $epoch.AddSeconds($inputUnixTime)
      return $epoch
    } else {
      return ""
    }
  }  ## Convert epoch time to date time 
#endregion ----- Data Conversion ----

#region ----- Authentication ----
  Function Set-APICredentials {
    Write-Host $Script:strLineSeparator 
    Write-Host "  Setting Backup API Credentials"
    ## CHECK FOR EXISTING API FILE
    if (Test-Path $APIcredpath) {
      Write-Host $Script:strLineSeparator
      Write-Host "  Backup API Credential Path Present"
    } else {
      New-Item -ItemType Directory -Path $APIcredpath
    }
    ## SET PARTNER NAME
    Write-Host "  Enter Exact, Case Sensitive Partner Name for N-able Backup.Management API i.e. 'Acme, Inc (bob@acme.net)'"
    if ($i_PartnerName -eq $null) {
      DO{$Script:PartnerName = Read-Host "  Enter Login Partner Name"}
      WHILE ($PartnerName.length -eq 0)
    } elseif ($i_PartnerName -ne $null) {
      $PartnerName = $i_PartnerName
    }
    ## SET BACKUP CREDENTIALS
    $BackupCred = New-Object -TypeName PSObject
    $BackupCred | Add-Member -MemberType NoteProperty -Name PartnerName -Value "$PartnerName"
    if (($i_BackupUser -eq $null) -or ($i_BackupPWD -eq $null)) {               ## NO CREDENTIALS PASSED
      $BackupCred = Get-Credential -UserName "" -Message 'Enter Login Email and Password for N-able Backup.Management API'
    } elseif (($i_BackupUser -ne $null) -and ($i_BackupPWD -ne $null)) {        ## CREDENTIALS PASSED
      $BackupCred | Add-Member -MemberType NoteProperty -Name UserName -Value "$i_BackupUser"
      $BackupCred | Add-Member -MemberType NoteProperty -Name Password -Value "$i_BackupPWD"
    }
    ## WRITE API FILE
    $PartnerName | out-file $APIcredfile
    $BackupCred.UserName | Out-file -append $APIcredfile
    $BackupCred.Password | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-file -append $APIcredfile
    Start-Sleep -milliseconds 300
    Send-APICredentialsCookie  ## Attempt API Authentication
  }  ## Set API credentials if not present

  Function Get-APICredentials {
    $Script:True_path = "C:\ProgramData\MXB\"
    $Script:APIcredfile = join-path -Path $True_Path -ChildPath "$env:computername API_Credentials.Secure.txt"
    $Script:APIcredpath = Split-path -path $APIcredfile

    if (($ClearCredentials) -and (Test-Path $APIcredfile)) {                    ## CLEAR API CREDENTIALS
      Remove-Item -Path $Script:APIcredfile
      $ClearCredentials = $Null
      Write-Host $Script:strLineSeparator 
      Write-Host "  Backup API Credential File Cleared"
      Send-APICredentialsCookie  ## Retry Authentication
    } else {                                                                    ## RETRIEVE API CREDENTIALS
      Write-Host $Script:strLineSeparator 
      Write-Host "  Getting Backup API Credentials" 
  
      if (Test-Path $APIcredfile) {                                             ## API FILE EXISTS
        Write-Host $Script:strLineSeparator        
        Write-Host "  Backup API Credential File Present"
        $APIcredentials = get-content $APIcredfile
        
        $Script:cred0 = [string]$APIcredentials[0] 
        $Script:cred1 = [string]$APIcredentials[1]
        $Script:cred2 = $APIcredentials[2] | Convertto-SecureString 
        $Script:cred2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Script:cred2))

        Write-Host $Script:strLineSeparator 
        Write-Host "  Stored Backup API Partner  = $Script:cred0"
        Write-Host "  Stored Backup API User     = $Script:cred1"
        Write-Host "  Stored Backup API Password = Encrypted"
      } else {                                                                  ## API FILE DOES NOT EXIST
        Write-Host $Script:strLineSeparator 
        Write-Host "  Backup API Credential File Not Present"
        Set-APICredentials  ## Create API Credential File if Not Found
      }
    }
  }  ## Get API credentials if present

  Function Send-APICredentialsCookie {
    Get-APICredentials  ## Read API Credential File before Authentication
    $url = $urlJSON
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.method = 'Login'
    $data.params = @{}
    $data.params.partner = $Script:cred0
    $data.params.username = $Script:cred1
    $data.params.password = $Script:cred2

    $webrequest = Invoke-WebRequest -Method POST `
      -ContentType 'application/json' `
      -Body (ConvertTo-Json $data) `
      -Uri $url `
      -SessionVariable Script:websession `
      -UseBasicParsing
      $Script:cookies = $websession.Cookies.GetCookies($url)
      $Script:websession = $websession
      $Script:Authenticate = $webrequest | convertfrom-json
    #Debug Write-Host "$($Script:cookies[0].name) = $($cookies[0].value)"

    if ($authenticate.visa) {
      $Script:visa = $authenticate.visa
    } else {
      Write-Host    $Script:strLineSeparator 
      Write-Host "  Authentication Failed: Please confirm your Backup.Management Partner Name and Credentials"
      Write-Host "  Please Note: Multiple failed authentication attempts could temporarily lockout your user account"
      Write-Host    $Script:strLineSeparator
      Set-APICredentials  ## Create API Credential File if Authentication Fails
    }
  }  ## Use Backup.Management credentials to Authenticate
#endregion ----- Authentication ----

#region ----- Backup.Management JSON Calls ----
  Function CallJSON($url,$object) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($object)
    $web = [System.Net.WebRequest]::Create($url)
    $web.Method = "POST"
    $web.ContentLength = $bytes.Length
    $web.ContentType = "application/json"
    $stream = $web.GetRequestStream()
    $stream.Write($bytes,0,$bytes.Length)
    $stream.close()
    $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
    return $reader.ReadToEnd()| ConvertFrom-Json
    $reader.Close()
  }

  Function Send-GetPartnerInfo ($PartnerName) {                
    $url = $urlJSON
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.visa = $Script:visa
    $data.method = 'GetPartnerInfo'
    $data.params = @{}
    $data.params.name = [String]$PartnerName

    $webrequest = Invoke-WebRequest -Method POST `
      -ContentType 'application/json' `
      -Body (ConvertTo-Json $data -depth 5) `
      -Uri $url `
      -SessionVariable Script:websession `
      -UseBasicParsing
      #$Script:cookies = $websession.Cookies.GetCookies($url)
      $Script:websession = $websession
      $Script:Partner = $webrequest | convertfrom-json

    $RestrictedPartnerLevel = @("Root","Sub-root","Distributor")
    <#---# POWERSHELL 2.0 #---#>
    if ($RestrictedPartnerLevel -notcontains $Partner.result.result.Level) {
    #---#>
    <#---# POWERSHELL 3.0+ #--->
    if ($Partner.result.result.Level -notin $RestrictedPartnerLevel) {
    #---#>
      [String]$Script:Uid = $Partner.result.result.Uid
      [int]$Script:PartnerId = [int]$Partner.result.result.Id
      [String]$script:Level = $Partner.result.result.Level
      [String]$Script:PartnerName = $Partner.result.result.Name
      Write-Host $Script:strLineSeparator
      Write-Host "  $PartnerName - $partnerId - $Uid"
      Write-Host $Script:strLineSeparator
    } else {
      Write-Host $Script:strLineSeparator
      Write-Host "  Lookup for $($Partner.result.result.Level) Partner Level Not Allowed"
      Write-Host $Script:strLineSeparator
      $Script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
      Send-GetPartnerInfo $Script:partnername
    }

    if ($partner.error) {
      Write-Host "  $($partner.error.message)"
      $Script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
      Send-GetPartnerInfo $Script:partnername
    }
  } ## Send-GetPartnerInfo API Call

  Function Send-EnumeratePartners {
    # ----- Get Partners via EnumeratePartners -----
    # (Create the JSON object to call the EnumeratePartners function)
    $objEnumeratePartners = (New-Object PSObject | 
      Add-Member -PassThru NoteProperty jsonrpc '2.0' |
      Add-Member -PassThru NoteProperty visa $Script:visa |
      Add-Member -PassThru NoteProperty method 'EnumeratePartners' |
      Add-Member -PassThru NoteProperty params @{
        parentPartnerId = $PartnerId 
        fetchRecursively = "false"
        fields = (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22) 
      } |
      Add-Member -PassThru NoteProperty id '1') | ConvertTo-Json -Depth 5
    
    # (Call the JSON Web Request Function to get the EnumeratePartners Object)
    [array]$Script:EnumeratePartnersSession = CallJSON $urlJSON $objEnumeratePartners
    #$Script:visa = $EnumeratePartnersSession.visa
    #Write-Host    $Script:strLineSeparator
    #Write-Host    "  Using Visa:" $Script:visa
    #Write-Host    $Script:strLineSeparator
    # (Added Delay in case command takes a bit to respond)
    Start-Sleep -Milliseconds 100
    # (Get Result Status of EnumerateAccountProfiles)
    $EnumeratePartnersSessionErrorCode = $EnumeratePartnersSession.error.code
    $EnumeratePartnersSessionErrorMsg = $EnumeratePartnersSession.error.message
    
    # (Check for Errors with EnumeratePartners - Check if ErrorCode has a value)
    if ($EnumeratePartnersSessionErrorCode) {
      Write-Host    $Script:strLineSeparator
      Write-Host    "  EnumeratePartnersSession Error Code:  $EnumeratePartnersSessionErrorCode"
      Write-Host    "  EnumeratePartnersSession Message:  $EnumeratePartnersSessionErrorMsg"
      Write-Host    $Script:strLineSeparator
      Write-Host    "  Exiting Script"
      # (Exit Script if there is a problem)
      #Break Script
    } else {
      # (No error)
      $Script:EnumeratePartnersSessionResults = $EnumeratePartnersSession.result.result | 
      select-object Name,@{l='Id';e={($_.Id).tostring()}},Level,ExternalCode,ParentId,LocationId,* -ExcludeProperty Company -ErrorAction Ignore
      $Script:EnumeratePartnersSessionResults | ForEach-Object {
        $_.CreationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.CreationTime))
      }
      $Script:EnumeratePartnersSessionResults | ForEach-Object {
        if ($_.TrialExpirationTime  -ne "0") {
          $_.TrialExpirationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialExpirationTime))
        }
      }
      $Script:EnumeratePartnersSessionResults | ForEach-Object {
        if ($_.TrialRegistrationTime -ne "0") {
          $_.TrialRegistrationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialRegistrationTime))
        }
      }
      $Script:SelectedPartners = $EnumeratePartnersSessionResults | Select-object * | 
        Where-object {$_.name -notlike "001???????????????- Recycle Bin"} | Where-object {$_.Externalcode -notlike '`[??????????`]* - ????????-????-????-????-????????????'}
      $Script:SelectedPartner = $Script:SelectedPartners += @( [pscustomobject]@{Name=$PartnerName;Id=[string]$PartnerId;Level='<ParentPartner>'} ) 
      
      if ($AllPartners) {
        $script:Selection = $Script:SelectedPartners | 
          Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name
        Write-Host    $Script:strLineSeparator
        Write-Host    "  All Partners Selected"
      } else {
        $script:Selection = $Script:SelectedPartners |  
          Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name | 
            out-gridview -Title "Current Partner | $partnername" -OutputMode Single
        if($null -eq $Selection) {
          # Cancel was pressed
          # Run cancel script
          Write-Host    $Script:strLineSeparator
          Write-Host    "  No Partners Selected"
          Break
        } else {
            # OK was pressed, $Selection contains what was chosen
            # Run OK script
            [int]$script:PartnerId = $script:Selection.Id
            [String]$script:PartnerName = $script:Selection.Name
        }
      }
    }
  }  ## Send-EnumeratePartners API Call

  Function Send-GetDevices {
    $url = $urlJSON
    $method = 'POST'
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.visa = $Script:visa
    $data.method = 'EnumerateAccountStatistics'
    $data.params = @{}
    $data.params.query = @{}
    $data.params.query.PartnerId = [int]$PartnerId
    $data.params.query.Filter = $Filter1
    $data.params.query.Columns = @("AU","AR","AN","MN","AL","LN","OP","OI","OS","PD","AP","PF","PN","CD","TS","TL","T3","US","AA843","AA77","AA2048")
    $data.params.query.OrderBy = "CD DESC"
    $data.params.query.StartRecordNumber = 0
    $data.params.query.RecordsCount = 2000
    $data.params.query.Totals = @("COUNT(AT==1)","SUM(T3)","SUM(US)")
    $jsondata = (ConvertTo-Json $data -depth 6)

    $params = @{
      Uri         = $url
      Method      = $method
      Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
      Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
      ContentType = 'application/json; charset=utf-8'
    }

    $Script:DeviceResponse = Invoke-RestMethod @params

    $Script:DeviceDetail = @()
    ForEach ( $DeviceResult in $DeviceResponse.result.result ) {
      $Script:DeviceDetail += New-Object -TypeName PSObject -Property @{
        AccountID      = [Int]$DeviceResult.AccountId;
        PartnerID      = [string]$DeviceResult.PartnerId;
        DeviceName     = $DeviceResult.Settings.AN -join '' ;
        ComputerName   = $DeviceResult.Settings.MN -join '' ;
        DeviceAlias    = $DeviceResult.Settings.AL -join '' ;
        PartnerName    = $DeviceResult.Settings.AR -join '' ;
        Reference      = $DeviceResult.Settings.PF -join '' ;
        Creation       = Convert-UnixTimeToDateTime ($DeviceResult.Settings.CD -join '') ;
        TimeStamp      = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TS -join '') ;  
        LastSuccess    = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TL -join '') ;                                                                                                                                                                                                               
        SelectedGB     = (($DeviceResult.Settings.T3 -join '') /1GB) ;  
        UsedGB         = (($DeviceResult.Settings.US -join '') /1GB) ;  
        DataSources    = $DeviceResult.Settings.AP -join '' ;                                                                
        Account        = $DeviceResult.Settings.AU -join '' ;
        Location       = $DeviceResult.Settings.LN -join '' ;
        Notes          = $DeviceResult.Settings.AA843 -join '' ;
        GUIPassword    = $DeviceResult.Settings.AA2048 -join '' ;                                                                    
        TempInfo       = $DeviceResult.Settings.AA77 -join '' ;
        Product        = $DeviceResult.Settings.PN -join '' ;
        ProductID      = $DeviceResult.Settings.PD -join '' ;
        Profile        = $DeviceResult.Settings.OP -join '' ;
        OS             = $DeviceResult.Settings.OS -join '' ;                                                                
        ProfileID      = $DeviceResult.Settings.OI -join ''
      }
    }
  } ## Send-GetDevices API Call

  Function Send-RemoteCommand { 
    if ($SecurePassword.length -ge 1) {
      $UnsecureGUIPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))
    }
    if ($RestoreOnly) {
      $PasswordParam = "password $($UnsecureGUIPassword)`nrestore_only allow"
    } else {
      $PasswordParam = "password $($UnsecureGUIPassword)`nrestore_only disallow"
    }
    if ($i_BackupCMD -eq "-WipeGUIPassword") {
      $UnsecureGUIPassword = ""
      Write-Host -NoNewline "Wiping GUI Password"
    }

    $url = "https://backup.management/jsonrpcv1"
    $method = 'POST'
    $Script:data = @{}
    $data.jsonrpc = '2.0'
    $data.id = 'jsonrpc'
    $data.method = 'SendRemoteCommands'
    $data.params = @{}
    $data.params.command = "set gui password"
    $data.params.parameters = "$PasswordParam"
    $data.params.ids = @([System.Int32[]]$selecteddevice.accountid)
    $jsondata = (ConvertTo-Json $data -depth 6)
    #$jsondata  ## Debug
    Write-Host "`n##Sending Remote Command##`n$($data.params.command)`n$CommandParameters" ## Output sent Remote Command

    $params = @{
      Uri         = $url
      Method      = $method
      Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
      Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
      ContentType = 'application/json; charset=utf-8'
    }  

    $Script:sendResult = Invoke-RestMethod @params
    #$Script:sendResult.result.result | Select-Object Id,@{Name="Status"; Expression={$_.Result.code}},@{Name="Message"; Expression={$_.Result.Message}} | Format-Table
    Write-Host " $($Script:sendResult.result.result.id) $($Script:sendResult.result.result.result.code)"
  } ## Send-RemoteCommand API Call

  Function UpdateCustomColumnA($DeviceId,$ColumnId,$Message) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization","Bearer $Script:visa")
    $headers.Add("Content-Type","application/json")
  
    $body = "{
      `n    `"jsonrpc`":`"2.0`",
      `n    `"id`":`"jsonrpc`",
      `n    `"visa`":`"$Script:visa`",
      `n    `"method`":`"UpdateAccountCustomColumnValues`",
      `n    `"params`":{
      `n      `"accountId`": $DeviceId,
      `n      `"values`": [[$ColumnId,`"$Message`"]]
      `n      }
      `n    }
      `n"

    $Script:updateCC = Invoke-RestMethod $urlJSON -Method 'POST' -Headers $headers -Body $body
    Write-Host $Script:strLineSeparator
    Write-Host "  UpdateA : $($Script:updateCC)"
  } ## UpdateCustomColumnA API Call

  Function UpdateCustomColumnB($DeviceId,$ColumnId,$Message) {
    $url = $urlJSON
    $method = 'POST'
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.visa = $Script:visa
    $data.method = 'UpdateAccountCustomColumnValues'
    $data.params = @{}
    $data.params.accountId = [System.Int32[]]$DeviceId
    $data.params.values = @($ColumnID,$Message)
    $jsondata = (ConvertTo-Json $data -depth 2)

    $params = @{
      Uri         = $url
      Method      = $method
      Headers     = @{"Authorization" = "Bearer $Script:visa"}
      Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
      ContentType = 'application/json; charset=utf-8'
    }
    
    $Script:updateCC = Invoke-RestMethod @params
    Write-Host $Script:strLineSeparator
    Write-Host "  UpdateB : $($Script:updateCC)"
  } ## UpdateCustomColumnB API Call

  Function UpdateCustomColumnC($DeviceId,$ColumnId,$Message) {
    $objModifyAccount = (New-Object PSObject | 
    Add-Member -PassThru NoteProperty jsonrpc ‘2.0’ | 
    Add-Member -PassThru NoteProperty visa $Script:visa |
    Add-Member -PassThru NoteProperty method ‘UpdateAccountCustomColumnValues’ |
    Add-Member -PassThru NoteProperty params @{
      accountId = [System.Int32]$DeviceId
      values = @($ColumnId,$Message)
    }) | ConvertTo-Json -Depth 2
    # (Call the JSON Web Request Function to get the ModifyAccount Object)
    $ModifyAccountSession = CallJSON $urlJSON $objModifyAccount
    # (Added Delay in case command takes a bit to respond)
    Start-Sleep -Milliseconds 100
    # (Get Result Status of ModifyAccountSession)
    $ModifyAccountSessionErrorCode = $ModifyAccountSession.error.code
    $ModifyAccountSessionErrorMsg = $ModifyAccountSession.error.message
    # (Check for Errors with ModifyAccountSession - Check if ErrorCode has a value)
    if ($ModifyAccountSessionErrorCode) {
      Write-Host $Script:strLineSeparator
      Write-Host "  ModifyAccountSession Error Code:  $ModifyAccountSessionErrorCode"
      Write-Host "  ModifyAccountSession Message:  $ModifyAccountSessionErrorMsg"
      Write-Host $Script:strLineSeparator
      Write-Host "  DEVICE | $($DeviceId) | $($selecteddevice.DeviceName) | ASSIGN GUI PW ERROR | $ModifyAccountSessionErrorMsg"
      # (Exit Script if there is a problem)
      #Break Script
    } elseif (-not $ModifyAccountSessionErrorCode) {
      # (No error)
      Write-Host $Script:strLineSeparator
      Write-Host "  SUCCESS UPDATING GUI PW COLUMN"
    }
    Write-Host $Script:strLineSeparator
    Write-Host "  UpdateC : $ModifyAccountSessionErrorMsg"
  } ## UpdateCustomColumnC API Call
#endregion ----- Backup.Management JSON Calls ----
#endregion ----- Functions ----

$switch = $i_BackupCMD
Send-APICredentialsCookie
Write-Host $Script:strLineSeparator
Write-Host "" 
Send-GetPartnerInfo $Script:cred0
#Send-EnumeratePartners
if ((-not $AllPartners) -and ($i_BackupName -ne $null)) {
  Send-GetPartnerInfo $i_BackupName
}
$filter1 = "AT == 1 AND PN != 'Documents'"   ### Excludes M365 and Documents devices from lookup.
Send-GetDevices $partnerId

if ($AllDevices) {
  $script:SelectedDevices = $DeviceDetail | 
    Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo
  Write-Host    $Script:strLineSeparator
  Write-Host    "  $($SelectedDevices.AccountId.count) Devices Selected"
} elseif (-not $allDevices) {
  #$script:SelectedDevices = $DeviceDetail | 
  #  Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo | 
  #  Out-GridView -title "Current Partner | $partnername" -OutputMode Multiple
  # OBTAIN BACKUP ACCOUNT ID
  [xml]$statusXML = Get-Content -LiteralPath $mxbPath\StatusReport.xml
  $BackupID = $statusXML.Statistics.Account
  if ($BackupID -ne $null) {
    $script:SelectedDevices = $DeviceDetail | 
      Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo | 
        Where-object {$_.DeviceName -eq $BackupID}
    Write-Host $Script:strLineSeparator
    Write-Host "  $($SelectedDevices.AccountId.count) Devices Selected"
  }
}    

if($null -eq $SelectedDevices) {
  # Cancel was pressed
  # Run cancel script
  Write-Host $Script:strLineSeparator
  Write-Host "  No Devices Selected"
  Break
} else {
  # OK was pressed, $Selection contains what was chosen
  # Run OK script
  $script:SelectedDevices | 
    Select-Object PartnerId,PartnerName,Reference,@{Name="AccountID"; Expression={[int]$_.AccountId}},DeviceName,ComputerName,DeviceAlias,GUIPassword,Creation,TimeStamp | 
        Sort-object AccountId | Format-Table

  if ($i_BackupCMD -eq "-SetGUIPassword") {
    #$SecurePassword = Read-Host "  Enter Backup Manager GUI Password to be applied to $($SelectedDevices.AccountId.count) Devices" -AsSecureString
    Write-Host $Script:strLineSeparator
    Write-Host "  Applying GUI Password to $($SelectedDevices.AccountId.count) Devices, please be patient."
  }

  foreach ($selecteddevice in $SelectedDevices) {
    $device = $selecteddevice.DeviceName
    # UPDATE CUSOTM COLUMN 'GUI PW'
    Write-Host $Script:strLineSeparator
    Write-Host "  Updating GUI PW Column for $device - " $selecteddevice.AccountID 2048 $password
    UpdateCustomColumnA $selecteddevice.AccountID 2048 $password
    Start-Sleep -Milliseconds 500
    # SEND REMOTE COMMAND
    Write-Host $Script:strLineSeparator
    Write-Host "  Updating GUI PW for $device"
    Send-RemoteCommand
    Start-Sleep -Milliseconds 500
  }
  $o_sPassword = $password
}