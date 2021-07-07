# ParseTeamsClientDebugLog

This script can be used to parse the Teams Client Debug Log in case you do need to know the Call ID for further troubleshooting. It might also be useful to see if you have everything you need when doing an repro for call related issues and providing logs to Microsoft Support. You can also use this to simply get the Meeting ID which then can be used within CQD - here you may want to have a look to https://docs.microsoft.com/en-us/microsoftteams/cqd-power-bi-query-templates.

To get Teams Debug Logs -> **Ctrl + Alt + Shift + 1**
https://docs.microsoft.com/en-us/microsoftteams/log-files

You can run it against multiple Teams Debug Log Files/Folders as the script will filter for Default Web Log file only to grab Call-ID and other information. So if you are dealing with multiple logs/repros just copy the logs to the same location and run the script together with the "Path" switch. By default, the script will search for available logs in "Downloads" folder.

## Examples

```
.\Get-Call-ID-from-Teams-DebugLog.ps1 | ft
.\Get-Call-ID-from-Teams-DebugLog.ps1 -Path C:\temp
$calls = .\Get-Call-ID-from-Teams-DebugLog.ps1
$calls | fl
```

```
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
```

In case no call start information are available anymore, simply run the following to get all Call IDs found in log.
```
.\Get-Call-ID-from-Teams-DebugLog.ps1 -OnlyCallIDs
```

You can also run with ClientInfo switch to get information back such as User Name, Client Version, Device, CPU.
```
.\Get-Call-ID-from-Teams-DebugLog.ps1 -ClientInfo

File            : C:\temp\MSTeams Diagnostics Log 7_6_2021__10_11_35_PM.txt
Name            : Richard Parker
Upn             : richard@contoso.com
SessionId       : 7269b132-f0f5-9f65-54c0-fc9d587f0fc9
TimeZoneUTC     : 2
Auth            : native-wam
Issuer          : https://sts.windows.net/
Region          : emea
Env             : pckgsvc-prod-c1-euno-01
Ring            : general
RingName        : Public
ClientType      : desktop
PlatformId      : 27
Version         : 1.4.00.16575
SlimcoreVersion : 2021.14.41
Device          : Surface Book 2
DeviceManu      : Microsoft Corporation
OSVersion       : 10.0.19042
Arch            : x64
Memory          : 17092849664
Cpu             : Intel(R) Core(TM) i7-8650U CPU @ 1.90GHz
CpuSpeed        : 2112
CpuCores        : 8
```

## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.
