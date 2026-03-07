# Build-Notes

A PowerShell script that compiles a folder of Markdown files into a single self-contained HTML document. No dependencies, no Node, no Python. Just drop your `.md` files in a folder and run the script.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell) ![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey) ![License](https://img.shields.io/badge/License-MIT-green)

---

## Features

- Compiles multiple Markdown files into one clean HTML page
- Fixed sidebar with navigation, search filter, and dark/light toggle
- 6 accent color themes, each with a dark and light variant (12 total)
- Numeric file prefixes for manual ordering (`01_`, `02_`, etc.)
- Fully self-contained output one `.html` file, no external dependencies
- Mobile-friendly with collapsible sidebar
- Interactive setup prompts or fully scriptable via CLI flags

---

## Requirements

- Windows 10 / 11
- PowerShell 5.1 or later (built-in on Windows, no install needed)

---

## Usage

### Quick start

```powershell
.\Build-Notes.ps1
```

The script will ask 3 questions:

```
[1/3] Document title [NOTES]
[2/3] Choose an accent color:
        1  BLUE    #4fc3f7
        2  RED     #f47c7c
        3  AMBER   #f5c842
        4  GREEN   #4fcf8a
        5  PURPLE  #b57bf7
        6  MONO    #d0d8e0
[3/3] Default mode  [D]ark / [L]ight
```

Press **Enter** on any prompt to accept the default. The output file is generated next to the script, named after your title (e.g. `notes.html`).

### CLI flags

All prompts can be skipped by passing parameters:

```powershell
.\Build-Notes.ps1 -Title "CYBERLAB" -ThemeColor "green" -ThemeMode "dark"
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-NotesDir` | Path to the folder containing your `.md` files | `.\MARKDOWN` |
| `-OutputFile` | Path for the generated HTML file | Auto-generated from title |
| `-Title` | Document title shown in the page and sidebar | Prompted |
| `-ThemeColor` | Accent color: `blue` `red` `amber` `green` `purple` `mono` | Prompted |
| `-ThemeMode` | Starting display mode: `dark` or `light` | Prompted |

---

## Folder structure

```
your-notes\
├── MARKDOWN\
│   ├── 01_windows.md       <- numeric prefix forces this file first
│   ├── 02_linux.md         <- second
│   ├── networking.md       <- no prefix, sorted alphabetically after
│   └── tools.md
├── Build-Notes.ps1
└── notes.html              <- generated output
```

Files without a numeric prefix are sorted A to Z automatically. Add a `01_`, `02_` prefix only when you want specific files pinned to the top. The prefix is stripped from display names, so `01_windows` shows as `WINDOWS` in the sidebar.

---

## Themes

Each color has an independent dark and light variant. The toggle in the sidebar switches between them live, and the preference is saved in `localStorage`.

| Color | Dark accent | Light accent |
|-------|-------------|--------------|
| `blue` | `#4fc3f7` | `#0284c7` |
| `red` | `#f47c7c` | `#c0392b` |
| `amber` | `#f5c842` | `#c07d00` |
| `green` | `#4fcf8a` | `#0a7c45` |
| `purple` | `#b57bf7` | `#7c3aed` |
| `mono` | `#d0d8e0` | `#2a3a45` |

---

## Markdown support

| Element | Supported |
|---------|-----------|
| Headings `#` `##` `###` `####` | Yes |
| Bold `**text**` and `__text__` | Yes |
| Italic `*text*` | Yes |
| Inline code `` `code` `` | Yes |
| Fenced code blocks | Yes |
| Unordered lists | Yes |
| Ordered lists | Yes |
| Tables | Yes |
| Links | Yes |
| Blockquotes | Yes |
| Horizontal rules | Yes |
| Raw HTML heading tags with `id` attributes | Yes |

---

## License

MIT
