# dsh-desktop

Run the **DeepSeek Harness** Web GUI as a real desktop app — its own window, its own icon, one click.

`dsh --profile web` is a server. It prints a tokenised URL and hands it to your default browser, so the GUI becomes a tab in whatever browser you were already using: the window belongs to that browser, and the DeepSeek launcher stays an icon with no window. This tool fixes all of it:

- **own chromeless window** (`--app=`) on a private browser profile, so DSH tabs never mix with your everyday browsing;
- **detached server** that survives closing the terminal and the window;
- **correct desktop attribution**, so the window sits under the DeepSeek icon instead of the browser's;
- **idempotent**: click again and the existing window is reused.

## Install

```bash
git clone https://github.com/zareismail/dsh-desktop.git
cd dsh-desktop
./install.sh
```

Nothing is compiled and no root is needed. It installs three things under your home directory and pins the entry to the GNOME dock.

```bash
./install.sh --no-pin           # skip the dock pin
./install.sh --port 8080        # default port 3080
./bin/dsh-desktop doctor        # prove the attribution is correct
```

Requirements: `bash`, `curl`, the `dsh` CLI (or `npx @deepseek-ai/dsh`), and a Chromium-family browser — Flatpak **or** distro package. `flatpak`, `ss`/`fuser`/`lsof`, `xprop` and `gsettings` are used when present.

## Commands

| command | what it does |
|---|---|
| `dsh-desktop run` | start/reuse the server, open the app window |
| `dsh-desktop install` | install launcher, icon and desktop entry |
| `dsh-desktop uninstall` | remove them and stop the detached server |
| `dsh-desktop doctor` | check that the window will get the DeepSeek icon |
| `dsh-desktop status` | server, port, state directory |

## Why the icon is the hard part

You can pass `--class=dsh-web-app` and set `StartupWMClass=dsh-web-app`, and GNOME will still group the window under Chrome. The reason is a gate in `shell-window-tracker.c`:

```c
sandbox_id = meta_window_get_sandboxed_app_id (window);     /* com.google.Chrome */
if (sandbox_id)
  app_prefix = g_strdup_printf ("%s.", sandbox_id);
...
if (app != NULL && check_app_id_prefix (app, app_prefix))
  return app;
```

For a **sandboxed** window every candidate desktop entry is rejected unless its *desktop id* starts with the sandbox id. `dsh-web-app.desktop` does not, so the `WM_CLASS` match is thrown away and the window falls through to the sandbox id — Chrome. The fix is to name the entry after the browser's id:

| browser | entry id that resolves |
|---|---|
| Flatpak Chrome | `com.google.Chrome.dsh-web-app.desktop` |
| Flatpak Chromium | `org.chromium.Chromium.dsh-web-app.desktop` |
| Flatpak Brave | `com.brave.Browser.dsh-web-app.desktop` |
| distro `.deb`/`.rpm` Chrome, Chromium, Edge | `dsh-web-app.desktop` |

`install` detects the browser and derives the id — that's the whole trick, and it's why this repo is not tied to one machine.

Two consequences worth knowing:

- **Only one entry may claim the class.** GNOME prefers a desktop id that equals the class exactly, so a leftover `dsh-web-app.desktop` would beat the prefixed entry and silently restore the browser icon. `install` deletes the other variants; `doctor` fails if two exist.
- **Wayland-only sessions have no `WM_CLASS`.** The launcher forces `--ozone-platform=x11` (XWayland) so `--class` is honoured. Set `DSH_DESKTOP_X11=0` to disable that.

## Portability notes

- **GNOME / Ubuntu Dock / Dash to Dock**: fully supported, including the sandbox rule above.
- **KDE, XFCE, Cinnamon**: they group by `WM_CLASS`/`StartupWMClass` without the sandbox gate, so the generated entry works there too; `doctor` warns when it cannot inspect windows.
- **Browser later changes** (e.g. you install Chrome as a Flatpak after using the `.deb`): re-run `./install.sh`, which rewrites the entry id.
- **Servers that belong to a terminal**: by default the launcher leaves them alone. `DSH_DESKTOP_TAKEOVER=1 dsh-desktop run` replaces them with the detached one.

## Troubleshooting

| symptom | cause / fix |
|---|---|
| still grouped under the browser | the window predates the entry — close it and click the icon again; GNOME caches the mapping per window |
| appears twice in the dock | two entries claim the class: `dsh-desktop doctor`, then `install` |
| opens a normal browser tab | no Chromium-family browser found, or `DSH_DESKTOP_BROWSER=xdg` |
| `dsh not found` on click | the desktop session has a minimal `PATH`; the launcher adds `~/.local/bin` and every nvm node; otherwise put `dsh` on `PATH` |
| window dies when the terminal closes | the server was not detached; `DSH_DESKTOP_TAKEOVER=1` |

## What it touches

```
~/.local/bin/dsh-desktop
~/.local/share/applications/<id>.desktop
~/.local/share/icons/hicolor/scalable/apps/deepseek-harness.svg
~/.local/state/dsh-web-app/          # token url, server pid, log, browser profile
~/.var/app/<browser-id>/dsh-desktop-profile/   # Flatpak private profile
```

`./uninstall.sh` removes the installed files and stops the detached server; the state directory is left behind on purpose.

## License

MIT
