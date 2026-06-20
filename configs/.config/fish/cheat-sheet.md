# 🐟 Fish Shell Cheat Sheet

> Run `cheat-fish` to view this anytime

---

## 🚀 Quick Reference (Most Used)

| Alias    | Command            | Alias  | Command        |
| -------- | ------------------ | ------ | -------------- |
| `c`      | clear              | `n`    | nvim           |
| `q`      | exit               | `e`    | $EDITOR        |
| `ls`     | eza (list)         | `ll`   | eza (list all) |
| `z`      | zoxide (smart cd)  | `fcd`  | fzf cd         |
| `gs`     | git status         | `gp`   | git push       |
| `ga`     | git add            | `gc`   | git commit -m  |
| `reload` | source config.fish | `copy` | wl-copy        |

---

## 📦 Custom Tools

| Alias | Command              |
| ----- | -------------------- |
| `dm`  | dot-man              |
| `dms` | dot-man status       |
| `dmt` | dot-man tui          |
| `pm`  | pro-mgr              |
| `pml` | pro-mgr project list |

---

## 🔀 Git

### Basic Operations

| Alias         | Command                    |
| ------------- | -------------------------- |
| `ga`          | git add                    |
| `gaa`         | git add .                  |
| `gs`          | git status                 |
| `gp`          | git push                   |
| `gpull`       | git pull                   |
| `gf`          | git fetch --all --prune    |
| `gc <msg>`    | git commit -m              |
| `gcm`         | git commit (opens editor)  |
| `gcom <msg>`  | git add . && git commit -m |
| `lazyg <msg>` | add + commit + push        |

### Branching

| Alias  | Command                      |
| ------ | ---------------------------- |
| `gco`  | git checkout                 |
| `gcb`  | git checkout -b (new branch) |
| `gsw`  | git switch                   |
| `gswc` | git switch -c (new branch)   |
| `gb`   | git branch                   |
| `gba`  | git branch -a                |
| `gbf`  | 🔍 fzf branch switcher       |

### Diff & Log

| Alias  | Command                 |
| ------ | ----------------------- |
| `gd`   | git diff                |
| `gds`  | git diff --staged       |
| `gl`   | git log (graph)         |
| `glog` | git log (pretty format) |

### Stash & Reset

| Alias      | Command                   |
| ---------- | ------------------------- |
| `gst`      | git stash                 |
| `gstp`     | git stash pop             |
| `grs`      | reset soft (keep changes) |
| `grh`      | reset hard (discard)      |
| `gunstage` | git restore --staged      |
| `gundo`    | discard file changes      |
| `gclean`   | remove untracked files    |

### Advanced

| Alias  | Command                  |
| ------ | ------------------------ |
| `gca`  | commit --amend           |
| `gcan` | commit --amend --no-edit |
| `gcp`  | cherry-pick              |
| `grb`  | rebase                   |
| `gwip` | quick WIP commit         |
| `gpr`  | push + create PR         |
| `gcl`  | git clone                |

---

## 🐙 GitHub CLI

| Alias   | Command          |
| ------- | ---------------- |
| `ghi`   | gh issue list    |
| `ghpr`  | gh pr list       |
| `ghprc` | gh pr create     |
| `ghprv` | gh pr view --web |
| `ghc`   | gh repo clone    |

---

## 📂 Files & Navigation

| Alias | Command        | Alias  | Command    |
| ----- | -------------- | ------ | ---------- |
| `l`   | eza -lh (long) | `lt`   | eza tree   |
| `ls`  | eza -1 (short) | `fnd`  | fd (find)  |
| `ll`  | eza -lha (all) | `z`    | zoxide cd  |
| `ld`  | eza dirs only  | `mkcd` | mkdir + cd |

### Safe Operations

| Alias | Command              |
| ----- | -------------------- |
| `cp`  | cp -ri (safe copy)   |
| `mv`  | mv -iv (safe move)   |
| `rm`  | rem (moves to trash) |
| `md`  | mkdir -p             |

---

## 🔍 FZF Functions

| Function    | What it does            |
| ----------- | ----------------------- |
| `fe`        | Fuzzy find & edit file  |
| `fcd`       | Fuzzy find & cd to dir  |
| `gbf`       | Fuzzy git branch switch |
| `ff <name>` | Find file by name       |

---

## 📦 Package Manager (Arch)

| Alias  | Command          |
| ------ | ---------------- |
| `pac`  | sudo pacman -S   |
| `pacr` | sudo pacman -Rns |
| `pacu` | sudo pacman -Syu |
| `pacs` | pacman -Ss       |
| `yays` | yay -Ss          |

---

## ⚙️ Systemd

| Alias | Command                |
| ----- | ---------------------- |
| `sc`  | sudo systemctl         |
| `scs` | systemctl status       |
| `sce` | sudo systemctl enable  |
| `scd` | sudo systemctl disable |
| `scr` | sudo systemctl restart |

---

## 🗑️ Trash

| Alias         | Command                  |
| ------------- | ------------------------ |
| `trash-list`  | list trash contents      |
| `trash-empty` | empty trash              |
| `empty`       | interactive trash delete |

---

## 📋 Clipboard (Wayland)

| Alias   | Command  |
| ------- | -------- |
| `copy`  | wl-copy  |
| `paste` | wl-paste |

---

## 🛠️ Utilities

| Function           | What it does            |
| ------------------ | ----------------------- |
| `note <text>`      | Quick timestamped note  |
| `note`             | Open today's notes      |
| `weather <city>`   | Get weather             |
| `cheat <cmd>`      | Get cheat sheet         |
| `gitignore <lang>` | Fetch .gitignore        |
| `colors`           | Display terminal colors |
| `backup <file>`    | Create .bak copy        |
| `compress <dir>`   | Create tar.gz           |
| `gdrive`           | Mount Google Drive      |

---

## 💻 System Info

| Alias     | Command           |
| --------- | ----------------- |
| `h`       | history           |
| `hs`      | history \| grep    |
| `path`    | pretty print PATH |
| `myip`    | public IP         |
| `localip` | local IP          |
| `ports`   | show open ports   |
| `df`      | disk usage        |
| `free`    | memory usage      |