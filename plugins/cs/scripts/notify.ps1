# Windows 기본 알림. 추가 설치 없음. "CS Center" 이름·아이콘으로 표시하고, 닫거나 "티켓 열기"를 누를 때까지 화면에 남는다.
# 사용: powershell -NoProfile -File notify.ps1 "제목" ["본문"] ["클릭 시 열 URL"]
param([Parameter(Mandatory)][string]$Title, [string]$Body, [string]$Url)
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

# 앱 ID를 HKCU에 등록하면 알림 머리에 PowerShell 대신 CS Center 이름과 아이콘이 나온다(관리자 권한 불필요).
$appId = 'Emfocus.CsCenter'
$icon = Join-Path $PSScriptRoot 'cs-icon.png'
$key = "HKCU:\Software\Classes\AppUserModelId\$appId"
if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
Set-ItemProperty $key DisplayName 'CS Center'
Set-ItemProperty $key IconUri $icon

$e = { param($s) [Security.SecurityElement]::Escape($s) }
$launch = if ($Url) { " activationType=`"protocol`" launch=`"$(& $e $Url)`"" } else { "" }
# 큰 알림(reminder)은 버튼이 하나 이상 있어야 Windows가 적용한다. 주소가 없을 때도 [닫기]를 넣어 항상 같은 모양으로 뜨게 한다.
$open = if ($Url) { "<action content=`"열기`" activationType=`"protocol`" arguments=`"$(& $e $Url)`"/>" } else { "" }
$open += "<action content=`"닫기`" activationType=`"system`" arguments=`"dismiss`"/>"
$bodyXml = if ($Body) { "<text>$(& $e $Body)</text>" } else { "" }
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml(@"
<toast scenario="reminder"$launch>
  <visual><binding template="ToastGeneric">
    <text>$(& $e $Title)</text>$bodyXml
    <text placement="attribution">AI 자동 유지보수</text>
    <image placement="appLogoOverride" hint-crop="circle" src="file:///$(& $e $icon.Replace('\','/'))"/>
  </binding></visual>
  <actions>$open</actions>
</toast>
"@)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
