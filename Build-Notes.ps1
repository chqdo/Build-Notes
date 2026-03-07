# ============================================================
#  Build-Notes.ps1
# ============================================================
#  USAGE
#  .\Build-Notes.ps1
#  .\Build-Notes.ps1 -NotesDir "C:\path\MARKDOWN" -OutputFile "C:\path\notes.html"
#
#  The script interactively asks:
#    1. Document title        (default: NOTES)
#    2. Accent color theme    (blue/red/amber/green/purple/mono)
#    3. Default mode          (dark/light)
#
#  STRUCTURE
#  NOTES\
#    MARKDOWN\
#      01_windows.md   <- numeric prefix = manual priority order
#      02_linux.md
#      aircrack.md     <- no prefix = sorted alphabetically (auto)
#    Build-Notes.ps1
#    notes.html        <- output
# ============================================================

param(
    [string]$NotesDir   = "$PSScriptRoot\MARKDOWN",
    [string]$OutputFile = "",          # auto-generated from title if empty
    [string]$Title      = "",          # prompted interactively if empty
    [string]$ThemeColor = "",          # blue|red|amber|green|purple|mono
    [string]$ThemeMode  = ""           # dark|light
)

# ============================================================
#  HELPERS
# ============================================================

function Slugify([string]$text) {
    $text = $text.ToUpper() -replace '[^A-Z0-9\s-]', ''
    $text = $text.Trim() -replace '\s+', '-'
    return $text
}

function Get-FileDisplayName([string]$filename) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($filename)
    $name = $name -replace '^\d+[_\-]', ''
    $name = $name -replace '-', ' '
    return $name.ToUpper()
}

function InlineMarkdown([string]$text) {
    $text = [regex]::Replace($text, '`([^`]+)`', '<code>$1</code>')
    $text = [regex]::Replace($text, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $text = [regex]::Replace($text, '__(.+?)__',     '<strong>$1</strong>')
    $text = [regex]::Replace($text, '\*(.+?)\*', '<em>$1</em>')
    $text = [regex]::Replace($text, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
    return $text
}

function ConvertMarkdown([string]$md) {
    $lines           = $md -split "`r?`n"
    $html            = [System.Text.StringBuilder]::new()
    $inPre           = $false
    $inList          = $false
    $inOl            = $false
    $inTable         = $false
    $tableHeaderDone = $false

    foreach ($raw in $lines) {
        $line = $raw

        # ── Fenced code blocks ──────────────────────────────
        if ($line -match '^```') {
            if (-not $inPre) {
                if ($inList)  { [void]$html.AppendLine("</ul>");           $inList          = $false }
                if ($inOl)    { [void]$html.AppendLine("</ol>");           $inOl            = $false }
                if ($inTable) { [void]$html.AppendLine("</tbody></table>"); $inTable        = $false
                                                                             $tableHeaderDone = $false }
                $lang  = ($line -replace '^```', '').Trim()
                $class = if ($lang) { " class=`"language-$lang`"" } else { "" }
                [void]$html.AppendLine("<pre><code$class>")
                $inPre = $true
            } else {
                [void]$html.AppendLine("</code></pre>")
                $inPre = $false
            }
            continue
        }

        if ($inPre) {
            # Escape everything inside code blocks — including raw HTML tags
            $escaped = $line -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
            [void]$html.AppendLine($escaped)
            continue
        }

        # ── Skip raw HTML heading tags (avoid double rendering) ──
        if ($line -match '^<h[1-6][\s>]') { continue }
        if ($line -match '^</h[1-6]>') { continue }

        # ── Tables ──────────────────────────────────────────
        if ($line -match '^\|') {
            if ($inList) { [void]$html.AppendLine("</ul>"); $inList = $false }
            if ($inOl)   { [void]$html.AppendLine("</ol>"); $inOl   = $false }

            if ($line -match '^\|\s*[-:| ]+\s*\|') {
                if (-not $tableHeaderDone) {
                    [void]$html.AppendLine("</tr></thead><tbody>")
                    $tableHeaderDone = $true
                }
                continue
            }

            $cells = ($line -replace '^\||\|$', '') -split '\|'

            if (-not $inTable) {
                [void]$html.AppendLine("<table><thead><tr>")
                foreach ($cell in $cells) {
                    $c = InlineMarkdown $cell.Trim()
                    [void]$html.AppendLine("<th>$c</th>")
                }
                $inTable         = $true
                $tableHeaderDone = $false
            } else {
                [void]$html.AppendLine("<tr>")
                foreach ($cell in $cells) {
                    $c = InlineMarkdown $cell.Trim()
                    [void]$html.AppendLine("<td>$c</td>")
                }
                [void]$html.AppendLine("</tr>")
            }
            continue
        } else {
            if ($inTable) {
                [void]$html.AppendLine("</tbody></table>")
                $inTable         = $false
                $tableHeaderDone = $false
            }
        }

        $isUL = $line -match '^[ \t]*[-*+] (.+)$'
        $isOL = $line -match '^[ \t]*\d+\. (.+)$'

        if (-not $isUL -and $inList) { [void]$html.AppendLine("</ul>"); $inList = $false }
        if (-not $isOL -and $inOl)   { [void]$html.AppendLine("</ol>"); $inOl   = $false }

        # ── Headings ────────────────────────────────────────
        if ($line -match '^#{6} (.+)$') { [void]$html.AppendLine("<h6>$(InlineMarkdown $matches[1])</h6>"); continue }
        if ($line -match '^#{5} (.+)$') { [void]$html.AppendLine("<h5>$(InlineMarkdown $matches[1])</h5>"); continue }
        if ($line -match '^#{4} (.+)$') { [void]$html.AppendLine("<h4>$(InlineMarkdown $matches[1])</h4>"); continue }

        if ($line -match '^#{3} (.+)$') {
            $slug = Slugify $matches[1]
            [void]$html.AppendLine("<h3 id=`"$slug`">$($matches[1])</h3>")
            continue
        }
        if ($line -match '^#{2} (.+)$') {
            $slug = Slugify $matches[1]
            [void]$html.AppendLine("<h2 id=`"$slug`">$($matches[1])</h2>")
            continue
        }
        if ($line -match '^# (.+)$') {
            $slug = Slugify $matches[1]
            [void]$html.AppendLine("<h2 id=`"$slug`">$($matches[1])</h2>")
            continue
        }

        if ($line -match '^---+$') { [void]$html.AppendLine("<hr>"); continue }

        if ($line -match '^> (.*)$') {
            [void]$html.AppendLine("<blockquote><p>$(InlineMarkdown $matches[1])</p></blockquote>")
            continue
        }

        if ($isUL) {
            if (-not $inList) { [void]$html.AppendLine("<ul>"); $inList = $true }
            [void]$html.AppendLine("<li>$(InlineMarkdown $matches[1])</li>")
            continue
        }

        if ($isOL) {
            if (-not $inOl) { [void]$html.AppendLine("<ol>"); $inOl = $true }
            [void]$html.AppendLine("<li>$(InlineMarkdown $matches[1])</li>")
            continue
        }

        if ($line.Trim() -eq '') { [void]$html.AppendLine(""); continue }

        [void]$html.AppendLine("<p>$(InlineMarkdown $line)</p>")
    }

    if ($inList)  { [void]$html.AppendLine("</ul>") }
    if ($inOl)    { [void]$html.AppendLine("</ol>") }
    if ($inTable) { [void]$html.AppendLine("</tbody></table>") }

    return $html.ToString()
}

# ============================================================
#  CSS
# ============================================================

$CSS = @'
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:ital,wght@0,300;0,400;0,600;1,400&family=IBM+Plex+Sans:wght@300;400;600&display=swap');

/* ================================================================
   12 SELF-CONTAINED THEMES — 6 colors x 2 modes
   Each theme defines ALL variables. No overrides, no cascade.
   Set via data-theme="color-mode" on <body>.
================================================================ */

/* ---- BLUE DARK ---- */
[data-theme="blue-dark"] {
  --bg:            #0a0d0f;
  --bg-surface:    #0f1317;
  --bg-raised:     #141920;
  --text:          #b8c5cc;
  --text-muted:    #566470;
  --text-bright:   #dde8ed;
  --white:         #eef4f7;
  --code-bg:       #080b0e;
  --accent:        #4fc3f7;
  --accent-dim:    #1e6a8a;
  --accent-glow:   rgba(79,195,247,0.12);
  --amber:         #e8a94a;
  --border:        rgba(79,195,247,0.12);
  --border-mid:    rgba(79,195,247,0.25);
  --border-bright: rgba(79,195,247,0.50);
}
/* ---- BLUE LIGHT ---- */
[data-theme="blue-light"] {
  --bg:            #f4f6f8;
  --bg-surface:    #eaedf0;
  --bg-raised:     #dde2e8;
  --text:          #3a4a55;
  --text-muted:    #8a9baa;
  --text-bright:   #1a2a35;
  --white:         #0f1a22;
  --code-bg:       #e2e8ed;
  --accent:        #0284c7;
  --accent-dim:    #5aaad4;
  --accent-glow:   rgba(2,132,199,0.10);
  --amber:         #b45309;
  --border:        rgba(2,132,199,0.18);
  --border-mid:    rgba(2,132,199,0.35);
  --border-bright: rgba(2,132,199,0.65);
}

/* ---- RED DARK ---- */
[data-theme="red-dark"] {
  --bg:            #0f0a0a;
  --bg-surface:    #140f0f;
  --bg-raised:     #1c1212;
  --text:          #ccb8b8;
  --text-muted:    #6e5050;
  --text-bright:   #eddcdc;
  --white:         #f7eded;
  --code-bg:       #0e0808;
  --accent:        #f47c7c;
  --accent-dim:    #7a2a2a;
  --accent-glow:   rgba(244,124,124,0.12);
  --amber:         #f5c842;
  --border:        rgba(244,124,124,0.12);
  --border-mid:    rgba(244,124,124,0.25);
  --border-bright: rgba(244,124,124,0.50);
}
/* ---- RED LIGHT ---- */
[data-theme="red-light"] {
  --bg:            #faf5f5;
  --bg-surface:    #f0e8e8;
  --bg-raised:     #e5d8d8;
  --text:          #4a2a2a;
  --text-muted:    #9a7a7a;
  --text-bright:   #2a1010;
  --white:         #1a0808;
  --code-bg:       #ecdcdc;
  --accent:        #c0392b;
  --accent-dim:    #c47a74;
  --accent-glow:   rgba(192,57,43,0.10);
  --amber:         #b45309;
  --border:        rgba(192,57,43,0.18);
  --border-mid:    rgba(192,57,43,0.35);
  --border-bright: rgba(192,57,43,0.65);
}

/* ---- AMBER DARK ---- */
[data-theme="amber-dark"] {
  --bg:            #0f0d08;
  --bg-surface:    #141108;
  --bg-raised:     #1c160a;
  --text:          #ccc4a0;
  --text-muted:    #6e6240;
  --text-bright:   #ede8cc;
  --white:         #f7f2e8;
  --code-bg:       #0e0c06;
  --accent:        #f5c842;
  --accent-dim:    #7a5c0a;
  --accent-glow:   rgba(245,200,66,0.12);
  --amber:         #f47c7c;
  --border:        rgba(245,200,66,0.12);
  --border-mid:    rgba(245,200,66,0.25);
  --border-bright: rgba(245,200,66,0.50);
}
/* ---- AMBER LIGHT ---- */
[data-theme="amber-light"] {
  --bg:            #faf8f0;
  --bg-surface:    #f0ece0;
  --bg-raised:     #e8e0cc;
  --text:          #4a3c10;
  --text-muted:    #9a8c50;
  --text-bright:   #2a2008;
  --white:         #181000;
  --code-bg:       #ece4cc;
  --accent:        #c07d00;
  --accent-dim:    #c4a050;
  --accent-glow:   rgba(192,125,0,0.10);
  --amber:         #c0392b;
  --border:        rgba(192,125,0,0.18);
  --border-mid:    rgba(192,125,0,0.35);
  --border-bright: rgba(192,125,0,0.65);
}

/* ---- GREEN DARK ---- */
[data-theme="green-dark"] {
  --bg:            #080f0c;
  --bg-surface:    #0c1410;
  --bg-raised:     #101c16;
  --text:          #a8ccb8;
  --text-muted:    #456455;
  --text-bright:   #d0eddc;
  --white:         #e8f7ee;
  --code-bg:       #060e0a;
  --accent:        #4fcf8a;
  --accent-dim:    #1a5c3a;
  --accent-glow:   rgba(79,207,138,0.12);
  --amber:         #f5c842;
  --border:        rgba(79,207,138,0.12);
  --border-mid:    rgba(79,207,138,0.25);
  --border-bright: rgba(79,207,138,0.50);
}
/* ---- GREEN LIGHT ---- */
[data-theme="green-light"] {
  --bg:            #f2faf5;
  --bg-surface:    #e4f2ea;
  --bg-raised:     #d4e8db;
  --text:          #1a3a28;
  --text-muted:    #6a9a7a;
  --text-bright:   #0a2018;
  --white:         #051208;
  --code-bg:       #d8eade;
  --accent:        #0a7c45;
  --accent-dim:    #4aa070;
  --accent-glow:   rgba(10,124,69,0.10);
  --amber:         #b45309;
  --border:        rgba(10,124,69,0.18);
  --border-mid:    rgba(10,124,69,0.35);
  --border-bright: rgba(10,124,69,0.65);
}

/* ---- PURPLE DARK ---- */
[data-theme="purple-dark"] {
  --bg:            #0c0a10;
  --bg-surface:    #100d16;
  --bg-raised:     #16121e;
  --text:          #bab0cc;
  --text-muted:    #5a5070;
  --text-bright:   #ddd8ed;
  --white:         #eeeaf7;
  --code-bg:       #09070e;
  --accent:        #b57bf7;
  --accent-dim:    #5a2a8a;
  --accent-glow:   rgba(181,123,247,0.12);
  --amber:         #f5c842;
  --border:        rgba(181,123,247,0.12);
  --border-mid:    rgba(181,123,247,0.25);
  --border-bright: rgba(181,123,247,0.50);
}
/* ---- PURPLE LIGHT ---- */
[data-theme="purple-light"] {
  --bg:            #f7f4ff;
  --bg-surface:    #ede8f8;
  --bg-raised:     #e0d8f0;
  --text:          #2a1a4a;
  --text-muted:    #8a7aaa;
  --text-bright:   #180a30;
  --white:         #0e0520;
  --code-bg:       #e0d8f0;
  --accent:        #7c3aed;
  --accent-dim:    #a07ad8;
  --accent-glow:   rgba(124,58,237,0.10);
  --amber:         #b45309;
  --border:        rgba(124,58,237,0.18);
  --border-mid:    rgba(124,58,237,0.35);
  --border-bright: rgba(124,58,237,0.65);
}

/* ---- MONO DARK ---- */
[data-theme="mono-dark"] {
  --bg:            #0a0a0a;
  --bg-surface:    #111111;
  --bg-raised:     #1a1a1a;
  --text:          #b0b8c0;
  --text-muted:    #505860;
  --text-bright:   #d8e0e8;
  --white:         #eef0f2;
  --code-bg:       #080808;
  --accent:        #d0d8e0;
  --accent-dim:    #566470;
  --accent-glow:   rgba(208,216,224,0.10);
  --amber:         #a0acb8;
  --border:        rgba(208,216,224,0.10);
  --border-mid:    rgba(208,216,224,0.20);
  --border-bright: rgba(208,216,224,0.45);
}
/* ---- MONO LIGHT ---- */
[data-theme="mono-light"] {
  --bg:            #f5f5f5;
  --bg-surface:    #ebebeb;
  --bg-raised:     #dedede;
  --text:          #2a3038;
  --text-muted:    #808890;
  --text-bright:   #141820;
  --white:         #080c10;
  --code-bg:       #e0e4e8;
  --accent:        #2a3a45;
  --accent-dim:    #7a8a95;
  --accent-glow:   rgba(42,58,69,0.08);
  --amber:         #4a5a65;
  --border:        rgba(42,58,69,0.15);
  --border-mid:    rgba(42,58,69,0.28);
  --border-bright: rgba(42,58,69,0.55);
}

/* ================================================================
   SHARED LAYOUT — uses only CSS variables, works with all themes
================================================================ */
:root { --sidebar-w: 260px; }

*, *::before, *::after { box-sizing: border-box; }
html { scroll-behavior: smooth; }

body {
  background: var(--bg);
  color: var(--text);
  font-family: 'IBM Plex Sans', system-ui, sans-serif;
  font-size: 12.5pt;
  line-height: 1.72;
  margin: 0;
  display: flex;
  transition: background 0.2s, color 0.2s;
}

/* SIDEBAR */
#sidebar {
  position: fixed;
  top: 0; left: 0;
  width: var(--sidebar-w);
  height: 100vh;
  overflow-y: auto;
  background: var(--bg-surface);
  border-right: 1px solid var(--border-mid);
  padding: 0 0 40px;
  z-index: 100;
  flex-shrink: 0;
}

#sidebar-header {
  position: sticky;
  top: 0;
  background: var(--bg-surface);
  z-index: 1;
  border-bottom: 1px solid var(--border-mid);
  padding: 16px 20px 12px;
}

#sidebar-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

#sidebar-title {
  font-family: 'IBM Plex Mono', monospace;
  font-size: 11pt;
  font-weight: 600;
  color: var(--accent);
  letter-spacing: 0.14em;
}

/* THEME TOGGLE */
#theme-toggle {
  background: var(--bg-raised);
  border: 1px solid var(--border-mid);
  border-radius: 20px;
  cursor: pointer;
  padding: 3px 10px;
  font-family: 'IBM Plex Mono', monospace;
  font-size: 8pt;
  color: var(--text-muted);
  transition: color 0.15s, border-color 0.15s;
  white-space: nowrap;
}
#theme-toggle:hover {
  color: var(--accent);
  border-color: var(--accent);
}

#sidebar-search {
  display: block;
  width: 100%;
  background: var(--bg-raised);
  border: 1px solid var(--border-mid);
  border-radius: 3px;
  color: var(--text-bright);
  font-family: 'IBM Plex Mono', monospace;
  font-size: 9pt;
  padding: 6px 10px;
  outline: none;
  transition: border-color 0.15s;
}
#sidebar-search:focus { border-color: var(--accent); }

/* TOC */
.toc-file { margin-top: 4px; }

.toc-file-label {
  font-family: 'IBM Plex Mono', monospace;
  font-size: 8.5pt;
  font-weight: 600;
  color: var(--accent);
  letter-spacing: 0.12em;
  text-transform: uppercase;
  padding: 10px 20px 3px;
  display: block;
}

.toc-h2, .toc-h3 {
  display: block;
  font-family: 'IBM Plex Mono', monospace;
  font-size: 8.5pt;
  color: var(--text-bright);
  text-decoration: none;
  padding: 2px 20px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.toc-h3 {
  padding-left: 32px;
  font-size: 8pt;
}

/* MAIN */
#main {
  margin-left: var(--sidebar-w);
  padding: 44px 60px;
  width: calc(100% - var(--sidebar-w));
  min-width: 0;
}

.file-section {
  border-top: 1px solid var(--border-mid);
  margin-top: 60px;
  padding-top: 4px;
}
.file-section:first-child { border-top: none; margin-top: 0; }

.file-section-label {
  font-family: 'IBM Plex Mono', monospace;
  font-size: 8pt;
  color: var(--text-muted);
  letter-spacing: 0.18em;
  text-transform: uppercase;
  margin: 0 0 2px;
}

h1.page-title {
  font-family: 'IBM Plex Mono', monospace;
  font-size: 20pt; font-weight: 600;
  color: var(--white);
  letter-spacing: 0.08em;
  text-align: center;
  margin: 0 0 48px;
  padding: 28px 0 24px;
  border-bottom: 1px solid var(--border-mid);
}
h1.page-title::after {
  content: '';
  display: block;
  width: 60px; height: 2px;
  background: var(--accent);
  margin: 14px auto 0;
  box-shadow: 0 0 8px var(--accent);
}

h2 {
  font-family: 'IBM Plex Mono', monospace;
  font-size: 13pt; font-weight: 600;
  color: var(--accent);
  letter-spacing: 0.10em; text-transform: uppercase;
  margin: 44px 0 20px;
  padding: 0 0 10px;
  border-bottom: 1px solid var(--border);
  scroll-margin-top: 24px;
}
h2::before { content: '// '; color: var(--accent-dim); font-weight: 300; }

h3 {
  font-family: 'IBM Plex Mono', monospace;
  font-size: 10.5pt; font-weight: 600;
  color: var(--text-bright);
  letter-spacing: 0.10em; text-transform: uppercase;
  margin: 28px 0 10px;
  padding: 6px 0 6px 10px;
  border-left: 3px solid var(--accent-dim);
  scroll-margin-top: 24px;
}

h4 {
  font-family: 'IBM Plex Mono', monospace;
  font-size: 10pt; font-weight: 400;
  color: var(--amber); letter-spacing: 0.08em;
  margin: 20px 0 8px;
}
h5 { font-size: 10pt; color: var(--text-bright); margin: 16px 0 6px; }
h6 { font-size: 9.5pt; color: var(--text-muted); margin: 14px 0 6px; }

p { margin: 12px 0; }
strong { color: var(--white); font-weight: 600; }
em { color: var(--accent); font-style: italic; }
hr { border: none; height: 1px; background: var(--border); margin: 36px 0; }

ul { margin: 10px 0 10px 20px; padding: 0; }
ul li { margin: 5px 0; }
ol { margin: 10px 0 10px 20px; padding: 0; }
ol li { margin: 5px 0; }

a, a:visited { color: var(--accent); text-decoration: none; transition: color 0.15s; }
a:hover { color: var(--white); text-decoration: underline; }

#sidebar a, #sidebar a:visited, #sidebar a:hover {
  color: var(--text-bright);
  text-decoration: none;
}

code {
  font-family: 'IBM Plex Mono', monospace;
  background: var(--bg-raised); color: var(--accent);
  font-size: 0.88em; padding: 2px 7px;
  border: 1px solid var(--border-mid); border-radius: 3px;
}
pre {
  background: var(--code-bg); color: var(--text-bright);
  font-family: 'IBM Plex Mono', monospace;
  font-size: 10.5pt; line-height: 1.65;
  padding: 20px 22px; border-radius: 4px;
  border: 1px solid var(--border); border-top: 2px solid var(--accent-dim);
  overflow-x: auto; margin: 16px 0;
}
pre code { color: var(--text-bright); background: none; border: none; padding: 0; font-size: inherit; }

blockquote {
  border-left: 3px solid var(--amber); background: var(--bg-surface);
  margin: 18px 0; padding: 12px 18px;
  color: var(--text-bright); border-radius: 0 4px 4px 0;
}
blockquote p { margin: 4px 0; }

table { width: 100%; border-collapse: collapse; margin: 18px 0; font-size: 0.93em; font-family: 'IBM Plex Mono', monospace; }
th, td { border: 1px solid var(--border); padding: 8px 13px; vertical-align: top; word-break: break-word; }
th { background: var(--bg-raised); color: var(--accent); font-weight: 600; font-size: 0.82em; letter-spacing: 0.10em; text-transform: uppercase; border-bottom: 1px solid var(--border-mid); white-space: nowrap; }
tr:nth-child(even) td { background: rgba(255,255,255,0.018); }
tr:hover td { background: var(--accent-glow); }

/* MOBILE */
#sidebar-toggle {
  display: none;
  position: fixed;
  top: 12px;
  left: 12px;
  z-index: 200;
  background: var(--bg-raised);
  border: 1px solid var(--border-mid);
  border-radius: 4px;
  color: var(--accent);
  font-family: 'IBM Plex Mono', monospace;
  font-size: 10pt;
  padding: 6px 10px;
  cursor: pointer;
  line-height: 1;
}

#sidebar-overlay {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  z-index: 99;
}

@media (max-width: 768px) {
  #sidebar-toggle { display: block; }

  #sidebar {
    transform: translateX(-100%);
    transition: transform 0.25s ease;
  }
  #sidebar.open {
    transform: translateX(0);
  }
  #sidebar-overlay.open {
    display: block;
  }
  #main {
    margin-left: 0;
    padding: 60px 20px 40px;
    max-width: 100%;
    width: 100%;
  }
}

::selection { background: var(--accent-glow); color: var(--white); }
::-webkit-scrollbar { width: 5px; height: 5px; }
::-webkit-scrollbar-track { background: var(--bg); }
::-webkit-scrollbar-thumb { background: var(--accent-dim); border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: var(--accent); }
'@

# ============================================================
#  JS
# ============================================================

$JS = @'
(function() {
  // Mobile sidebar toggle
  var sidebarToggle  = document.getElementById('sidebar-toggle');
  var sidebarOverlay = document.getElementById('sidebar-overlay');
  var sidebar        = document.getElementById('sidebar');

  sidebarToggle.addEventListener('click', function() {
    sidebar.classList.toggle('open');
    sidebarOverlay.classList.toggle('open');
  });
  sidebarOverlay.addEventListener('click', function() {
    sidebar.classList.remove('open');
    sidebarOverlay.classList.remove('open');
  });
  // Close sidebar on link click (mobile)
  document.querySelectorAll('.toc-h2, .toc-h3').forEach(function(link) {
    link.addEventListener('click', function() {
      if (window.innerWidth <= 768) {
        sidebar.classList.remove('open');
        sidebarOverlay.classList.remove('open');
      }
    });
  });

  // Theme toggle — switches between color-dark <-> color-light
  var toggle   = document.getElementById('theme-toggle');
  var body     = document.body;
  var current  = body.getAttribute('data-theme'); // e.g. "blue-dark"
  var parts    = current.split('-');
  var color    = parts.slice(0, parts.length - 1).join('-'); // "blue", "red", etc.
  var mode     = parts[parts.length - 1];                    // "dark" or "light"

  // Restore saved mode preference if available
  var savedMode = localStorage.getItem('noice-mode');
  if (savedMode && savedMode !== mode) {
    mode = savedMode;
    body.setAttribute('data-theme', color + '-' + mode);
  }
  toggle.textContent = (mode === 'dark') ? 'LIGHT' : 'DARK';

  toggle.addEventListener('click', function() {
    var cur   = body.getAttribute('data-theme');
    var p     = cur.split('-');
    var col   = p.slice(0, p.length - 1).join('-');
    var m     = p[p.length - 1];
    var next  = (m === 'dark') ? 'light' : 'dark';
    body.setAttribute('data-theme', col + '-' + next);
    toggle.textContent = (next === 'dark') ? 'LIGHT' : 'DARK';
    localStorage.setItem('noice-mode', next);
  });

  // Search filter
  var allLinks = document.querySelectorAll('.toc-h2, .toc-h3');
  var search = document.getElementById('sidebar-search');
  search.addEventListener('input', function() {
    var q = search.value.trim().toLowerCase();
    allLinks.forEach(function(link) {
      link.style.display = (!q || link.textContent.toLowerCase().indexOf(q) !== -1) ? '' : 'none';
    });
    document.querySelectorAll('.toc-file').forEach(function(file) {
      var visible = Array.from(file.querySelectorAll('.toc-h2, .toc-h3')).some(function(l) {
        return l.style.display !== 'none';
      });
      file.style.display = (!q || visible) ? '' : 'none';
    });
  });
})();
'@

# ============================================================
#  MAIN
# ============================================================

if (-not (Test-Path $NotesDir)) {
    Write-Error "Directory not found: $NotesDir"
    exit 1
}

$mdFiles = Get-ChildItem -Path $NotesDir -Filter "*.md" | Sort-Object Name

if ($mdFiles.Count -eq 0) {
    Write-Warning "No .md files found in: $NotesDir"
    exit 0
}

# ── Prompt 1: Title ─────────────────────────────────────────
if (-not $Title) {
    Write-Host ""
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |         BUILD-NOTES SETUP            |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    $inputTitle = Read-Host "  [1/3] Document title [NOTES]"
    if ($inputTitle.Trim() -eq '') { $Title = "NOTES" } else { $Title = $inputTitle.Trim() }
}

# ── Prompt 2: Accent color ───────────────────────────────────
$validColors = @('blue','red','amber','green','purple','mono')
if (-not $ThemeColor -or $validColors -notcontains $ThemeColor.ToLower()) {
    Write-Host ""
    Write-Host "  [2/3] Choose an accent color:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    1  BLUE    #4fc3f7" -ForegroundColor Blue
    Write-Host "    2  RED     #f47c7c" -ForegroundColor Red
    Write-Host "    3  AMBER   #f5c842" -ForegroundColor Yellow
    Write-Host "    4  GREEN   #4fcf8a" -ForegroundColor Green
    Write-Host "    5  PURPLE  #b57bf7" -ForegroundColor Magenta
    Write-Host "    6  MONO    #d0d8e0" -ForegroundColor Gray
    Write-Host ""
    $colorInput = Read-Host "  Number or name [1]"
    $colorInput = $colorInput.Trim().ToLower()
    switch ($colorInput) {
        '1'      { $ThemeColor = 'blue'   }
        '2'      { $ThemeColor = 'red'    }
        '3'      { $ThemeColor = 'amber'  }
        '4'      { $ThemeColor = 'green'  }
        '5'      { $ThemeColor = 'purple' }
        '6'      { $ThemeColor = 'mono'   }
        'blue'   { $ThemeColor = 'blue'   }
        'red'    { $ThemeColor = 'red'    }
        'amber'  { $ThemeColor = 'amber'  }
        'green'  { $ThemeColor = 'green'  }
        'purple' { $ThemeColor = 'purple' }
        'mono'   { $ThemeColor = 'mono'   }
        default  { $ThemeColor = 'blue'   }
    }
}

# ── Prompt 3: Default mode ───────────────────────────────────
$validModes = @('dark','light')
if (-not $ThemeMode -or $validModes -notcontains $ThemeMode.ToLower()) {
    Write-Host ""
    $modeInput = Read-Host "  [3/3] Default mode  [D]ark / [L]ight  [D]"
    $modeInput = $modeInput.Trim().ToLower()
    if ($modeInput -eq 'l' -or $modeInput -eq 'light') { $ThemeMode = 'light' } else { $ThemeMode = 'dark' }
}

# ── Build output filename from title if not specified ────────
if (-not $OutputFile) {
    $safeName   = ($Title -replace '[^A-Za-z0-9_\-]', '_').ToLower()
    $OutputFile = "$PSScriptRoot\$safeName.html"
}

# ── Build data-theme value ───────────────────────────────────
$dataTheme       = "$ThemeColor-$ThemeMode"
$toggleInitLabel = if ($ThemeMode -eq 'light') { "DARK" } else { "LIGHT" }

Write-Host ""
Write-Host "  Title    : $Title" -ForegroundColor White
Write-Host "  Color    : $($ThemeColor.ToUpper())" -ForegroundColor White
Write-Host "  Mode     : $($ThemeMode.ToUpper())" -ForegroundColor White
Write-Host "  Output   : $OutputFile" -ForegroundColor White
Write-Host ""
Write-Host "  [$($mdFiles.Count) file(s)] $NotesDir" -ForegroundColor Cyan

$tocHtml  = [System.Text.StringBuilder]::new()
$bodyHtml = [System.Text.StringBuilder]::new()

foreach ($file in $mdFiles) {
    $displayName = Get-FileDisplayName $file.Name
    $rawMd       = Get-Content $file.FullName -Raw -Encoding UTF8

    Write-Host "  OK  $($file.Name)" -ForegroundColor Green

    # Build sidebar TOC (H2 + H3 only, skip raw HTML heading tags)
    [void]$tocHtml.AppendLine("<div class=`"toc-file`">")
    [void]$tocHtml.AppendLine("<span class=`"toc-file-label`">$displayName</span>")

    foreach ($mdLine in ($rawMd -split "`r?`n")) {
        if ($mdLine -match '^<h[1-6]') { continue }
        if ($mdLine -match '^#{2} (.+)$' -or $mdLine -match '^# (.+)$') {
            $text = $matches[1] -replace '\*\*|__|\*|_|`', ''
            $slug = Slugify $text
            [void]$tocHtml.AppendLine("<a class=`"toc-h2`" href=`"#$slug`">$text</a>")
        }
        elseif ($mdLine -match '^#{3} (.+)$') {
            $text = $matches[1] -replace '\*\*|__|\*|_|`', ''
            $slug = Slugify $text
            [void]$tocHtml.AppendLine("<a class=`"toc-h3`" href=`"#$slug`">$text</a>")
        }
    }

    [void]$tocHtml.AppendLine("</div>")

    $convertedHtml = ConvertMarkdown $rawMd
    [void]$bodyHtml.AppendLine("<section class=`"file-section`">")
    [void]$bodyHtml.AppendLine($convertedHtml)
    [void]$bodyHtml.AppendLine("</section>")
}

$fullHtml  = "<!DOCTYPE html>`r`n"
$fullHtml += "<html lang=`"en`">`r`n"
$fullHtml += "<head>`r`n"
$fullHtml += "  <meta charset=`"UTF-8`">`r`n"
$fullHtml += "  <meta name=`"viewport`" content=`"width=device-width, initial-scale=1.0`">`r`n"
$fullHtml += "  <title>$Title</title>`r`n"
$fullHtml += "  <style>`r`n$CSS`r`n  </style>`r`n"
$fullHtml += "</head>`r`n"
$fullHtml += "<body data-theme=`"$dataTheme`">`r`n"
$fullHtml += "<button id=`"sidebar-toggle`">&#9776;</button>`r`n"
$fullHtml += "<div id=`"sidebar-overlay`"></div>`r`n"
$fullHtml += "<nav id=`"sidebar`">`r`n"
$fullHtml += "  <div id=`"sidebar-header`">`r`n"
$fullHtml += "    <div id=`"sidebar-top`">`r`n"
$fullHtml += "      <span id=`"sidebar-title`">// $Title</span>`r`n"
$fullHtml += "      <button id=`"theme-toggle`">$toggleInitLabel</button>`r`n"
$fullHtml += "    </div>`r`n"
$fullHtml += "    <input id=`"sidebar-search`" type=`"search`" placeholder=`"Filter...`">`r`n"
$fullHtml += "  </div>`r`n"
$fullHtml += $tocHtml.ToString()
$fullHtml += "</nav>`r`n"
$fullHtml += "<main id=`"main`">`r`n"
$fullHtml += "  <h1 class=`"page-title`">$Title</h1>`r`n"
$fullHtml += $bodyHtml.ToString()
$fullHtml += "</main>`r`n"
$fullHtml += "<script>`r`n$JS`r`n</script>`r`n"
$fullHtml += "</body>`r`n</html>"

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutputFile, $fullHtml, $utf8NoBom)

Write-Host ""
Write-Host "  DONE  HTML generated: $OutputFile" -ForegroundColor Green
Write-Host "        Open this file in your browser." -ForegroundColor DarkGray
Write-Host ""
