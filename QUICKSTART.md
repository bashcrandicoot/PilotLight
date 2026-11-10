# PilotLight quick start

PilotLight shows a soft yellow glow around your screen, plus a pill that reads
**Grok is working**, while an agent is using your Mac.
Your clicks, scrolling and typing pass straight through it.

It's free and open source (MIT). You'll need macOS 13 or later.

On first launch, PilotLight opens a short Quick Start walkthrough. The
window is marked as seen as soon as it appears, so it does not open
automatically again. You can open it any time from the menu bar under
**Quick Start…**.

## 1. Install

A DMG is coming later. For now, install from source. You'll need the Xcode
Command Line Tools (run `xcode-select --install` if you don't have them).

```bash
git clone https://github.com/bashcrandicoot/PilotLight.git
cd PilotLight
./Scripts/build.sh
./Scripts/install.sh
```

The installer doesn't use `sudo`. It puts:

- the app in `~/Applications/PilotLight.app`
- the command at `~/bin/pilotlight` (`~/bin/grok-border` does the same thing)
- a login item, so PilotLight starts every time you log in

When it finishes, Ember (a small terracotta bun) shows up in your menu bar. The border
stays off until something turns it on.

If typing `pilotlight` says "command not found", use the full path
`~/bin/pilotlight`, or add `~/bin` to your `PATH`.

## 2. Try it

```bash
~/bin/pilotlight on       # show the border
~/bin/pilotlight status   # on, off or stale
~/bin/pilotlight off      # hide it
```

You can also open the menu bar icon and choose **Show Test Border for 5s** to
preview it. **Hide Border Now** turns it off right away.

## 3. Tell your agent to use it

PilotLight doesn't detect agents on its own. The agent has to turn it on and
off. Paste this into Grok, or any agent that can run commands on your Mac:

> Before you control my Mac, run `~/bin/pilotlight on`. During long work, run
> `~/bin/pilotlight ping` at least every 15 minutes. When you're done, run
> `~/bin/pilotlight off`, even if something failed. For a single command, you
> can wrap it instead: `~/bin/pilotlight run -- <command>`.

`run --` turns the border on, runs the command, and always turns it off
afterwards, even if the command fails.

## 4. Commands

| Command | What it does |
| --- | --- |
| `pilotlight on` | Shows the border |
| `pilotlight off` | Hides the border |
| `pilotlight ping` | Keeps the border alive during long work |
| `pilotlight status` | Prints `on`, `off` or `stale` |
| `pilotlight run -- <command>` | Turns it on, runs the command, then turns it off |

How it works: `on` creates a flag file at `~/.grok-working`, and `off` deletes
it. The app shows the border whenever that file exists, so any tool can create
or delete the file directly.

## 5. Auto-hide after 20 minutes

If the flag hasn't been touched for 20 minutes, PilotLight treats it as stale
and hides the border. That way a crashed agent can't leave the glow stuck on
your screen. `ping` refreshes the flag, so an agent on a long job should ping
every few minutes. A later `ping` or `on` brings a hidden border back.

## 6. Settings and Tip Jar

**Settings…** in the menu bar, or **Open Settings** on the last Quick Start
page, lets you pick a glow style, a color, and intensity.

**Tip Jar** in the menu, just above Quit, opens the same Ko-fi page as Lodge.
The last Quick Start page is a short thank-you, with a Tip Jar button. Settings has one too.

## 7. Uninstall

From the PilotLight folder:

```bash
./Scripts/uninstall.sh
```

This removes the app, the command, the login item and the flag file, and
nothing else.
