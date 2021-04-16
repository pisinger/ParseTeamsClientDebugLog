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
     .\Get-Call-ID-and-Time-from-Teams-DebugLog.ps1 | ft
     .\Get-Call-ID-and-Time-from-Teams-DebugLog.ps1 -Path C:\temp
    $calls = .\Get-Call-ID-and-Time-from-Teams-DebugLog.ps1
    $calls | fl
    

    TimeStartUTC        Established TimeEnd  CallId                               Direction CallType Modality ToFrom         TerminatedReason CallControllerCode
    ------------        ----------- -------  ------                               --------- -------- -------- ------         ---------------- ------------------
    2021-03-26 11:36:25 11:36:35    11:36:43 50477aeb-a2fa-4f3c-b722-0a4399d9d328 Outbound  Skype    Audio                   1                0
    2021-03-26 11:36:05 11:36:09    11:36:19 6f892872-f737-4dd8-aaff-4b1f75cc2e6b Inbound   Skype    Audio    Jane Doe    	 1                0
    2021-03-26 11:17:17 11:17:48    11:17:57 000a9959-e91f-494a-b10c-914e968ae1ad Inbound   Teams    Video    Richard Parker
    2021-03-26 11:17:17 11:17:30    11:17:40 000a9959-e91f-494a-b10c-914e968ae1ad Inbound   Teams    Video    Richard Parker
    2021-03-26 11:17:17 11:17:19    11:18:01 000a9959-e91f-494a-b10c-914e968ae1ad Inbound   Teams    Audio    Richard Parker 1                0
    2021-03-26 10:37:24 10:37:36    10:37:54 00bf232b-46c6-4700-a9f4-45a8678cefe2 Outbound  Teams    Video    Kalle Svensson
    2021-03-26 10:37:24 10:37:26    10:38:26 00bf232b-46c6-4700-a9f4-45a8678cefe2 Inbound   Teams    Audio    Kalle Svensson 1                0
    2021-03-25 20:03:48 20:04:56    20:05:05 2ee5beed-8d5e-46e7-9821-d32fcba3c6ca Inbound   Teams    Sharing  Richard Parker
    2021-03-25 20:03:48 20:04:33    20:04:47 2ee5beed-8d5e-46e7-9821-d32fcba3c6ca Inbound   Teams    Sharing  Richard Parker
    2021-03-25 20:03:48 20:04:33    20:04:47 2ee5beed-8d5e-46e7-9821-d32fcba3c6ca Inbound   Teams    Video    Richard Parker
    2021-03-25 20:03:48 20:03:54    20:05:08 2ee5beed-8d5e-46e7-9821-d32fcba3c6ca Inbound   Teams    Audio    Richard Parker 1                0
    2021-03-25 18:54:32 18:55:22    18:55:39 eef4ca98-7601-42dd-973a-e1c4a3ed48ae Outbound  MeetNow  Sharing
    2021-03-25 18:54:32 18:54:44    18:55:03 eef4ca98-7601-42dd-973a-e1c4a3ed48ae Outbound  MeetNow  Sharing
    2021-03-25 18:54:32 18:54:36    18:55:48 eef4ca98-7601-42dd-973a-e1c4a3ed48ae Outbound  MeetNow  Audio                   1                0
    2021-03-25 14:31:04 14:31:06    14:31:12 1a7c0674-00c0-491b-b4a1-c31096bd500b Inbound   Skype4B  Audio    John Doe       1                0
    2021-03-25 13:44:38             13:44:46 a585785c-41bb-48d2-b2a1-e5a845a83611 Outbound  Teams    Audio                   12               487
    2021-03-25 12:40:39 12:40:41    12:40:55 3e91efee-378b-4ff8-989d-341e95339715 Outbound  Meeting  Audio                   1                0
    2021-03-25 07:42:21             07:42:33 96b6d394-377a-44eb-b4d7-e08bc7224427 Inbound   PSTN     Audio    +49123456789   missed
    2021-03-25 07:41:52 07:41:56    07:42:03 0367145b-8390-4757-82f1-0287e289a06c Inbound   PSTN     Audio    +49123456789   1                0
    2021-03-25 07:41:32 07:41:39    07:41:47 c6dde31f-4765-490f-9427-28d0048e6a34 Outbound  PSTN     Audio    +49123456789   1                0
#>

param(
    [ValidateScript({Test-Path $_})]
    [string]$Path = "$env:USERPROFILE\Downloads"
)

$excluded = "(sync|calling|cdl|cdlWorker|chatListData|experience_renderer|extensibility)\.txt"
$Files = Get-ChildItem $Path -Include *MSTeams*.txt* -Recurse | where Name -notmatch $excluded

$logs = @()

foreach ($File in $Files) {    
    $logs += Get-Content -Path $File.FullName
}

function Calls () {
    param ( 
        [string]$StartTime,[string]$ConnectTime,[string]$EndTime,
        $CallId,$Direction,$CallType,$Modality,$ToFrom,
        $TerminatedReason,$CallControllerCode,$MeetingId
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
        TerminatedReason = $TerminatedReason
        CallControllerCode = $CallControllerCode
        MeetingId = $MeetingId
    }
    return $object
}

$CallStart          = $logs | select-string '((\[_createCall\]) threadId\:)|\[initCall\[callId\=|threadId=19:meeting'
$CallConnectDisc    = $logs | select-string 'callingservice.+(\=connected|\=disconnected)'
$ModalityType       = $logs | select-string '_stopVideo|_startVideo|startedVideo|main-video|CallingScreenSharingMixin|SharingStarted|\[StartScreenSharing\]success|\[screenSharing\]\[control\]|\[StopScreenSharing\]success|ScreenSharingControl|SharingControl initiating new viewer session'
$ConvController     = $logs | select-string 'participants.+,\"4:+'
$CallEndReason 	    = $logs | select-string 'Finish start call scenarios'
$TeamsInterop 	    = $logs | select-string 'ExtendedCallStateMixin|InteropCallAlert'
$IncomingCalls      = $logs | select-string 'Received incoming call'
$IncomingCallerName = $logs | select-string 'toastCallerDisplayName'

$calls = @()
$CallIds = @(([RegEx]::Matches($CallStart, '(?i)callId\:.{36}').Value) -replace "callId:" | select -Unique)
IF ($IncomingCalls) {$CallIds += ([RegEx]::Matches($IncomingCalls, '(?i)\[callId\=.{36}').Value) -replace "\[callId=" | select -Unique}
$CallIds = $CallIds.Split('',[System.StringSplitOptions]::RemoveEmptyEntries)

FOREACH ($callId in $CallIds) { 	
    FOREACH ($line in ($CallStart | select-string $CallID | select -first 1)) {
        # init
        $MeetingId = ""
        $CallControllerCode = ""
        $Modality = "Audio"
        $TerminatedReason = ""
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
        IF ($line -like "*createCall*"){
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

        IF ($ConnectTime -eq $NULL -and $Direction -eq "inbound"){
            $TerminatedReason = "missed"
        }
        ELSEIF ($end){
            $TerminatedReason = (([RegEx]::Matches($end, 'terminatedReason\=.+?(?=])').Value) -split('=',2))[1]
            $CallControllerCode = (([RegEx]::Matches($end, 'callControllerCode\=.+?(?=])').Value) -split('=',2))[1]	
        }
        
        # AUDIO - check for Call Type	
        IF ($end -like "*create_meetup_from_link*") {$CallType = "Meeting"; $MeetingId = ((([RegEx]::Matches($line, '(?i)\:meeting_.+?(?=@)').Value)) -Replace (":meeting_"))}	
        ELSEIF ($end -like "*create_meetup*") 		{$CallType = "MeetNow"; $MeetingId = ((([RegEx]::Matches($line, '(?i)\:meeting_.+?(?=@)').Value)) -Replace (":meeting_"))}
        ELSEIF ($end -like "*meetup*")				{$CallType = "_Meet_"; 	$MeetingId = ((([RegEx]::Matches($line, '(?i)\:meeting_.+?(?=@)').Value)) -Replace (":meeting_"))}
        #ELSEIF (($end -like "*interop_sfc_call*" -or $end -like "*call_accept*") -and $Incoming -like "*live:*") {$CallType = "Skype";$ToFrom = $DisplayName}	
        ELSEIF ($end -like "*interop_sfc_call*") 	{$CallType = "Skype";$ToFrom = $DisplayName}
        ELSEIF ($Incoming -like "*live:*") 			{$CallType = "Skype";$ToFrom = $DisplayName}
        ELSEIF ($Incoming -like "*sfb*")            {$CallType = "Skype4B"; $ToFrom = $DisplayName}	
        ELSEIF (($end -like "*one_to_one_call*" -or $end -like "*call_accept*") -and $ToFrom -notlike "*+*") {$CallType = "Teams"; $ToFrom = $DisplayName }
        ELSEIF ($ToFrom -like "*orgid*") 			{$CallType = "Teams"; $ToFrom = $DisplayName;}
        ELSEIF (($end -like "*pstn*" -or $end -like "*call_accept*")) {$CallType = "PSTN";}
        ELSEIF ($ToFrom -like "*+*") 				{$CallType = "PSTN"}
        ELSE 										{$CallType = "undefined"}
        
        # save results
        $calls += Calls $StartTime $ConnectTime $EndTime $CallId $Direction $CallType $Modality $ToFrom $TerminatedReason $CallControllerCode $MeetingId
        
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
                        $calls += Calls $StartTime $ConnectTime $EndTime $CallId "Outbound" $CallType $Modality $ToFrom "" "" $MeetingId        
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
                        $calls += Calls $StartTime $ConnectTime $EndTime $CallId "Inbound" $CallType $Modality $ToFrom "" "" $MeetingId        
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
                        $calls += Calls $StartTime $ConnectTime $EndTime $CallId "Outbound" $CallType $Modality $ToFrom "" "" $MeetingId        
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
                        $calls += Calls $StartTime $ConnectTime $EndTime $CallId "Inbound" $CallType $Modality $ToFrom "" "" $MeetingId        
                    }
                }
            }
        }
    }
}
$calls = $calls | Sort-Object TimeStartUTC, Established -Descending; 
$calls