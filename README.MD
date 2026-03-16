# many-grub

A simple CLI utility for managing **GRUB themes**.

`many-grub` lets you install, preview, and switch GRUB themes easily without manually editing `/etc/default/grub`.

It supports:

* installing themes from folders
* installing themes directly from Git repositories
* automatic theme detection (`theme.txt`)
* backup and restore of GRUB configuration
* previewing theme screenshots

---

# Installation

Clone the repository and run the script:

```bash
git clone https://github.com/<your-user>/many-grub
cd many-grub
chmod +x many-grub.sh
```

You can optionally place it in your PATH:

```bash
sudo cp many-grub.sh /usr/local/bin/many-grub
```

---

# Usage

```bash
many-grub [command] [arguments]
```

Available commands:

| Command          | Description                                    |
| ---------------- | ---------------------------------------------- |
| `add [DIR]`      | Add a theme from a directory                   |
| `git-add [REPO]` | Clone a repository and install detected themes |
| `install [DIR]`  | Add and immediately apply a theme              |
| `set [NAME]`     | Apply an installed theme                       |
| `list`           | List installed themes                          |
| `preview [NAME]` | Preview a theme image if available             |
| `current`        | Show the currently active theme                |
| `custom [FILE]`  | Use a custom `theme.txt` path                  |
| `backups`        | Show available GRUB config backups             |
| `restore`        | Restore the most recent backup                 |
| `help`           | Show help message                              |

---

# Examples

### Install a theme from a folder

```bash
many-grub add ./my-theme
```

---

### Install themes from a Git repository

```bash
many-grub git-add https://github.com/MrVivekRajan/Grub-Themes
```

`many-grub` automatically detects all directories containing a `theme.txt` file.

---

### Apply a theme

```bash
many-grub set Minimal-Arch
```

---

### Preview a theme

```bash
many-grub preview Minimal-Arch
```

---

### List installed themes

```bash
many-grub list
```

Example output:

```
Installed themes:

• Minimal-Arch
• Minimal-Ubuntu
• NeonPurple
```

---

# Safety

Before applying any theme, `many-grub` automatically creates a backup of:

```
/etc/default/grub
```

Backups are stored in:

```
~/.local/share/many-grub/backup
```

You can restore the latest backup with:

```bash
many-grub restore
```

---

# Theme Structure

A valid GRUB theme must contain:

```
theme-folder/
 ├── theme.txt
 ├── background.png
 └── other assets...
```

`many-grub` detects themes by searching for `theme.txt`.

---

# Philosophy

This project follows a simple idea:

> A CLI tool should do one thing well.

`many-grub` does not attempt to manage GRUB itself —
it simply helps install and switch themes safely.

---

# License

MIT
