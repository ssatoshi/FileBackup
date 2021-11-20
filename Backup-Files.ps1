# --------------------------------------
# homeフォルダバックアップ
# バックアップ先にシステム年月フォルダを作成しROBOCOPY
# ROBOCOPYのデフォルトは、サイズが違うもの日付が違うものだけをコピーするので
# 結果的に差分になる
# version:2111.1.0.0
# --------------------------------------

# -----------------------------------------------
# 設定ファイル読み込み
# -----------------------------------------------
function Load-Config()
{

  $here =  (Split-Path -Parent $MyInvocation.PSCommandPath.ToString())
  $confxml = Join-Path $here "config.xml"
  
  $xml = [xml](Get-Content -Encoding UTF8 $confxml)
  $config = @{}

  $xpath = "//setting/@*"
  $nav = $xml.CreateNavigator()
  
  $nav.Select($xpath) | % {
    if($_.NodeType -eq "Attribute"){
       $config[$_.Name] = $_.Value
    }
  }
  $config
}

# -----------------------------------------------
# システム日時の取得
# -----------------------------------------------
function Get-NowTime
{
    Get-Date
    #[DateTime]("2018/1/1 12:34:56")    
}

# -----------------------------------------------
# ログファイル名の生成
# -----------------------------------------------
function Create-Log
{

    Param (
        [string]$logRoot
    )

    # バックアップ対象年月(システム年月)
    $targetYM = (Get-NowTime).ToString("yyyyMM")

    # ログファイル
    $logfile = (Get-NowTime).ToString("yyyyMMdd_HHmmss") + ".log"

    #$scriptDir = $logFolder

    # ログフォルダ\
    $logFolder = (Join-Path $logRoot "logs" | Join-Path -ChildPath $targetYM)

    if(-not (Test-Path $logFolder))
    {
        New-Item $logFolder -type directory | Out-Null
    }

    $logfile = (Join-Path $logFolder $logfile)

    $logfile
}

# -----------------------------------------------
# バックアップフォルダの作成
# -----------------------------------------------
function Write-Log
{
    Param (
        [string]$logfile,
        [string]$msg
    )

    $dt = (Get-Date -Format "yyyy/MM/dd HH:mm:ss")
    "[$dt]$msg" | Out-File $logfile -Encoding default -Append

}

# -----------------------------------------------
# バックアップフォルダの作成
# -----------------------------------------------
function Create-BackupDir
{
    Param (
        [string]$dstRoot,
        [string]$logfile
    )

    <#
    $i = [int](Get-NowTime).DayOfWeek
    if($i -eq 0)
    {
        # 実行曜日が日曜日ならば前回バックアップを削除する
        # -7だと先週分は削除(今週分だけ保持)、
        # -14だと先々週分を削除(先週と今週保持)になる。
        # 本来は２週間分持ったほうがいいとおもうがHDDのサイズを考えて決める
        $lastWeek = ((Get-NowTime).AddDays(-7)).ToString("yyyyMMdd")
        
        $lastWeekBackup = (Join-Path $dstRoot $lastWeek)
        
        if(Test-Path $lastWeekBackup)
        {
            Write-Log -logfile $logfile -msg "バックアップフォルダを削除します $lastWeekBackup"
            Remove-Item $lastWeekBackup -Force -Recurse
        }
    }
    #>

    $i = $i * -1

    $targetWeek = ((Get-NowTime).AddDays($i)).ToString("yyyyMMdd")
    $currentBackup = (Join-Path $dstRoot $targetWeek)

    if(-not (Test-Path $currentBackup))
    {
        Write-Log -logfile $logfile -msg "バックアップフォルダを作成します $currentBackup"
        New-Item $currentBackup -type directory | Out-Null
    }

    $currentBackup
}

# -----------------------------------------------
# プロセス実行
# -----------------------------------------------
Function Execute-Command 
{
    Param (
        [string]$commandTitle, 
        [string]$commandPath, 
        [array]$commandArguments
    )
    Try 
    {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $commandPath
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = $commandArguments
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        [pscustomobject]@{
            commandTitle = $commandTitle
            stdout = $p.StandardOutput.ReadToEnd()
            stderr = $p.StandardError.ReadToEnd()
            ExitCode = $p.ExitCode  
        }
        $p.WaitForExit()
    }
    Catch {
        exit
    }
}

# -----------------------------------------------
# バックアップ対象外リスト作成
# -----------------------------------------------
function Create-IgnorePath
{
    Param(
        [string]$srcRoot,
        [string]$ignorePath
    )

    $returnValue = ""
    $ignorePath.Split(",") | % {
        $path = $_
        $returnValue += ("`"" + (Join-Path $srcRoot $path) + "`"")
        $returnValue += " "
    }

    return $returnValue.TrimEnd(" ")
}

# -----------------------------------------------
# ROBOCOPY実行
# -----------------------------------------------
function Exec-RoboCopy
{
    Param (
        [string]$backupSrc,
        [string]$backupDir,
        [string]$logfile,
        [string]$ignoreDir
    )
    $exec = "ROBOCOPY"

    $prms = @()
    
    $prms += $backupSrc
    #$prms += $conf.backupSrc
    $prms += $backupDir
    #$prms += $backupDir
    $prms += "/E" 
    $prms += "/R:10" 
    $prms += "/W:15" 
    $prms += "/FP" 
    $prms += "/NP"
    $prms += "/XX"
    $prms += "/XC"
    $prms += "/XN"
    $prms += "/XO"

    if(-not ([string]::IsNullOrEmpty($ignoreDir)))
    {
        $prms += ("/XD " + $ignoreDir)
    }

    $tempLog = New-TemporaryFile
    $prms += ("/LOG:" + $tempLog)

    Write-Log -logfile $logfile -msg "ROBOCOPY 開始" 

    $proc = (Execute-Command -commandTitle "BACKUP" -commandPath $exec -commandArguments $prms)

    Write-Log -logfile $logfile -msg "ROBOCOPY 終了 以下ログ" 

    [System.IO.StreamReader] $reader = New-Object System.IO.StreamReader($tempLog,[System.Text.Encoding]::GetEncoding("Shift-JIS"))
    $content = $reader.ReadToEnd()
    $reader.Close()

    Write-Log -logfile $logfile -msg $content

    Remove-Item $tempLog -Force 
    #Write-Host $proc.stdout
}

# 設定ファイル読み込み
$conf = Load-Config

# ログファイル
$logfile = (Create-Log -logRoot $conf.logRoot)

# バックアップ先
$backupDir = (Create-BackupDir -dstRoot $conf.dstRoot -logfile $logfile)

# バックアップ対象外フォルダリスト作成
$ignoreDir = Create-IgnorePath -srcRoot $conf.backupSrc -ignorePath $conf.ignorePath

# ROBOCOPY 実行
Exec-RoboCopy -backupSrc $conf.backupSrc -backupDir $backupDir -logfile $logfile -ignoreDir $ignoreDir
#ROBOCOPY $conf.backupSrc $backupDir /E /R:10 /W:15 /FP /NP /LOG:$logfile

Write-Log -logfile $logfile -msg "バックアップ完了"