# verify-briefing.ps1
# 宏观日报交付前校验器 —— 对应 prompts/format-baseline.md
#
# 用法：
#   & "F:\AI project\宏观分析\verify-briefing.ps1" -Date "2026-07-23"
#   & "F:\AI project\宏观分析\verify-briefing.ps1" -Md "D:\some\other.md"
#
# 退出码：0 = 全部通过（可能有 WARN）；1 = 存在 FAIL，不得交付。
#
# 注意：本文件必须保存为「UTF-8 带 BOM」，否则 PowerShell 5.1 会按 GBK 解析中文正则而失效。

param(
    [string]$Date = "",
    [string]$Md = "",
    [string]$Root = "F:\AI project\宏观分析",
    [switch]$AsJson,
    # 默认不调用 exit（避免在交互会话中把宿主 PowerShell 一起结束）；
    # 需要在 CI / 自动化里拿到退出码时加 -StrictExit
    [switch]$StrictExit
)

$ErrorActionPreference = "Stop"

# ============================================================
# 上限配置（唯一数值来源 = prompts/format-baseline.md）
# ============================================================
$LIM = @{
    MdKbFail        = 50      # MD 体积 > 50 KB 直接失败
    MdKbWarn        = 45      # 45–50 KB 警告
    BodyChars       = 14000   # 正文总字数
    CalRows         = 10      # 表一 行数
    CalEventCell    = 35      # 表一「数据/事件」栏
    CalImpactCell   = 30      # 表一「影响品种」栏
    RecentRows      = 18      # 表二 行数
    CellHard        = 120     # 任何表格单元格硬底线
    RecentActual    = 20      # 表二「实际值」栏
    RecentRead      = 60      # 表二「解读」栏
    EventMin        = 3       # 事件数下限
    EventMax        = 6       # 事件数上限
    EventTitle      = 70      # 事件标题行
    EventCard       = 1300    # 单个事件卡片
    EventSection    = 6500    # 事件章节合计
    SectorItemsMin  = 4       # 板块 4 关键因素条数
    SectorItemsMax  = 6
    SectorItemLen   = 450     # 板块 4 单条
    ThemeItemsMin   = 4       # 板块 5 条数
    ThemeItemsMax   = 5
    ThemeItemLen    = 300     # 板块 5 单条
    RiskItemsMin    = 6       # 板块 6 条数
    RiskItemsMax    = 8
    RiskItemLen     = 180     # 板块 6 单条
    DsrcLen         = 150     # 数据来源行
}

# 上表数值的标定依据 —— 黄金样本 briefings/2026-07-23/ 实测：
#   MD 34.2 KB / 正文 13,697 字 / 表一 7 行（最长格 18 字）/ 表二 16 行（最长格 40 字）
#   事件 5 个（最长标题 62 字 / 章节合计 4,329 字）/ 板块 4 各 4·5·6 条（最长 436 字）
#   板块 5 共 5 条（最长 285 字）/ 板块 6 共 8 条（最长 148 字）/ 数据来源行 124 字
# 阈值取「略高于基线」，基线必须全 PASS。

$results = New-Object System.Collections.ArrayList

function Add-Result {
    param([string]$Level, [string]$Item, [string]$Detail)
    if ($null -eq $Detail) { $Detail = "" }
    if ($Detail.Length -gt 170) { $Detail = $Detail.Substring(0, 170) + "…（略）" }
    [void]$results.Add([pscustomobject]@{ Level = $Level; Item = $Item; Detail = $Detail })
}

function Test-Limit {
    param(
        [string]$Item,
        [double]$Value,
        [double]$WarnAt,
        [double]$FailAt,
        [string]$Unit = ""
    )
    if ($Value -gt $FailAt) {
        Add-Result "FAIL" $Item ("{0}{1} > 上限 {2}{1}（FAIL 阈值 {3}）" -f $Value, $Unit, $WarnAt, $FailAt)
    } elseif ($Value -gt $WarnAt) {
        Add-Result "WARN" $Item ("{0}{1} > 上限 {2}{1}" -f $Value, $Unit, $WarnAt)
    } else {
        Add-Result "PASS" $Item ("{0}{1} ≤ {2}{1}" -f $Value, $Unit, $WarnAt)
    }
}

# 去掉 markdown 标记与空白后的有效字数
function Get-TextLen {
    param([string]$s)
    if ([string]::IsNullOrEmpty($s)) { return 0 }
    $t = $s -replace '\*\*', ''
    $t = $t -replace '<[^>]+>', ''
    $t = $t -replace '\s', ''
    return $t.Length
}

# ============================================================
# 定位文件
# ============================================================
if ($Md -ne "") {
    $mdPath = $Md
} elseif ($Date -ne "") {
    $mdPath = Join-Path (Join-Path $Root "briefings") (Join-Path $Date ("{0}-宏观日报.md" -f $Date))
} else {
    Write-Output "用法: verify-briefing.ps1 -Date YYYY-MM-DD"
    $global:LASTEXITCODE = 2
    return
}

$mdPath = $mdPath.Trim()
if (-not (Test-Path -LiteralPath $mdPath)) {
    Write-Output ("FAIL  文件  未找到: {0}" -f $mdPath)
    $global:LASTEXITCODE = 1
    return
}

$mdItem = Get-Item -LiteralPath $mdPath
$lines = @(Get-Content -LiteralPath $mdPath -Encoding UTF8)
$raw = [System.IO.File]::ReadAllText($mdPath, [System.Text.Encoding]::UTF8)

$tag = $mdItem.BaseName

# ============================================================
# 1. 全局体积
# ============================================================
$kb = [math]::Round($mdItem.Length / 1024, 1)
Test-Limit "① MD 体积" $kb $LIM.MdKbWarn $LIM.MdKbFail "KB"

$bodyChars = Get-TextLen ($lines -join "`n")
Test-Limit "① 正文总字数" $bodyChars $LIM.BodyChars $LIM.BodyChars ""

# ============================================================
# 2. 章节结构
# ============================================================
$h2 = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^##\s*(\d+)\.\s') {
        [void]$h2.Add([pscustomobject]@{ Num = [int]$Matches[1]; Line = $i })
    }
}
$h2nums = @($h2 | ForEach-Object { $_.Num })
if (($h2nums -join ',') -eq "1,2,3,4,5,6") {
    Add-Result "PASS" "② 一级章节" "1→2→3→4→5→6，共 6 个"
} else {
    Add-Result "FAIL" "② 一级章节" ("期望 1,2,3,4,5,6，实际 {0}" -f ($h2nums -join ','))
}

# ### 3.x 禁止
$badH3 = @()
$h3all = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^###\s*(\d+)\.(\d+)\s') {
        $a = [int]$Matches[1]; $b = [int]$Matches[2]
        [void]$h3all.Add(("{0}.{1}" -f $a, $b))
        if ($a -eq 3) { $badH3 += ("行 {0}: {1}" -f ($i + 1), $lines[$i].Trim()) }
    }
}
if ($badH3.Count -eq 0) {
    Add-Result "PASS" "② 事件章节结构" "无 ### 3.x 子标题，保持平铺列表"
} else {
    Add-Result "FAIL" "② 事件章节结构" ("出现 {0} 个 ### 3.x 子标题: {1}" -f $badH3.Count, ($badH3 -join ' | '))
}
$sect4 = @($h3all | Where-Object { $_ -like '4.*' })
if (($sect4 -join ',') -eq "4.1,4.2,4.3") {
    Add-Result "PASS" "② 二级子章节" "仅 4.1 / 4.2 / 4.3"
} else {
    Add-Result "FAIL" "② 二级子章节" ("期望 4.1,4.2,4.3，实际 {0}" -f ($sect4 -join ','))
}

function Get-SectionRange {
    param($Table, [int]$Num, [int]$Total)
    $start = -1
    foreach ($h in $Table) { if ($h.Num -eq $Num) { $start = $h.Line; break } }
    if ($start -lt 0) { return $null }
    $end = $Total
    foreach ($h in $Table) { if ($h.Line -gt $start) { $end = $h.Line; break } }
    return @($start, $end)
}

function Get-Cells {
    param([string]$row)
    $r = $row.Trim()
    if ($r.StartsWith('|')) { $r = $r.Substring(1) }
    if ($r.EndsWith('|')) { $r = $r.Substring(0, $r.Length - 1) }
    return @($r -split '\|' | ForEach-Object { $_.Trim() })
}

# ============================================================
# 3. 表一 今日宏观数据
# ============================================================
$calStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|' -and $lines[$i] -match '时间' -and $lines[$i] -match '数据/事件') { $calStart = $i; break }
}
if ($calStart -lt 0) {
    Add-Result "FAIL" "③ 表一 今日宏观数据" "未找到五列表格（表头须含「时间」「数据/事件」）"
} else {
    $rows = @()
    for ($i = $calStart + 2; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -notmatch '^\|') { break }
        $rows += $lines[$i]
    }
    Test-Limit "③ 表一行数" $rows.Count $LIM.CalRows $LIM.CalRows " 行"

    $maxEvent = 0; $maxImpact = 0; $maxCell = 0
    $evLine = 0; $imLine = 0
    $badRows = @()
    foreach ($r in $rows) {
        $cs = Get-Cells $r
        $n2 = 0
        if ($cs.Count -ge 5) {
            $n2 = Get-TextLen $cs[1]
            $n5 = Get-TextLen $cs[4]
            if ($n2 -gt $maxEvent) { $maxEvent = $n2 }
            if ($n5 -gt $maxImpact) { $maxImpact = $n5 }
        }
        foreach ($c in $cs) {
            $n = Get-TextLen $c
            if ($n -gt $maxCell) { $maxCell = $n }
        }
        if ($n2 -gt 60 -and $cs.Count -ge 2) { $badRows += ("数据/事件栏 {0} 字: {1}" -f $n2, $cs[1]) }
    }
    Test-Limit "③ 表一「数据/事件」栏" $maxEvent $LIM.CalEventCell 50 ""
    Test-Limit "③ 表一「影响品种」栏" $maxImpact $LIM.CalImpactCell 45 ""
    Test-Limit "③ 表一 最长单元格" $maxCell $LIM.CellHard ($LIM.CellHard * 2) ""
    foreach ($b in $badRows) { Add-Result "WARN" "③ 表一 判断语检出行" $b }
}

# ============================================================
# 4. 表二 近期宏观数据
# ============================================================
$recStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|' -and $lines[$i] -match '方向' -and $lines[$i] -match '实际值' -and $lines[$i] -match '解读') { $recStart = $i; break }
}
if ($recStart -lt 0) {
    Add-Result "FAIL" "④ 表二 近期宏观数据" "未找到七列表格（表头须含「方向」「实际值」「解读」）"
} else {
    $rows = @()
    for ($i = $recStart + 2; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -notmatch '^\|') { break }
        $rows += $lines[$i]
    }
    Test-Limit "④ 表二行数" $rows.Count $LIM.RecentRows $LIM.RecentRows " 行"

    $maxCell = 0; $maxCellLine = 0
    $maxActual = 0; $maxActualLine = 0
    $maxRead = 0; $maxReadLine = 0
    $overCell = @()
    $reviewRows = @()
    for ($k = 0; $k -lt $rows.Count; $k++) {
        $cs = Get-Cells $rows[$k]
        $ln = $recStart + 3 + $k
        foreach ($c in $cs) {
            $n = Get-TextLen $c
            if ($n -gt $maxCell) { $maxCell = $n; $maxCellLine = $ln }
            if ($n -gt $LIM.CellHard) { $overCell += ("行 {0}: {1} 字" -f $ln, $n) }
        }
        if ($cs.Count -ge 7) {
            $na = Get-TextLen $cs[3]
            $nr = Get-TextLen $cs[6]
            if ($na -gt $maxActual) { $maxActual = $na; $maxActualLine = $ln }
            if ($nr -gt $maxRead) { $maxRead = $nr; $maxReadLine = $ln }
        }
        if ($rows[$k] -match '回顾') { $reviewRows += ("行 {0}" -f $ln) }
    }
    Test-Limit "④ 表二「实际值」栏" $maxActual $LIM.RecentActual 40 ""
    Test-Limit "④ 表二「解读」栏" $maxRead $LIM.RecentRead $LIM.CellHard ""
    Test-Limit "④ 表二 最长单元格" $maxCell $LIM.CellHard ($LIM.CellHard * 2) ""

    if ($overCell.Count -gt 0) {
        Add-Result "FAIL" "④ 表二 超 120 字单元格" ("{0} 处: {1}" -f $overCell.Count, (($overCell | Select-Object -First 8) -join ' | '))
    } else {
        Add-Result "PASS" "④ 表二 超 120 字单元格" "0 处"
    }
    if ($reviewRows.Count -gt 0) {
        Add-Result "FAIL" "④ 表二 历史复述行" ("发现「回顾」类行: {0}" -f ($reviewRows -join ', '))
    } else {
        Add-Result "PASS" "④ 表二 历史复述行" "无"
    }
}

# ============================================================
# 5. 板块 3 事件跟踪
# ============================================================
$rng = Get-SectionRange $h2 3 $lines.Count
if ($null -eq $rng) {
    Add-Result "FAIL" "⑤ 事件章节" "未找到「## 3.」章节"
} else {
    $s3 = $lines[$rng[0]..($rng[1] - 1)]
    $idx = @()
    for ($i = 0; $i -lt $s3.Count; $i++) { if ($s3[$i] -match '^-\s*【') { $idx += $i } }

    $cnt = $idx.Count
    if ($cnt -lt $LIM.EventMin -or $cnt -gt $LIM.EventMax) {
        Add-Result "FAIL" "⑤ 事件数量" ("{0} 个（要求 {1}–{2} 个）" -f $cnt, $LIM.EventMin, $LIM.EventMax)
    } else {
        Add-Result "PASS" "⑤ 事件数量" ("{0} 个" -f $cnt)
    }

    $maxTitle = 0
    $cardOver = @()
    for ($k = 0; $k -lt $idx.Count; $k++) {
        $a = $idx[$k]
        $b = $s3.Count
        if ($k + 1 -lt $idx.Count) { $b = $idx[$k + 1] }
        $titleTxt = ($s3[$a] -replace '^-\s*【[^】]*】\s*', '')
        $tl = Get-TextLen $titleTxt
        if ($tl -gt $maxTitle) { $maxTitle = $tl }
        $cardLen = 0
        for ($j = $a; $j -lt $b; $j++) { $cardLen += Get-TextLen $s3[$j] }
        if ($cardLen -gt $LIM.EventCard) { $cardOver += ("事件 {0}（行 {1}）: {2} 字" -f ($k + 1), ($rng[0] + $a + 1), $cardLen) }
    }
    Test-Limit "⑤ 事件标题行" $maxTitle $LIM.EventTitle 80 ""

    if ($cardOver.Count -gt 0) {
        Add-Result "FAIL" "⑤ 单事件卡片长度" ("超出 1300 字的卡片: {0}" -f ($cardOver -join ' | '))
    } else {
        Add-Result "PASS" "⑤ 单事件卡片长度" "全部 ≤ 1300 字"
    }

    $secLen = 0
    foreach ($l in $s3) { $secLen += Get-TextLen $l }
    Test-Limit "⑤ 事件章节合计" $secLen $LIM.EventSection ($LIM.EventSection * 1.5) ""
}

# ============================================================
# 6. 板块 4 关键因素条数 / 单条长度
# ============================================================
$rng4 = Get-SectionRange $h2 4 $lines.Count
if ($null -eq $rng4) {
    Add-Result "FAIL" "⑥ 品种分析" "未找到「## 4.」章节"
} else {
    $s4 = $lines[$rng4[0]..($rng4[1] - 1)]
    $subIdx = @()
    for ($i = 0; $i -lt $s4.Count; $i++) { if ($s4[$i] -match '^###\s*4\.\d') { $subIdx += $i } }
    for ($k = 0; $k -lt $subIdx.Count; $k++) {
        $a = $subIdx[$k]
        $b = $s4.Count
        if ($k + 1 -lt $subIdx.Count) { $b = $subIdx[$k + 1] }
        $name = $s4[$a].Trim()
        $items = @()
        for ($j = $a; $j -lt $b; $j++) {
            if ($s4[$j] -match '^\d+\.\s') { $items += $s4[$j] }
        }
        $ic = $items.Count
        if ($ic -lt $LIM.SectorItemsMin -or $ic -gt $LIM.SectorItemsMax) {
            Add-Result "FAIL" ("⑥ {0} 关键因素条数" -f $name) ("{0} 条（要求 {1}–{2}）" -f $ic, $LIM.SectorItemsMin, $LIM.SectorItemsMax)
        } else {
            Add-Result "PASS" ("⑥ {0} 关键因素条数" -f $name) ("{0} 条" -f $ic)
        }
        $mx = 0; $mxJ = 0
        for ($j = 0; $j -lt $items.Count; $j++) {
            $n = Get-TextLen ($items[$j] -replace '^\d+\.\s*', '')
            if ($n -gt $mx) { $mx = $n; $mxJ = $j + 1 }
        }
        if ($mx -gt 500) {
            Add-Result "FAIL" ("⑥ {0} 单条长度" -f $name) ("第 {0} 条 {1} 字 > 500（上限 350）" -f $mxJ, $mx)
        } elseif ($mx -gt $LIM.SectorItemLen) {
            Add-Result "WARN" ("⑥ {0} 单条长度" -f $name) ("第 {0} 条 {1} 字 > 上限 {2}" -f $mxJ, $mx, $LIM.SectorItemLen)
        } else {
            Add-Result "PASS" ("⑥ {0} 单条长度" -f $name) ("最长 {0} 字 ≤ {1}" -f $mx, $LIM.SectorItemLen)
        }
    }
}

# ============================================================
# 7. 板块 5 / 6 条数与单条长度
# ============================================================
function Test-BulletSection {
    param($Table, [int]$Num, [int]$Total, [int]$Min, [int]$Max, [int]$ItemLen, [string]$Name)
    $r = Get-SectionRange $Table $Num $Total
    if ($null -eq $r) { Add-Result "FAIL" ("⑦ {0}" -f $Name) "章节未找到"; return }
    $sec = $lines[$r[0]..($r[1] - 1)]
    $items = @()
    foreach ($l in $sec) { if ($l -match '^-\s') { $items += $l } }
    $c = $items.Count
    if ($c -lt $Min -or $c -gt $Max) {
        Add-Result "FAIL" ("⑦ {0}条数" -f $Name) ("{0} 条（要求 {1}–{2}）" -f $c, $Min, $Max)
    } else {
        Add-Result "PASS" ("⑦ {0}条数" -f $Name) ("{0} 条" -f $c)
    }
    $mx = 0; $mxJ = 0
    for ($j = 0; $j -lt $items.Count; $j++) {
        $n = Get-TextLen ($items[$j] -replace '^-\s*', '')
        if ($n -gt $mx) { $mx = $n; $mxJ = $j + 1 }
    }
    if ($mx -gt ($ItemLen * 2)) {
        Add-Result "FAIL" ("⑦ {0}单条长度" -f $Name) ("第 {0} 条 {1} 字 > {2}（上限 {3}）" -f $mxJ, $mx, ($ItemLen * 2), $ItemLen)
    } elseif ($mx -gt $ItemLen) {
        Add-Result "WARN" ("⑦ {0}单条长度" -f $Name) ("第 {0} 条 {1} 字 > 上限 {2}" -f $mxJ, $mx, $ItemLen)
    } else {
        Add-Result "PASS" ("⑦ {0}单条长度" -f $Name) ("最长 {0} 字 ≤ {1}" -f $mx, $ItemLen)
    }
}

Test-BulletSection $h2 5 $lines.Count $LIM.ThemeItemsMin $LIM.ThemeItemsMax $LIM.ThemeItemLen "板块5 今日重点关注"
Test-BulletSection $h2 6 $lines.Count $LIM.RiskItemsMin $LIM.RiskItemsMax $LIM.RiskItemLen "板块6 宏观风险"

# ============================================================
# 8. 文本卫生
# ============================================================
$oddBoldNums = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $c = ([regex]::Matches($lines[$i], '\*\*')).Count
    if ($c % 2 -ne 0) { $oddBoldNums += ($i + 1) }
}
if ($oddBoldNums.Count -eq 0) {
    Add-Result "PASS" "⑧ 加粗标记配对" "全部成对"
} else {
    Add-Result "FAIL" "⑧ 加粗标记配对" ("{0} 行标记数为奇数（会在 HTML 留下裸 **），行号: {1}" -f $oddBoldNums.Count, (($oddBoldNums | Select-Object -First 20) -join ', '))
}

$emojiPat = '[\uD800-\uDBFF][\uDC00-\uDFFF]|\uFE0F|\u2705|\u274C|\u26A0|\u2B50'
$emojiHits = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $emojiPat) { $emojiHits += ("行 {0}" -f ($i + 1)) }
}
if ($emojiHits.Count -eq 0) {
    Add-Result "PASS" "⑧ emoji" "未发现"
} else {
    Add-Result "FAIL" "⑧ emoji" ("发现 emoji: {0}" -f (($emojiHits | Select-Object -First 8) -join ', '))
}

$disclaim = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '仅供参考|不构成投资建议|本简报由') { $disclaim += ("行 {0}" -f ($i + 1)) }
}
if ($disclaim.Count -eq 0) {
    Add-Result "PASS" "⑧ 免责声明" "未出现"
} else {
    Add-Result "WARN" "⑧ 免责声明" ("疑似出现免责声明: {0}" -f ($disclaim -join ', '))
}

$dsrcLine = @($lines | Where-Object { $_ -match '^\*数据来源' })
if ($dsrcLine.Count -eq 0) {
    Add-Result "WARN" "⑧ 数据来源行" "未找到「*数据来源：…*」行"
} else {
    $dl = Get-TextLen $dsrcLine[0]
    Test-Limit "⑧ 数据来源行" $dl $LIM.DsrcLen ($LIM.DsrcLen * 2) ""
}

# ============================================================
# 9. 配套文件存在性（仅在指定 -Date 时检查）
# ============================================================
if ($Date -ne "") {
    $dir = Split-Path -Parent $mdPath
    $html = Join-Path $dir ("{0}-宏观日报.html" -f $Date)
    $pdf = Join-Path $dir ("{0}-宏观日报.pdf" -f $Date)
    if (Test-Path -LiteralPath $html) { Add-Result "PASS" "⑨ HTML" "已生成" } else { Add-Result "WARN" "⑨ HTML" "尚未生成" }
    if (Test-Path -LiteralPath $pdf) {
        $pk = [math]::Round((Get-Item -LiteralPath $pdf).Length / 1024, 0)
        Add-Result "PASS" "⑨ PDF" ("{0} KB" -f $pk)
    } else {
        Add-Result "WARN" "⑨ PDF" "尚未生成"
    }
    $idx = Join-Path $Root "index.html"
    if (Test-Path -LiteralPath $idx) {
        $latest = ""
        $bd = Join-Path $Root "briefings"
        if (Test-Path -LiteralPath $bd) {
            $latest = (@(Get-ChildItem -LiteralPath $bd -Directory | Sort-Object Name | Select-Object -Last 1)).Name
        }
        $idxLen = (Get-Item -LiteralPath $idx).Length
        $htmlLen = 0
        if (Test-Path -LiteralPath $html) { $htmlLen = (Get-Item -LiteralPath $html).Length }

        if ($latest -ne "" -and $latest -ne $Date) {
            Add-Result "PASS" "⑨ index.html" ("本期为历史期（最新期为 {0}），index.html 无需同步" -f $latest)
        } elseif ($htmlLen -gt 0 -and $idxLen -eq $htmlLen) {
            Add-Result "PASS" "⑨ index.html" "已同步为本期（与简报 HTML 字节数一致）"
        } else {
            Add-Result "WARN" "⑨ index.html" ("index.html {0} 字节 与 本期 HTML {1} 字节 不一致，可能未同步" -f $idxLen, $htmlLen)
        }
    }
}

# ============================================================
# 输出
# ============================================================
if ($AsJson) {
    $results | ConvertTo-Json -Depth 4
} else {
    $failCount = @($results | Where-Object { $_.Level -eq 'FAIL' }).Count
    $warnCount = @($results | Where-Object { $_.Level -eq 'WARN' }).Count
    $passCount = @($results | Where-Object { $_.Level -eq 'PASS' }).Count

    Write-Output ("=========== 宏观日报校验：{0} ===========" -f $tag)
    Write-Output ("文件: {0}" -f $mdPath)
    Write-Output ""
    foreach ($r in $results) {
        Write-Output ("{0}  {1,-28} {2}" -f $r.Level, $r.Item, $r.Detail)
    }
    Write-Output ""
    Write-Output ("---- PASS {0} / WARN {1} / FAIL {2} ----" -f $passCount, $warnCount, $failCount)
    if ($failCount -gt 0) {
        Write-Output "结论: 不合格，禁止交付。请按 prompts/daily-briefing.md「第三遍 · 强制删减」修订后重跑。"
    } elseif ($warnCount -gt 0) {
        Write-Output "结论: 通过（存在警告项，建议收敛到上限以内）。"
    } else {
        Write-Output "结论: 全部通过。"
    }
}

if (@($results | Where-Object { $_.Level -eq 'FAIL' }).Count -gt 0) {
    $global:LASTEXITCODE = 1
} else {
    $global:LASTEXITCODE = 0
}
if ($StrictExit) { exit $global:LASTEXITCODE }
