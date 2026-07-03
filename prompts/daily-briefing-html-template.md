# 宏观盘前简报 —— HTML 排版规范模板

> **用途**：每次生成日报 HTML 时，CSS 和 DOM 结构**原样照搬**，只替换内容数据。
> 此模板与 `daily-briefing.md` 配套使用——MD 定义内容结构，本文件定义 HTML 视觉规范。

---

## 一、全局基础参数

| 属性 | 值 | 说明 |
|------|-----|------|
| 字体 | `Microsoft YaHei`, `SimHei`, sans-serif | Windows 中文本地优先 |
| 全局字号 | **14px** | 标题、正文、表格统一（仅 footer 12px） |
| 最大宽度 | **960px** | 居中显示 |
| 行高 | **1.85** | 提升中文阅读舒适度 |
| 背景色 | `#fff` | 纯白底 |
| 正文色 | `#1a1a1a` | 近黑色，不刺眼 |

---

## 二、六色配色板

| 用途 | 色值 | CSS 变量/class | 说明 |
|------|------|---------------|------|
| 主色-标题/表头 | `#1e3a5f` | `th`, `h1`, `h2` color | 深蓝，沉稳专业 |
| 强调色-链接/引用 | `#2563eb` | `a`, `blockquote` border-left | 亮蓝，可点击感 |
| 🔴 利多/上涨/升级 | `#dc2626` | `.red`, `.bullish`, `.event.up`, `.etag.up` | 中国习惯：红涨 |
| 🟢 利空/下跌/缓和 | `#16a34a` | `.green`, `.bearish`, `.event.dn`, `.etag.dn` | 中国习惯：绿跌 |
| 🟠 中性/持续 | `#d97706` / `#92400e` | `.orange`, `.neutral`, `.event.on`, `.etag.on` | 橙色表示待观察 |
| ⬜ 边框/分隔 | `#e5e7eb` | `td` border, `hr`, `h2` border | 浅灰，不抢眼 |

### 背景色微调

| 场景 | 色值 | 用途 |
|------|------|------|
| 偶数行 | `#f8fafc` | 表格斑马纹 |
| 蓝色引用块 | `#f0f4ff` | 普通 blockquote 背景 |
| 橙色警告块 | `#fffbeb` | `.warn` blockquote 背景 |
| 红色事件卡 | `#fef2f2` | `.event.up` 升级事件 |
| 橙色事件卡 | `#fffbeb` | `.event.on` 持续事件 |
| 绿色事件卡 | `#f0fdf4` | `.event.dn` 缓和事件 |
| 默认事件卡 | `#f9fafb` | `.event` 默认背景 |
| 偏空 badge | `#dcfce7` | `.bearish` verdict 背景 |
| 偏多 badge | `#fee2e2` | `.bullish` verdict 背景 |
| 中性 badge | `#fef3c7` | `.neutral` verdict 背景 |

---

## 三、完整 CSS（不可修改）

```css
@page { margin-bottom: 24mm; @bottom-center { content: counter(page) "/" counter(pages); font-size: 12px; color: #9ca3af; font-family: "Microsoft YaHei","SimHei",sans-serif; } } @media print { body { margin: 0 0 20px 0; } }
body { font-family: "Microsoft YaHei", "SimHei", sans-serif; font-size: 14px; max-width: 960px; margin: 20px auto; padding: 0 24px; color: #1a1a1a; line-height: 1.85; background: #fff; }
h1 { font-size: 20px; border-bottom: 2px solid #2563eb; padding-bottom: 10px; color: #1e3a5f; }
h2 { font-size: 16px; margin-top: 32px; color: #1e3a5f; border-bottom: 1px solid #e5e7eb; padding-bottom: 6px; }
h3 { font-size: 14px; margin-top: 24px; color: #374151; }
table { width: 100%; border-collapse: collapse; margin: 10px 0 16px; font-size: 14px; }
th { background: #1e3a5f; color: #fff; padding: 7px 9px; text-align: left; font-weight: 600; font-size: 14px; }
td { padding: 6px 9px; border-bottom: 1px solid #e5e7eb; vertical-align: top; font-size: 14px; }
tr:nth-child(even) td { background: #f8fafc; }
.red { color: #dc2626; font-weight: bold; } .green { color: #16a34a; font-weight: bold; } .orange { color: #d97706; font-weight: bold; }
blockquote { border-left: 3px solid #2563eb; margin: 12px 0; padding: 8px 14px; background: #f0f4ff; color: #374151; font-size: 14px; }
.warn { border-left-color: #d97706; background: #fffbeb; }
ol { margin: 6px 0; padding-left: 22px; } ol li { margin: 4px 0 8px; font-size: 14px; }
ul { margin: 6px 0; padding-left: 20px; } ul li { margin: 5px 0; font-size: 14px; }
.verdict { display: inline-block; padding: 2px 12px; border-radius: 4px; font-weight: bold; font-size: 13px; margin: 0 4px; }
.bearish { background: #dcfce7; color: #16a34a; }
.neutral { background: #fef3c7; color: #92400e; }
.bullish { background: #fee2e2; color: #dc2626; }
.verdict-sep { margin: 0 6px; color: #9ca3af; }
.event { margin: 14px 0; padding: 10px 14px; background: #f9fafb; border-radius: 6px; border-left: 3px solid #d1d5db; }
.event.up { border-left-color: #dc2626; background: #fef2f2; }
.event.on  { border-left-color: #d97706; background: #fffbeb; }
.event.dn  { border-left-color: #16a34a; background: #f0fdf4; }
.etag { display: inline-block; padding: 1px 8px; border-radius: 3px; font-size: 12px; font-weight: bold; margin-right: 6px; color: #fff; }
.etag.up { background: #dc2626; } .etag.on { background: #d97706; } .etag.dn { background: #16a34a; }
.flabel { font-weight: bold; color: #374151; }
.retlink { text-align: right; font-size: 13px; margin-bottom: 8px; }
.retlink a { color: #2563eb; text-decoration: none; }
hr { border: none; border-top: 1px solid #e5e7eb; margin: 24px 0; }
.footer { font-size: 12px; color: #9ca3af; margin-top: 30px; text-align: center; } .footer .page-num::after { content: "— " counter(page) " —"; } .dsrc { font-size: 12px; color: #9ca3af; margin-top: 24px; }
```

---

## 四、各板块 HTML 骨架

### 4.0 页面外壳 + 目录

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>宏观盘前简报 —— YYYY年M月D日（周X）</title>
<style>
  /* 完整 CSS（见第三章，原样复制） */
</style>
</head>
<body>

<h1>宏观盘前简报 —— YYYY年M月D日（周X）</h1>

<h2 id="toc">目录</h2>
<ul>
  <li><a href="#s1">1. 今日关注</a></li>
  <li><a href="#s2">2. 隔夜外盘</a></li>
  <li><a href="#s3">3. 重大事件跟踪</a></li>
  <li><a href="#s4">4. 近期重要数据回顾</a></li>
  <li><a href="#s5">5. 品种宏观影响分析</a>
    <ul>
      <li><a href="#s51">5.1 建材板块（玻璃 FG · 纯碱 SA）</a></li>
      <li><a href="#s52">5.2 黑色系（螺纹钢 RB · 热卷 HC · 铁矿石 I · 焦炭 J · 焦煤 JM）</a></li>
      <li><a href="#s53">5.3 有色板块（铜 CU · 铝 AL · 锌 ZN）</a></li>
    </ul>
  </li>
  <li><a href="#s6">6. 今日宏观交易主题</a></li>
  <li><a href="#s7">7. 风险提示</a></li>
</ul>
<hr>
```

### 4.1 今日关注（五列表格）

```html
<h2 id="s1">1. 今日关注</h2>
<p class="retlink"><a href="#toc">【返回目录】</a></p>
<table>
<tr><th>时间</th><th>数据/事件</th><th>预期值</th><th>前值</th><th>影响品种</th></tr>
<tr><td>M/D (周X) HH:MM</td><td>数据名称</td><td>XX</td><td>XX</td><td>品种名</td></tr>
<!-- 按重要程度排序，最重要的排最前面 -->
</table>
<blockquote><strong>今日最重要的宏观事件</strong>：...一句话核心总结...</blockquote>
<hr>
```

### 4.2 隔夜外盘（四列表格 + 涨跌幅着色）

**涨跌幅着色规则**：上涨 → `class="red"`，下跌 → `class="green"`

```html
<h2 id="s2">2. 隔夜外盘</h2>
<p class="retlink"><a href="#toc">【返回目录】</a></p>
<table>
<tr><th>资产</th><th>收盘价</th><th>涨跌幅</th><th>关键驱动</th></tr>
<tr><td>道指</td><td>XX,XXX</td><td class="green">-X.X%</td><td>驱动简述</td></tr>
<tr><td>标普500</td><td>X,XXX</td><td class="red">+X.X%</td><td>驱动简述</td></tr>
<tr><td>纳指</td><td>XX,XXX</td><td class="red">+X.X%</td><td>驱动简述</td></tr>
<tr><td>美元指数</td><td>XX.XX</td><td class="green">-X.X%</td><td>驱动简述</td></tr>
<tr><td>10年美债</td><td>X.XXX%</td><td class="red">+Xbp</td><td>驱动简述</td></tr>
<tr><td>COMEX黄金</td><td>$X,XXX</td><td class="green">-X.X%</td><td>驱动简述</td></tr>
<tr><td>WTI原油</td><td>$XX.XX</td><td class="red">+X.X%</td><td>驱动简述</td></tr>
<tr><td>LME铜</td><td>$XX,XXX</td><td class="green">-X.X%</td><td>驱动简述</td></tr>
</table>
<blockquote><strong>整体风险偏好：risk-on / risk-off / 中性偏谨慎</strong>。...一句话总结...</blockquote>
<hr>
```

### 4.3 重大事件跟踪（卡片列表）

**事件状态 ↔ CSS class 对照表**：

| 状态标签 | `.event` class | `.etag` class | 左边框色 | 背景色 |
|---------|---------------|---------------|---------|--------|
| 升级 | `.event.up` | `.etag.up` | `#dc2626` 红 | `#fef2f2` |
| 持续 | `.event.on` | `.etag.on` | `#d97706` 橙 | `#fffbeb` |
| 缓和 | `.event.dn` | `.etag.dn` | `#16a34a` 绿 | `#f0fdf4` |

```html
<h2 id="s3">3. 重大事件跟踪</h2>
<p class="retlink"><a href="#toc">【返回目录】</a></p>
<blockquote>持续追踪影响品种的宏观事件，记录演进轨迹。每日更新最新进展。</blockquote>

<div class="event dn">
  <span class="etag dn">缓和</span> <strong>事件标题</strong>
  <br><br><span class="flabel">事件</span>：...事件背景概述，1-2句话说清来龙去脉...
  <br><br><span class="flabel">最新（M月D日）</span>：...具体时间 + 最新发生的事 + 影响...
  <br><br><span class="flabel">现状</span>：...当前状态判断 + 后续关注点...
  <br><br><span class="flabel">影响品种</span>：品种名 → 传导路径 → <strong>方向判断</strong>
</div>

<div class="event on">
  <span class="etag on">持续</span> <strong>事件标题</strong>
  <br><br><span class="flabel">事件</span>：...
  <br><br><span class="flabel">最新（M月D日）</span>：...
  <br><br><span class="flabel">现状</span>：...
  <br><br><span class="flabel">影响品种</span>：...
</div>

<div class="event up">
  <span class="etag up">升级</span> <strong>事件标题</strong>
  <br><br><span class="flabel">事件</span>：...
  <br><br><span class="flabel">最新（M月D日）</span>：...
  <br><br><span class="flabel">现状</span>：...
  <br><br><span class="flabel">影响品种</span>：...
</div>
<!-- 每期 3-6 个事件，按重要程度排序 -->
<hr>
```

### 4.4 近期重要数据回顾（七列表格 + 方向着色）

**颜色规则（中国习惯：红涨绿跌）**：

| 方向 | 方向列 class | 实际值列 class |
|------|-------------|---------------|
| 利多 | `<span class="red">利多</span>` | `class="green"` |
| 利空 | `<span class="green">利空</span>` | `class="red"` |
| 中性 | `<span class="orange">中性</span>` | 不着色 |

> ⚠️ 注意：利多=红色，但利多数据本身（超预期好）用绿色 class 标记——因为 HTML 中 `.red` 是红字、`.green` 是绿字。方向列的"利多/利空"是**对品种的影响方向**。

```html
<h2 id="s4">4. 近期重要数据回顾</h2>
<p class="retlink"><a href="#toc">【返回目录】</a></p>
<table>
<tr><th>方向</th><th>数据</th><th>公布</th><th>实际值</th><th>预期值</th><th>前值</th><th>解读</th></tr>
<tr>
  <td><span class="green">利空</span></td>
  <td>数据名称</td>
  <td>M/D</td>
  <td class="red"><strong>实际值</strong></td>
  <td>预期值</td>
  <td>前值</td>
  <td>一句话解读</td>
</tr>
<tr>
  <td><span class="red">利多</span></td>
  <td>数据名称</td>
  <td>M/D</td>
  <td class="green"><strong>实际值</strong></td>
  <td>预期值</td>
  <td>前值</td>
  <td>一句话解读</td>
</tr>
<tr>
  <td><span class="orange">中性</span></td>
  <td>数据名称</td>
  <td>M/D</td>
  <td>实际值</td>
  <td>预期值</td>
  <td>前值</td>
  <td>一句话解读</td>
</tr>
</table>
<blockquote><strong>整体判断</strong>：海外宏观面偏X...国内宏观面偏X...</blockquote>
<hr>
```

### 4.5 品种宏观影响分析（verdict badge + 编号列表）

**品种判断 badge 对照表**：

| 判断 | CSS class | 背景色 | 文字色 |
|------|-----------|--------|--------|
| 偏空 | `.verdict.bearish` | `#dcfce7` | `#16a34a` |
| 中性/中性偏空/中性偏多 | `.verdict.neutral` | `#fef3c7` | `#92400e` |
| 偏多 | `.verdict.bullish` | `#fee2e2` | `#dc2626` |

**判断格式固定**：`短期【偏X】· 中期【偏X】`

```html
<h2 id="s5">5. 品种宏观影响分析</h2>
<p class="retlink"><a href="#toc">【返回目录】</a></p>

<h3 id="s51">5.1 建材板块（玻璃 FG · 纯碱 SA）</h3>
<p><strong>宏观面判断</strong>：
  <span class="verdict neutral">短期 中性偏空</span>
  <span class="verdict-sep">·</span>
  <span class="verdict neutral">中期 中性偏多</span>
</p>
<ol>
  <li><strong>因素1标题</strong> —— 分析内容，每点 2-3 句话，说清传导逻辑</li>
  <li><strong>因素2标题</strong> —— 分析内容...</li>
  <!-- 通常 4-7 条 -->
</ol>
<p><strong>盘面</strong>：主力合约价格和状态描述。</p>
<blockquote class="warn"><strong>本周关注</strong>：本周最重要的变量和关注点。</blockquote>

<h3 id="s52">5.2 黑色系（螺纹钢 RB · 热卷 HC · 铁矿石 I · 焦炭 J · 焦煤 JM）</h3>
<p><strong>宏观面判断</strong>：
  <span class="verdict neutral">短期 中性偏空</span>
  <span class="verdict-sep">·</span>
  <span class="verdict neutral">中期 中性</span>
</p>
<ol>
  <li><strong>因素1</strong> —— ...</li>
  <!-- ... -->
</ol>
<p><strong>盘面</strong>：...</p>
<blockquote class="warn"><strong>本周关注</strong>：...</blockquote>

<h3 id="s53">5.3 有色板块（铜 CU · 铝 AL · 锌 ZN）</h3>
<p><strong>宏观面判断</strong>：
  <span class="verdict bearish">短期 偏空</span>
  <span class="verdict-sep">·</span>
  <span class="verdict neutral">中期 中性偏空</span>
</p>
<ol>
  <li><strong>因素1</strong> —— ...</li>
  <!-- ... -->
</ol>
<p><strong>盘面</strong>：...</p>
<blockquote class="warn"><strong>本周关注</strong>：...</blockquote>
<hr>
```

### 4.6 今日宏观交易主题

```html
<h2 id="s6">6. 今日宏观交易主题</h2>
<p class="retlink"><a href="#toc">【返回目录】</a></p>
<blockquote><strong>一句话核心主题，点出今日宏观面的核心矛盾或交易逻辑</strong></blockquote>
<p><strong>今日重点关注：</strong></p>
<ul>
  <li><strong>主题1标题</strong><br>关注原因和可能的影响路径，2-3句话</li>
  <li style="margin-top:10px;"><strong>主题2标题</strong><br>关注原因和可能的影响路径</li>
  <li style="margin-top:10px;"><strong>主题3标题</strong><br>关注原因和可能的影响路径</li>
</ul>
<hr>
```

### 4.7 风险提示

```html
<h2 id="s7">7. 风险提示</h2>
<p class="retlink"><a href="#toc">【返回目录】</a></p>
<ul>
  <li>...风险项1（含具体触发条件和影响方向）...</li>
  <li>...风险项2...</li>
  <!-- 通常 5-8 条 -->
</ul>
<hr>
```

### 4.8 数据来源 + 页脚

> ⚠️ **页脚规则**：页脚只放页码，不放任何文字（不含免责声明、数据来源、生成时间等）。数据来源单独放在正文末尾（风险提示之后）。

```html
<p class="dsrc">数据来源：新华社、东方财富、金十数据、新浪财经、ForexFactory、Investing.com、Mysteel、上海有色网、国家统计局</p>

<div class="footer">
  <span class="page-num"></span>
</div>

</body>
</html>
```

---

## 五、生成检查清单（每次输出 HTML 前逐条核对）

- [ ] ① 全局字号 14px，标题/正文/表格统一
- [ ] ② 每个 `<h2>` 下方有 `<p class="retlink"><a href="#toc">【返回目录】</a></p>`
- [ ] ③ 板块间用 `<hr>` 分隔（目录后、1-2-3-4-5-6-7 各板块之间、7 之后到 footer 之前）
- [ ] ④ 利空 = `.green` 绿字，利多 = `.red` 红字，中性 = `.orange` 橙字（中国习惯：红涨绿跌）
- [ ] ⑤ 事件卡片状态三色：升级 `.up`（红）、持续 `.on`（橙）、缓和 `.dn`（绿）
- [ ] ⑥ verdict badge 三色：偏空 `.bearish`（红底）、中性 `.neutral`（黄底）、偏多 `.bullish`（绿底）
- [ ] ⑦ 品种判断格式固定：`短期【偏X】· 中期【偏X】`
- [ ] ⑧ 表格表头深蓝底 `#1e3a5f` + 白字，偶数行 `#f8fafc` 背景
- [ ] ⑨ blockquote 蓝色左边框 + `#f0f4ff` 背景；警告类加 `.warn` class 变橙色
- [ ] ⑩ MD 和 HTML 内容完全对应——相同章节、相同数据、相同文字内容
- [ ] ⑪ 所有数据必须标注来源
- [ ] ⑫ 聚焦 10 个用户品种，不做全市场分析
- [ ] ⑬ 每个结论都有"对品种意味着什么"
- [ ] ⑭ 关键数据（非农/CPI/PMI/社融/房地产/美联储/LPR）交叉验证后再写入
- [ ] ⑮ 页脚只放页码（`.footer .page-num`），不写免责声明、数据来源或生成时间
- [ ] ⑯ 数据来源放在正文末尾（`.dsrc`），不放在页脚；不写"本简报由 AI 生成…"等免责声明

---

## 六、CSS class 速查表

```
┌─────────────────────────────────────────────────────────┐
│ 文字颜色类（标在 td 或 span 上）                          │
│   .red      = 红字 #dc2626  (利多 / 上涨)                │
│   .green    = 绿字 #16a34a  (利空 / 下跌)                │
│   .orange   = 橙字 #d97706  (中性)                       │
├─────────────────────────────────────────────────────────┤
│ 品种判断 badge（span.verdict）                            │
│   .bearish  = 绿底 #dcfce7 / 绿字 #16a34a  偏空          │
│   .neutral  = 黄底 #fef3c7 / 棕字 #92400e  中性          │
│   .bullish  = 红底 #fee2e2 / 红字 #dc2626  偏多          │
├─────────────────────────────────────────────────────────┤
│ 事件卡片（div.event）                                     │
│   .event.up = 红左边框 + 红背景   升级                    │
│   .event.on = 橙左边框 + 橙背景   持续                    │
│   .event.dn = 绿左边框 + 绿背景   缓和                    │
├─────────────────────────────────────────────────────────┤
│ 事件标签（span.etag）                                     │
│   .etag.up  = 红底白字  升级                              │
│   .etag.on  = 橙底白字  持续                              │
│   .etag.dn  = 绿底白字  缓和                              │
├─────────────────────────────────────────────────────────┤
│ 引用块变体                                               │
│   blockquote       = 蓝左边框 + 蓝底  默认                │
│   blockquote.warn  = 橙左边框 + 橙底  警告                │
├─────────────────────────────────────────────────────────┤
│ 其他                                                     │
│   .retlink  = 右对齐，返回目录链接                        │
│   .flabel   = 事件卡片中的字段标签（粗体）                 │
│   .verdict-sep = 短期/中期判断之间的分隔符                 │
│   .footer   = 居中灰色页脚（仅含页码），12px                          │
│   .dsrc     = 数据来源行，12px 灰色                                    │
└─────────────────────────────────────────────────────────┘
```
