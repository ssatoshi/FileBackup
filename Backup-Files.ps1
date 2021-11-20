# --------------------------------------
# home�t�H���_�o�b�N�A�b�v
# �o�b�N�A�b�v��ɃV�X�e���N���t�H���_���쐬��ROBOCOPY
# ROBOCOPY�̃f�t�H���g�́A�T�C�Y���Ⴄ���̓��t���Ⴄ���̂������R�s�[����̂�
# ���ʓI�ɍ����ɂȂ�
# version:2111.1.0.0
# --------------------------------------

# -----------------------------------------------
# �ݒ�t�@�C���ǂݍ���
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
# �V�X�e�������̎擾
# -----------------------------------------------
function Get-NowTime
{
    Get-Date
    #[DateTime]("2018/1/1 12:34:56")    
}

# -----------------------------------------------
# ���O�t�@�C�����̐���
# -----------------------------------------------
function Create-Log
{

    Param (
        [string]$logRoot
    )

    # �o�b�N�A�b�v�Ώ۔N��(�V�X�e���N��)
    $targetYM = (Get-NowTime).ToString("yyyyMM")

    # ���O�t�@�C��
    $logfile = (Get-NowTime).ToString("yyyyMMdd_HHmmss") + ".log"

    #$scriptDir = $logFolder

    # ���O�t�H���_\
    $logFolder = (Join-Path $logRoot "logs" | Join-Path -ChildPath $targetYM)

    if(-not (Test-Path $logFolder))
    {
        New-Item $logFolder -type directory | Out-Null
    }

    $logfile = (Join-Path $logFolder $logfile)

    $logfile
}

# -----------------------------------------------
# �o�b�N�A�b�v�t�H���_�̍쐬
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
# �o�b�N�A�b�v�t�H���_�̍쐬
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
        # ���s�j�������j���Ȃ�ΑO��o�b�N�A�b�v���폜����
        # -7���Ɛ�T���͍폜(���T�������ێ�)�A
        # -14���Ɛ�X�T�����폜(��T�ƍ��T�ێ�)�ɂȂ�B
        # �{���͂Q�T�ԕ��������ق��������Ƃ�������HDD�̃T�C�Y���l���Č��߂�
        $lastWeek = ((Get-NowTime).AddDays(-7)).ToString("yyyyMMdd")
        
        $lastWeekBackup = (Join-Path $dstRoot $lastWeek)
        
        if(Test-Path $lastWeekBackup)
        {
            Write-Log -logfile $logfile -msg "�o�b�N�A�b�v�t�H���_���폜���܂� $lastWeekBackup"
            Remove-Item $lastWeekBackup -Force -Recurse
        }
    }
    #>

    $i = $i * -1

    $targetWeek = ((Get-NowTime).AddDays($i)).ToString("yyyyMMdd")
    $currentBackup = (Join-Path $dstRoot $targetWeek)

    if(-not (Test-Path $currentBackup))
    {
        Write-Log -logfile $logfile -msg "�o�b�N�A�b�v�t�H���_���쐬���܂� $currentBackup"
        New-Item $currentBackup -type directory | Out-Null
    }

    $currentBackup
}

# -----------------------------------------------
# �v���Z�X���s
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
# �o�b�N�A�b�v�ΏۊO���X�g�쐬
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
# ROBOCOPY���s
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

    Write-Log -logfile $logfile -msg "ROBOCOPY �J�n" 

    $proc = (Execute-Command -commandTitle "BACKUP" -commandPath $exec -commandArguments $prms)

    Write-Log -logfile $logfile -msg "ROBOCOPY �I�� �ȉ����O" 

    [System.IO.StreamReader] $reader = New-Object System.IO.StreamReader($tempLog,[System.Text.Encoding]::GetEncoding("Shift-JIS"))
    $content = $reader.ReadToEnd()
    $reader.Close()

    Write-Log -logfile $logfile -msg $content

    Remove-Item $tempLog -Force 
    #Write-Host $proc.stdout
}

# �ݒ�t�@�C���ǂݍ���
$conf = Load-Config

# ���O�t�@�C��
$logfile = (Create-Log -logRoot $conf.logRoot)

# �o�b�N�A�b�v��
$backupDir = (Create-BackupDir -dstRoot $conf.dstRoot -logfile $logfile)

# �o�b�N�A�b�v�ΏۊO�t�H���_���X�g�쐬
$ignoreDir = Create-IgnorePath -srcRoot $conf.backupSrc -ignorePath $conf.ignorePath

# ROBOCOPY ���s
Exec-RoboCopy -backupSrc $conf.backupSrc -backupDir $backupDir -logfile $logfile -ignoreDir $ignoreDir
#ROBOCOPY $conf.backupSrc $backupDir /E /R:10 /W:15 /FP /NP /LOG:$logfile

Write-Log -logfile $logfile -msg "�o�b�N�A�b�v����"