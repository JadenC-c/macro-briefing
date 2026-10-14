# -*- coding: utf-8 -*-
"""
md2html.py —— 宏观日报 MD → HTML 转换器（带篇幅报警）

用途
    把 briefings/YYYY-MM-DD/YYYY-MM-DD-宏观日报.md 转成同目录下的 .html，
    内联 CSS 与 DOM 结构严格照 `prompts/daily-briefing-html-template.md`，
    保证 MD 与 HTML 内容逐字对应。

核心特性
    转换过程中**逐格统计字数**，所有超出 `prompts/format-baseline.md` 上限的
    单元格 / 条目 / 章节都会打印出来。这样篇幅膨胀在交付前就暴露，
    而不是等到 PDF 变成 50 页才发现。

用法
    python md2html.py -Date 2026-10-13
    python md2html.py -Date 2026-10-13 --root "F:\\AI project\\宏观分析"
    python md2html.py --md <输入.md> --out <输出.html>
    python md2html.py -Date 2026-10-13 --strict      # 有超限即以退出码 1 结束

退出码：0 = 无超限（可能有告警）；1 = 存在 FAIL 级超限（仅 --strict 时生效）
"""
import argparse
import io
import os
import re
import sys

# ------------------------------------------------------------------
# 上限配置（唯一数值来源 = prompts/format-baseline.md）
# ------------------------------------------------------------------
LIM = {
    'cell_hard':      120,   # 任何表格单元格
    'cal_rows':        10,   # 表一 行数
    'cal_event':       35,   # 表一「数据/事件」
    'cal_impact':      30,   # 表一「影响品种」
    'recent_rows':     18,   # 表二 行数
    'recent_data':     25,   # 表二「数据」
    'recent_actual':   20,   # 表二「实际值」
    'recent_expect':   12,   # 表二「预期值」「前值」
    'recent_read':     60,   # 表二「解读」
    'event_title':     70,   # 事件标题行
    'event_card':    1300,   # 单个事件卡片
    'event_section': 6500,   # 事件章节合计
    'sector_item':    450,   # 板块 4 单条
}

CSS = r"""@page { margin-bottom: 24mm; @bottom-center { content: counter(page) "/" counter(pages); font-size: 12px; color: #9ca3af; font-family: "Microsoft YaHei","SimHei",sans-serif; } } @media print { body { margin: 0 0 20px 0; } }
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
.footer { font-size: 12px; color: #9ca3af; margin-top: 30px; text-align: center; } .dsrc { font-size: 12px; color: #9ca3af; margin-top: 24px; }"""

# 事件标签 → event/etag class
TAG_CLASS = {
    '升级': 'up', '恶化': 'up', '转折': 'up',
    '持续': 'on', '新增': 'on',
    '缓和': 'dn', '消退': 'dn',
}

violations = []   # (level, item, lineno, detail)


def v_add(level, item, lineno, detail):
    violations.append((level, item, lineno, detail))


def v_summary():
    """按 (级别, 项目) 归组，避免同类超限刷屏。"""
    groups = {}
    order = []
    for lv, item, ln, detail in violations:
        key = (lv, item)
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append((ln, detail))
    order.sort(key=lambda k: (0 if k[0] == 'FAIL' else 1, k[1]))
    out = []
    for key in order:
        lv, item = key
        arr = groups[key]
        if len(arr) == 1:
            out.append('%s  %-30s %s' % (lv, item, arr[0][1]))
        else:
            lns = sorted(set(x[0] for x in arr if x[0]))
            if lns:
                sample = ', '.join(str(x) for x in lns[:14])
                more = ' …' if len(lns) > 14 else ''
                loc = '行 %s%s' % (sample, more)
            else:
                loc = ''
            worst = max(arr, key=lambda x: len(x[1]))[1]
            out.append('%s  %-30s %d 处  %s   最严重: %s' % (lv, item, len(arr), loc, worst))
    return out


def tlen(t):
    """有效字数：去掉 markdown 粗体标记、HTML 标签与所有空白。"""
    if not t:
        return 0
    t = t.replace('**', '')
    t = re.sub(r'<[^>]+>', '', t)
    t = re.sub(r'\s', '', t)
    return len(t)


def check_len(level, item, line, value, limit):
    if value > limit:
        v_add(level, item, line, '%d 字 > 上限 %d' % (value, limit))
        return True
    return False


def normalize_bold(t):
    """标记数为奇数时去掉一个游离的 '**'，避免 HTML 留下裸标记。"""
    if t.count('**') % 2 == 1:
        parts = t.split('**')
        if parts[-1].strip() == '':
            k = t.rfind('**')
            t = t[:k] + t[k + 2:]
        else:
            k = t.find('**')
            t = t[:k] + t[k + 2:]
    return t


def inline(t):
    t = normalize_bold(t)
    t = t.replace('<u>', '\x01u\x02').replace('</u>', '\x01/u\x02')
    t = t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    t = t.replace('\x01u\x02', '<u>').replace('\x01/u\x02', '</u>')
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    return t


def map_anchor(a):
    m = re.match(r'^(\d+)-', a)
    if m:
        return 's' + m.group(1)
    return a


def vcls(v):
    if '偏空' in v or '看空' in v:
        return 'bearish'
    if '偏多' in v or '看多' in v:
        return 'bullish'
    return 'neutral'


def color_class(c):
    if '利空' in c or '偏空' in c:
        return 'green'
    if '利多' in c or '偏多' in c:
        return 'red'
    if '中性' in c:
        return 'orange'
    return ''


def convert(src, dst):
    with io.open(src, 'r', encoding='utf-8') as f:
        raw = f.read()
    lines = raw.replace('\r\n', '\n').split('\n')
    n = len(lines)

    title = ''
    out = []
    i = 0
    section3_len = 0
    in_s3 = False
    event_count = 0
    odd_bold_lines = []

    while i < n:
        line = lines[i]
        s = line.rstrip()
        st = s.strip()
        lineno = i + 1

        if st == '':
            i += 1
            continue

        # ---- h1 ----
        if s.startswith('# ') and not s.startswith('## '):
            title = s[2:].strip()
            out.append('<h1>%s</h1>' % inline(title))
            i += 1
            continue

        # ---- TOC ----
        if s.startswith('## ') and '目录' in s and len(st) <= 6:
            out.append('<h2 id="toc">目录</h2>')
            i += 1
            items = []
            while i < n:
                l = lines[i]
                ls = l.strip()
                if ls == '':
                    i += 1
                    continue
                if not ls.startswith('- ['):
                    break
                indent = len(l) - len(l.lstrip(' '))
                m = re.match(r'^-\s*\[(.+?)\]\(#(.+?)\)\s*$', ls)
                if m:
                    items.append((0 if indent == 0 else 1, m.group(1), map_anchor(m.group(2))))
                i += 1
            toc = ['<ul>']
            j = 0
            while j < len(items):
                lvl, text, anc = items[j]
                if lvl == 0:
                    has_kids = (j + 1 < len(items) and items[j + 1][0] > 0)
                    if has_kids:
                        toc.append('  <li><a href="#%s">%s</a>' % (anc, text))
                        toc.append('    <ul>')
                        k = j + 1
                        while k < len(items) and items[k][0] > 0:
                            toc.append('      <li><a href="#%s">%s</a></li>' % (items[k][2], items[k][1]))
                            k += 1
                        toc.append('    </ul>')
                        toc.append('  </li>')
                        j = k
                    else:
                        toc.append('  <li><a href="#%s">%s</a></li>' % (anc, text))
                        j += 1
                else:
                    toc.append('  <li><a href="#%s">%s</a></li>' % (anc, text))
                    j += 1
            toc.append('</ul>')
            out.append('\n'.join(toc))
            continue

        # ---- h2 ----
        m = re.match(r'^## (\d+)\. (.+)$', s)
        if m:
            num = m.group(1)
            in_s3 = (num == '3')
            out.append('<h2 id="s%s">%s. %s</h2>' % (num, num, inline(m.group(2))))
            out.append('<p class="retlink"><a href="#toc">【返回目录】</a></p>')
            i += 1
            while i < n and lines[i].strip() == '':
                i += 1
            if i < n and lines[i].strip().startswith('[【返回目录】]'):
                i += 1
            continue

        # ---- h3 ----
        m = re.match(r'^### (\d+)\.(\d+) (.+)$', s)
        if m:
            if m.group(1) == '3':
                v_add('FAIL', '事件章节结构', lineno,
                      '出现 ### 3.x 子标题，应改为平铺列表')
            out.append('<h3 id="s%s%s">%s.%s %s</h3>' % (
                m.group(1), m.group(2), m.group(1), m.group(2), inline(m.group(3))))
            i += 1
            continue

        # ---- hr ----
        if st == '---':
            out.append('<hr>')
            i += 1
            continue

        # ---- table ----
        if st.startswith('|'):
            rows = []
            while i < n and lines[i].strip().startswith('|'):
                rows.append((i + 1, lines[i].strip()))
                i += 1

            def cells(r):
                r = r.strip()
                if r.startswith('|'):
                    r = r[1:]
                if r.endswith('|'):
                    r = r[:-1]
                return [c.strip() for c in r.split('|')]

            header = cells(rows[0][1])
            body = rows[2:] if len(rows) > 2 else []
            is_dir_tbl = (len(header) > 0 and header[0] == '方向')
            is_cal_tbl = (len(header) > 0 and header[0] == '时间')

            if is_cal_tbl and len(body) > LIM['cal_rows']:
                v_add('FAIL', '表一 行数', rows[0][0],
                      '%d 行 > 上限 %d 行' % (len(body), LIM['cal_rows']))
            if is_dir_tbl and len(body) > LIM['recent_rows']:
                v_add('FAIL', '表二 行数', rows[0][0],
                      '%d 行 > 上限 %d 行' % (len(body), LIM['recent_rows']))

            col_names = {
                0: '方向', 1: '数据', 2: '公布',
                3: '实际值', 4: '预期值', 5: '前值', 6: '解读',
            }
            t = ['<table>']
            t.append('<tr>' + ''.join('<th>%s</th>' % inline(h) for h in header) + '</tr>')
            for (rl, r) in body:
                cs = cells(r)
                tds = []
                for k, c in enumerate(cs):
                    cl = tlen(c)
                    if cl > LIM['cell_hard']:
                        v_add('FAIL', '表格单元格超 %d 字' % LIM['cell_hard'], rl,
                              '第 %d 列 %d 字' % (k + 1, cl))
                    if is_cal_tbl:
                        if k == 1:
                            check_len('WARN', '表一「数据/事件」栏', rl, cl, LIM['cal_event'])
                        elif k == 4:
                            check_len('WARN', '表一「影响品种」栏', rl, cl, LIM['cal_impact'])
                    if is_dir_tbl:
                        if k == 1:
                            check_len('WARN', '表二「数据」栏', rl, cl, LIM['recent_data'])
                        elif k == 3:
                            check_len('WARN', '表二「实际值」栏', rl, cl, LIM['recent_actual'])
                        elif k in (4, 5):
                            check_len('WARN', '表二「预期值/前值」栏', rl, cl, LIM['recent_expect'])
                        elif k == 6:
                            check_len('WARN', '表二「解读」栏', rl, cl, LIM['recent_read'])

                    if is_dir_tbl and k == 0:
                        ccl = color_class(c)
                        if ccl:
                            tds.append('<td class="%s">%s</td>' % (ccl, inline(c)))
                        else:
                            tds.append('<td>%s</td>' % inline(c))
                    else:
                        tds.append('<td>%s</td>' % inline(c))
                t.append('<tr>' + ''.join(tds) + '</tr>')

                if is_dir_tbl and '回顾' in r:
                    v_add('FAIL', '表二 历史复述行', rl, '出现「回顾」类行，应删除')
            t.append('</table>')
            blk = '\n'.join(t)
            out.append(blk)
            if in_s3:
                section3_len += tlen(blk)
            continue

        # ---- blockquote ----
        if st.startswith('>'):
            paras = []
            cur = []
            while i < n and lines[i].lstrip().startswith('>'):
                txt = lines[i].lstrip()[1:]
                if txt.startswith(' '):
                    txt = txt[1:]
                txt = txt.strip()
                if txt == '':
                    if cur:
                        paras.append(' '.join(cur))
                        cur = []
                else:
                    cur.append(txt)
                i += 1
            if cur:
                paras.append(' '.join(cur))
            if not paras:
                continue
            cls = ' class="warn"' if paras[0].startswith('**本周关注**') else ''
            if len(paras) == 1:
                out.append('<blockquote%s>%s</blockquote>' % (cls, inline(paras[0])))
            else:
                b = ['<blockquote%s>' % cls]
                for p in paras:
                    b.append('<p>%s</p>' % inline(p))
                b.append('</blockquote>')
                out.append('\n'.join(b))
            continue

        # ---- event card ----
        m = re.match(r'^- 【(.+?)】\s*(.*)$', st)
        if m:
            label = m.group(1).strip()
            summary = m.group(2)
            cls = TAG_CLASS.get(label, 'on')
            event_count += 1
            check_len('WARN', '事件标题行', lineno, tlen(summary), LIM['event_title'])
            card_len = tlen(st)
            i += 1
            fields = []
            while i < n:
                l = lines[i]
                ls = l.strip()
                if ls == '':
                    i += 1
                    continue
                if ls == '>':
                    i += 1
                    continue
                if ls.startswith('└'):
                    content = re.sub(r'^└\s*', '', ls)
                    card_len += tlen(content)
                    f2 = re.match(r'^\*\*(.+?)\*\*[：:]\s*(.*)$', content)
                    if f2:
                        fields.append((f2.group(1), f2.group(2)))
                    else:
                        fields.append(('', content))
                    i += 1
                    continue
                break
            if card_len > LIM['event_card']:
                v_add('FAIL', '单事件卡片长度', lineno,
                      '「%s」%d 字 > 上限 %d' % (label, card_len, LIM['event_card']))
            ev = ['<div class="event %s">' % cls]
            sm = inline(summary)
            if not sm.startswith('<strong>'):
                sm = '<strong>%s</strong>' % sm
            ev.append('<p><span class="etag %s">%s</span>%s</p>' % (cls, label, sm))
            for fl, ft in fields:
                if fl:
                    ev.append('<p><span class="flabel">%s</span>：%s</p>' % (fl, inline(ft)))
                else:
                    ev.append('<p>%s</p>' % inline(ft))
            ev.append('</div>')
            blk = '\n'.join(ev)
            out.append(blk)
            section3_len += card_len
            continue

        # ---- ordered list ----
        if re.match(r'^\d+\.\s', st):
            ol = ['<ol>']
            while i < n:
                l = lines[i]
                ls = l.strip()
                if ls == '':
                    j = i
                    while j < n and lines[j].strip() == '':
                        j += 1
                    if j < n and re.match(r'^\d+\.\s', lines[j].strip()):
                        i = j
                        continue
                    break
                if re.match(r'^\d+\.\s', ls):
                    check_len('WARN', '板块4 关键因素单条', i + 1,
                              tlen(re.sub(r'^\d+\.\s*', '', ls)), LIM['sector_item'])
                    ol.append('<li>%s</li>' % inline(re.sub(r'^\d+\.\s*', '', ls)))
                    i += 1
                else:
                    break
            ol.append('</ol>')
            out.append('\n'.join(ol))
            continue

        # ---- unordered list ----
        if st.startswith('- ') and not re.match(r'^- 【', st):
            ul = ['<ul>']
            while i < n:
                l = lines[i]
                ls = l.strip()
                if ls == '':
                    j = i
                    while j < n and lines[j].strip() == '':
                        j += 1
                    if j < n and lines[j].strip().startswith('- ') and not re.match(r'^- 【', lines[j].strip()):
                        i = j
                        continue
                    break
                if ls.startswith('- ') and not re.match(r'^- 【', ls):
                    ul.append('<li>%s</li>' % inline(ls[2:].strip()))
                    i += 1
                else:
                    break
            ul.append('</ul>')
            out.append('\n'.join(ul))
            continue

        # ---- verdict line ----
        m = re.match(r'^\*\*宏观面判断\*\*[：:]\s*短期【(.+?)】\s*·\s*中期【(.+?)】\s*$', st)
        if m:
            out.append('<p><strong>宏观面判断</strong>：短期<span class="verdict %s">%s</span>'
                       '<span class="verdict-sep">·</span>中期<span class="verdict %s">%s</span></p>'
                       % (vcls(m.group(1)), m.group(1), vcls(m.group(2)), m.group(2)))
            i += 1
            continue

        # ---- data source ----
        if st.startswith('*数据来源'):
            t = st
            if t.startswith('*'):
                t = t[1:]
            if t.endswith('*'):
                t = t[:-1]
            out.append('<p class="dsrc"><em>%s</em></p>' % inline(t))
            i += 1
            continue

        # ---- plain paragraph ----
        if st.count('**') % 2 == 1:
            odd_bold_lines.append(lineno)
        out.append('<p>%s</p>' % inline(st))
        i += 1

    # ---- md 级校验 ----
    if event_count < 3 or event_count > 6:
        v_add('FAIL', '事件数量', 0, '%d 个（要求 3–6 个）' % event_count)
    if section3_len > LIM['event_section']:
        v_add('FAIL', '事件章节合计', 0, '%d 字 > 上限 %d' % (section3_len, LIM['event_section']))
    for lno in odd_bold_lines[:20]:
        v_add('FAIL', '加粗标记配对', lno, '该行 ** 标记数为奇数（HTML 已自动归一，但 MD 源应先修正）')

    emoji_pat = re.compile(
        u'[\U0001F300-\U0001FAFF\u2705\u274C\u26A0\u2B50\uFE0F]')
    for i2, l in enumerate(lines):
        if emoji_pat.search(l):
            v_add('FAIL', 'emoji', i2 + 1, '出现 emoji 字符')
        if '仅供参考' in l or '不构成投资建议' in l:
            v_add('WARN', '免责声明', i2 + 1, '出现免责声明字样')

    # ---- 组装 ----
    BLOCK_PREFIX = ('<h2', '<h3', '<hr', '<table', '<blockquote', '<div', '<ul', '<ol')
    body_parts = []
    for blk in out:
        if body_parts and blk.startswith(BLOCK_PREFIX):
            body_parts.append('')
        body_parts.append(blk)
    body = '\n'.join(body_parts)

    html = ('<!DOCTYPE html>\n'
            '<html lang="zh-CN">\n'
            '<head>\n'
            '<meta charset="UTF-8">\n'
            '<title>%s</title>\n'
            '<style>\n%s\n</style>\n'
            '</head>\n'
            '<body>\n\n%s\n\n</body>\n</html>\n' % (title, CSS, body))

    with io.open(dst, 'w', encoding='utf-8', newline='\n') as f:
        f.write(html)

    return {
        'title': title,
        'md_lines': n,
        'html_bytes': len(html.encode('utf-8')),
        'events': event_count,
        'section3_chars': section3_len,
        'leftover_markers': html.count('**'),
        'strong_open': html.count('<strong>'),
        'strong_close': html.count('</strong>'),
        'h2': sum(1 for b in out if b.startswith('<h2')),
        'h3': sum(1 for b in out if b.startswith('<h3')),
        'table': sum(1 for b in out if b.startswith('<table')),
        'event_divs': sum(1 for b in out if b.startswith('<div')),
    }


def main():
    ap = argparse.ArgumentParser(description='宏观日报 MD → HTML 转换器（带篇幅报警）')
    ap.add_argument('-Date', dest='date', default='', help='简报日期，如 2026-10-13')
    ap.add_argument('--md', dest='md', default='', help='输入 MD 路径')
    ap.add_argument('--out', dest='out', default='', help='输出 HTML 路径')
    ap.add_argument('--root', dest='root', default=r'F:\AI project\宏观分析',
                    help='项目根目录')
    ap.add_argument('--strict', dest='strict', action='store_true',
                    help='存在 FAIL 级超限时以退出码 1 结束')
    args = ap.parse_args()

    # Windows 控制台默认 GBK，中文标签会乱码；尽量切到 UTF-8
    for stream in ('stdout', 'stderr'):
        s = getattr(sys, stream, None)
        try:
            if s is not None and hasattr(s, 'reconfigure'):
                s.reconfigure(encoding='utf-8')
        except Exception:
            pass

    if args.md:
        src = args.md
        dst = args.out or (os.path.splitext(src)[0] + '.html')
    elif args.date:
        src = os.path.join(args.root, 'briefings', args.date,
                           '%s-宏观日报.md' % args.date)
        dst = os.path.join(args.root, 'briefings', args.date,
                           '%s-宏观日报.html' % args.date)
    else:
        ap.print_help()
        return 2

    if not os.path.isfile(src):
        sys.stdout.write('FAIL  未找到 MD: %s\n' % src)
        return 1

    stats = convert(src, dst)

    sys.stdout.write('===== md2html: %s =====\n' % os.path.basename(src))
    for k in sorted(stats):
        sys.stdout.write('  %-18s %s\n' % (k, stats[k]))
    sys.stdout.write('  -> %s\n' % dst)

    fails = [v for v in violations if v[0] == 'FAIL']
    warns = [v for v in violations if v[0] == 'WARN']

    if violations:
        sys.stdout.write('\n----- 篇幅超限项（上限见 prompts/format-baseline.md）-----\n')
        for ln in v_summary():
            sys.stdout.write(ln + '\n')
    sys.stdout.write('\n---- 超限统计: FAIL %d / WARN %d ----\n' % (len(fails), len(warns)))
    if fails:
        sys.stdout.write('存在超限项，应先按「第三遍 · 强制删减」收敛后再交付。\n')
    else:
        sys.stdout.write('无 FAIL 级超限。\n')

    if args.strict and fails:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
