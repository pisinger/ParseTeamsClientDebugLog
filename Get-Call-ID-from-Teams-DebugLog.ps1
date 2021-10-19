# https://github.com/pisinger

<#
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
#>

<#
	purpose: If you do need the Call-ID and/or Meeting-ID for further troubleshooting/investigation
	
	To get Teams Debug Logs -> Ctrl + Alt + Shift + 1
	https://docs.microsoft.com/en-us/microsoftteams/log-files

	Examples
	.\Get-Call-ID-from-Teams-DebugLog.ps1 -ClientInfo
	.\Get-Call-ID-from-Teams-DebugLog.ps1 -OnlyCallIDs
	.\Get-Call-ID-from-Teams-DebugLog.ps1 | ft
	.\Get-Call-ID-from-Teams-DebugLog.ps1 -Path C:\temp
	$calls = .\Get-Call-ID-from-Teams-DebugLog.ps1
	$calls | fl
	
	TimeStartUTC        : 2021-10-07 10:58:08
	Established         : 10:58:12
	TimeEnd             : 11:02:26
	CallId              : d5dd25b0-1eda-4190-b3fa-5d97225c55ba
	Direction           : Inbound
	CallType            : Teams
	Modality            : Audio
	ToFrom              : John Doe
	Scenario            : call_accept
	TerminatedReason    : 1
	CallControllerCode  : 0
	CallEndReasonPhrase : LocalUserInitiated
	MeetingId           :
#>

param(
	[ValidateScript({Test-Path $_})]
	[string]$Path = "$env:USERPROFILE\Downloads",
    [switch]$OnlyCallIDs,
	[switch]$ClientInfo
)

$excluded = "(sync|calling|cdl|cdlWorker|chatListData|experience_renderer|extensibility)\.txt"
$Files = Get-ChildItem $Path -Include *MSTeams*.txt* -Recurse | where Name -notmatch $excluded

# get client/endpoint info only
IF ($ClientInfo) {
	$object = @()
	
	foreach ($File in $Files) {
		
		[string]$log = Get-Content -Path $File.FullName;
		$log = $log | ConvertTo-Json | ConvertFrom-Json;
		$log = ([string]$log -split "} }",2)[0];
		$log = $log + "} }";
		$j = ($log | ConvertFrom-Json)
		
		$object += [pscustomobject]@{
			File = $($File.FullName)
			Name = $j.user.profile.name
			Upn =  $j.user.profile.upn
			SessionId = $j.sessionId
			TimeZoneUTC = $j.timezone
			Auth = $j.context.authStack
			Issuer = $j.user.profile.iss
			Tenant = $j.user.profile.tid
			Region = $j.context."UserInfo.Region"
			Env = $j.context.environment
			Ring = $j.context."UserInfo.Ring"
			RingName = $j.ring.friendlyName
			ClientType = $j.context.clientType
			PlatformId = $j.context."AppInfo.PlatformId"
			Version = $j.context.appversion
			VersionDate = $j.context.buildtime
			SlimcoreVersion = $j.version.slimcoreVersion			
			Device = $j.context."DeviceInfo.SystemProductName"
			DeviceManu = $j.context."DeviceInfo.SystemManufacturer"
			OSVersion = $j.context.osversion
			Arch = $j.context.osarchitecture
			MemoryGB = [math]::round($j.context.totalMemory / 1000000000)
			Cpu = $j.context.cpumodel
			CpuSpeed = $j.context.cpuspeed
			CpuCores = $j.context.cores
			PublicIP = $j.user.profile.ipaddr
		}		
	}
	$object | sort -unique SessionId
	break
}

$logs = @()
foreach ($File in $Files) {    
	$logs += Get-Content -Path $File.FullName
}

function Calls () {
	param ( 
		[string]$StartTime,[string]$ConnectTime,[string]$EndTime,
		$CallId,$Direction,$CallType,$Modality,$ToFrom,
		$Scenario,$TerminatedReason,$CallControllerCode,$CallEndReasonPhrase,
		$MeetingId
	)
		
	$object = [pscustomobject]@{
		TimeStartUTC = [string]$StartTime
		Established	= [string]$ConnectTime
		TimeEnd = [string]$EndTime
		CallId = $CallId
		Direction = $Direction
		CallType = $CallType
		Modality = $Modality
		ToFrom = $ToFrom
		Scenario = $Scenario
		TerminatedReason = $TerminatedReason
		CallControllerCode = $CallControllerCode
		CallEndReasonPhrase	= $CallEndReasonPhrase
		MeetingId = $MeetingId
	}
	return $object
}

$CallStart          = $logs | select-string '\[_createCall|\[initCall\[callId\=|newCallId = '	# |threadId=19:meet|threadId:19:meet|newCallId = '
$CallConnectDisc    = $logs | select-string 'callingservice.+(\=connected|\=disconnected)'
$ModalityType       = $logs | select-string '_stopVideo|_startVideo|startedVideo|main-video|CallingScreenSharingMixin|SharingStarted|\[StartScreenSharing\]success|\[screenSharing\]\[control\]|\[StopScreenSharing\]success|ScreenSharingControl|SharingControl initiating new viewer session'
$ConvController     = $logs | select-string 'participants.+,\"4:+'
$CallEndReason 	    = $logs | select-string 'Finish start call scenarios'
$CallEndPhrase		= $logs | select-string '"phrase":'
$TeamsInterop 	    = $logs | select-string 'ExtendedCallStateMixin|InteropCallAlert'
$IncomingCalls      = $logs | select-string 'Received incoming call'
$IncomingCallerName = $logs | select-string 'toastCallerDisplayName'

$calls = @()

IF (!$CallStart -or $OnlyCallIDs) {
	# in case log has been overridden already
	# .\Get-Call-ID-from-Teams-DebugLog.ps1 -OnlyCallIDs   
	
	TRY {
		$CallIDs = @(([RegEx]::Matches($CallConnectDisc, '(?i)callId \= .{36}').Value) -replace "callId = " | select -Unique)
		$CallIDs += @(([RegEx]::Matches($CallStart, '(?i)callId\:.{36}').Value) -replace "callId:" | select -Unique)	
		$CallIDs = $CallIDs | select -unique
	}
	CATCH {
		Write-warning "No Calling information found in log."
	}
	
    FOREACH ($callId in $CallIds) { 
		$CallControllerCode = ""
		$CallEndReasonPhrase = ""
		$Scenario = ""
		
		$StartTime = ((($CallStart | select-string $CallId) -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]
        $Disconnect = $CallConnectDisc | select-string $CallId | select-string "disconnected"
        $EndTime = ((($Disconnect -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]

        $end = ($CallEndReason | select-string "$CallId" | select -First 1)
		$endPhrase = ($CallEndPhrase | select-string "$CallId" | select -First 1)

		IF ($ConnectTime -eq $NULL -and $Direction -eq "inbound"){
			$TerminatedReason = "missed"
		}
		ELSEIF ($end){
			$TerminatedReason = (([RegEx]::Matches($end, 'terminatedReason\=.+?(?=])').Value) -split('=',2))[1]			
			$CallControllerCode = (([RegEx]::Matches($end, 'callControllerCode\=.+?(?=])').Value) -split('=',2))[1]	
			$Scenario = (([RegEx]::Matches($end, 'primaryScenario\=.+?(?=])').Value) -split('=',2))[1]
			$CallEndReasonPhrase = (([RegEx]::Matches($endPhrase, 'phrase\"\:.+?(?=")').Value) -split(':"',2))[1]
		}

        $calls += Calls $StartTime "" $EndTime $CallId "" "" "" "" $Scenario $TerminatedReason $CallControllerCode $CallEndReasonPhrase ""
    }

    $calls | select CallId, TimeStartUTC, TimeEnd, Scenario, TerminatedReason, CallControllerCode, CallEndReasonPhrase | Sort-Object EndTime -Descending
    break;
}
ELSE {
    $CallIds = @(([RegEx]::Matches($CallStart, '(?i)callId\:.{36}').Value) -replace "callId:" | select -Unique)
	$CallIds += @(([RegEx]::Matches($CallStart, '(?i)newCallId \= .{36}').Value) -replace "newCallId = " | select -Unique)
	$CallIds = $CallIds | select -unique
}

IF ($IncomingCalls) {$CallIds += ([RegEx]::Matches($IncomingCalls, '(?i)\[callId\=.{36}').Value) -replace "\[callId=" | select -Unique}
$CallIds = $CallIds.Split('',[System.StringSplitOptions]::RemoveEmptyEntries)

FOREACH ($callId in $CallIds) {	
	FOREACH ($line in ($CallStart | select-string $CallID | select -first 1)) {
		# init
		$MeetingId = ""
		$CallControllerCode = ""
		$Modality = "Audio"
		$TerminatedReason = ""
		$Scenario = ""
		$CallEndReasonPhrase = ""
		$incoming = $IncomingCalls | Select-String $CallId | select -First 1
		#$tid = $TeamsInterop | Select-String "$CallId" | select -First 1
		
		#------------------------------------------------------------
		$Connected = $CallConnectDisc | select-string $CallId | select-string " connected"
		$Disconnect = $CallConnectDisc | select-string $CallId | select-string "disconnected"
		$StartTime = (($line -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]
		$ConnectTime = ((($Connected -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
		$EndTime = ((($Disconnect -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
		#------------------------------------------------------------
		
		# check for inbound or outbound call
		IF ($line -like "*createCall*" -or $line -like "*newCall*"){
			$Direction = "Outbound"
			$DisplayName = ""

			TRY {
				$ToFrom = $ConvController | Select-String "$CallId" | select -First 1 -ErrorAction SilentlyContinue
				$ToFrom = ((([RegEx]::Matches($ToFrom, '\"\d{1}\:\+.+?(?=")')).Value) -split(':',2))[1]
			}CATCH{
				$ToFrom = ""
			}
		}
		ELSE{ 
			$Direction = "Inbound"

			TRY {
				$ToFrom = $IncomingCalls | Select-String "$CallId" | select -First 1 -ErrorAction SilentlyContinue
				$ToFrom = (([RegEx]::Matches($ToFrom, '\"\d{1}\:\+.+?(?=")').Value) -split(':',2))[1]

				$DisplayName = $IncomingCallerName | Select-String "$CallId" | select -First 1 -ErrorAction SilentlyContinue
				$DisplayName = (([RegEx]::Matches($DisplayName, 'toastCallerDisplayName\=.+?(?=])').Value) -split('=',2))[1]         
				
			}CATCH{
				$ToFrom = ""
			}
		}
		
		# check for Skype Interop Call
		#IF($tid){ $tid = (([RegEx]::Matches($tid, 'CallId\=.+?(?=])').Value) -split('=',2))[1]}
		
		# check for Call End Reason and Call Type: teams, pstn, meeting, interop
		$end = ($CallEndReason | select-string "$CallId" | select -First 1)
		$endPhrase = ($CallEndPhrase | select-string "$CallId" | select -First 1)

		IF ($ConnectTime -eq $NULL -and $Direction -eq "inbound"){
			$TerminatedReason = "missed"
		}
		ELSEIF ($end){
			$TerminatedReason = (([RegEx]::Matches($end, 'terminatedReason\=.+?(?=])').Value) -split('=',2))[1]
			$CallControllerCode = (([RegEx]::Matches($end, 'callControllerCode\=.+?(?=])').Value) -split('=',2))[1]	
			$Scenario = (([RegEx]::Matches($end, 'primaryScenario\=.+?(?=])').Value) -split('=',2))[1]
			$CallEndReasonPhrase = (([RegEx]::Matches($endPhrase, 'phrase\"\:.+?(?=")').Value) -split(':"',2))[1]
		}
		
		# AUDIO - check for Call Type	
		IF ($end -like "*create_meetup_from_link*") {$CallType = "Meeting"; $MeetingId = ((([RegEx]::Matches($line, '(?i)\:meeting_.+?(?=@)').Value)) -Replace (":meeting_"))}	
		ELSEIF ($end -like "*create_meetup*")       {$CallType = "MeetNow"; $MeetingId = ((([RegEx]::Matches($line, '(?i)\:meeting_.+?(?=@)').Value)) -Replace (":meeting_"))}
		ELSEIF ($end -like "*meetup*")              {$CallType = "_Meet_";  $MeetingId = ((([RegEx]::Matches($line, '(?i)\:meeting_.+?(?=@)').Value)) -Replace (":meeting_"))}
		#ELSEIF (($end -like "*interop_sfc_call*" -or $end -like "*call_accept*") -and $Incoming -like "*live:*") {$CallType = "Skype";$ToFrom = $DisplayName}	
		ELSEIF ($end -like "*interop_sfc_call*")    {$CallType = "Skype";$ToFrom = $DisplayName}
		ELSEIF ($Incoming -like "*live:*")          {$CallType = "Skype";$ToFrom = $DisplayName}
		ELSEIF ($Incoming -like "*sfb*")            {$CallType = "Skype4B"; $ToFrom = $DisplayName}	
		ELSEIF (($end -like "*one_to_one_call*" -or $end -like "*call_accept*") -and $ToFrom -notlike "*+*") {$CallType = "Teams"; $ToFrom = $DisplayName }
		ELSEIF ($ToFrom -like "*orgid*")            {$CallType = "Teams"; $ToFrom = $DisplayName;}
		ELSEIF (($end -like "*pstn*" -or $end -like "*call_accept*")) {$CallType = "PSTN";}
		ELSEIF ($ToFrom -like "*+*")                {$CallType = "PSTN"}
		ELSE                                        {$CallType = "undefined"}
		
		# save results
		$calls += Calls $StartTime $ConnectTime $EndTime $CallId $Direction $CallType $Modality $ToFrom $Scenario $TerminatedReason $CallControllerCode $CallEndReasonPhrase $MeetingId
		
		# VIDEO or SHARING
		IF ($ModalityType | select-string $callId) {
			# VIDEO
			IF (($ModalityType | select-string $callId) -like "*video*"){
				$Modality = "Video"
  
				IF (($ModalityType | select-string $callId) -like "*_startVideoObject*"){
					# sender
					$Connected = @(($ModalityType | select-string $callId) -like "*_startVideoObject*success*" | select -Unique)
					$Disconnect = @(($ModalityType | select-string $callId) -like "*_stopVideoObject*success*" | select -Unique)
					
					for ($i = 0; $i -lt $Connected.Length; $i++) {
						$ConnectTime = ((($Connected[$i] -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
						$EndTime = ((($Disconnect[$i] -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
						# save results
						$calls += Calls $StartTime $ConnectTime $EndTime $CallId "Outbound" $CallType $Modality $ToFrom "" "" "" "" $MeetingId 
					}
				}
				IF (($ModalityType | select-string $callId) -like "*main-video*"){
					# receiver
					$Connected = @(($ModalityType | select-string $callId) -like "*remote*video*is*started*" | select -Unique)
					$Disconnect = @(($ModalityType | select-string $callId) -like "*_stopVideo *video*stopped*" | select -Unique)
					
					for ($i = 0; $i -lt $Connected.Length; $i++) {
						$ConnectTime = ((($Connected[$i] -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
						$EndTime = ((($Disconnect[$i] -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
						# save results
						$calls += Calls $StartTime $ConnectTime $EndTime $CallId "Inbound" $CallType $Modality $ToFrom "" "" "" "" $MeetingId
					}
				}
			}
			# SHARING
			IF (($ModalityType | select-string $callId) -like "*ScreenSharing*"){
				$Modality = "Sharing"

				IF (($ModalityType | select-string $callId) -like "*startScreenSharing in call*"){
					# sender
					$Connected = @(($ModalityType | select-string $callId) -like "*startScreenSharing in call*" | select -Unique)
					$Disconnect = @(($ModalityType | select-string $callId) -like "*stopScreenSharing in call*" | select -Unique)

					for ($i = 0; $i -lt $Connected.Length; $i++) {
						$ConnectTime = ((($Connected[$i] -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
						$EndTime = ((($Disconnect[$i] -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
						# save results
						$calls += Calls $StartTime $ConnectTime $EndTime $CallId "Outbound" $CallType $Modality $ToFrom "" "" "" "" $MeetingId
					}                    
				}
				IF (($ModalityType | select-string $callId) -like "*SharingStarted*"){ 
					# receiver        
					$Connected = @(($ModalityType | select-string $callId) -like "*SharingControl initiating new viewer session*" | select -Unique)
					$Disconnect = @(($ModalityType | select-string $callId) -like "*sending event mdsc_gtc_viewer_session*" | select -Unique)

					for ($i = 0; $i -lt $Connected.Length; $i++) {
						$ConnectTime = ((($Connected[$i] -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
						$EndTime = ((($Disconnect[$i] -split ('\dZ',2))[0] -replace ("T"," ")).Split(".",2)[0]).split(" ",2)[1]
						# save results
						$calls += Calls $StartTime $ConnectTime $EndTime $CallId "Inbound" $CallType $Modality $ToFrom "" "" "" "" $MeetingId
					}
				}
			}
		}
	}
}
$calls = $calls | Sort-Object TimeStartUTC, Established; 
$calls