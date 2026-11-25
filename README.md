# bmw-m-watchface

An analog BMW M Motorsport watch face for Garmin Connect IQ. Target device:
**Venu X1** (`venux1`).

## Wireframe

![Watch face wireframe](docs/wireframe.png)

Tap zones: yellow opens weather, red opens heart rate, blue opens the
activity rings page.

![Tap zones](docs/tap-zones.png)

Tap pages (activity rings, a metric page, weather):

![Tap pages](docs/pages.png)

These are mock-ups with example values and the time set to 10:08:35. They are not
simulator screenshots. They are generated from `source/Theme.mc` by
`docs/wireframes.py`, so they follow the theme. Layout that lives in the Monkey C
files is mirrored in the script and has to be kept in sync by hand. Regenerate
with:

```sh
python3 docs/wireframes.py /tmp/wf   # writes dial.svg, tap-zones.svg, pages.svg
```

then convert the SVGs to PNG with any renderer (these were done with headless
Chromium).

## Features

- Analog chronograph dial with a white-sword hand set, a red second hand
  (hidden in low-power mode) and a roundel at the hand pivot.
- M badge at 12 o'clock, drawn from the flat M logo's geometry.
- Three activity rings inside the lower dial, in the badge colours:
  steps (blue), weekly active minutes (navy) and body battery (red).
- Top row with date, current temperature and watch battery.
- Tap pages (full screen, tap again or wait 20 s to return):
  - ring band: steps, active minutes and body battery together
  - roundel: heart rate (resting, today's low and high)
  - top row: weather (conditions, feels-like, high/low, rain chance, wind,
    humidity, next four hours)

## Layout

```
manifest.xml          app id, target product, permissions
monkey.jungle         build configuration
source/
  BmwMWatchApp.mc       app entry
  BmwMWatchView.mc      dial, rings, hands, roundel, tap hit-testing
  BmwMDetail.mc         tap detail pages
  Theme.mc              colours, spacing and font roles used everywhere
  BmwMWatchDelegate.mc  forwards taps to the view
resources/            strings and launcher icon
build.sh              compile to bin/bmw-m-watchface.prg
.devcontainer/        devcontainer + post-create (SDK from a shared feature)
.vscode/tasks.json    build task
```

## Design tokens

Everything visual comes from `source/Theme.mc`, so a change there changes the
whole face.

- **Colours:** the logo's blue `0066B1`, navy `003C78` and red `E32618`, a dark
  tint of each for empty tracks, white, and three greys (light, mid, dark). One
  deliberate exception: `NAVY_LIGHT` `4A90D9`, a lighter blue for the
  active-minutes bolt, because navy is nearly invisible as a small glyph on black.
- **Spacing:** one 2 px gap is used between the badge stripes, between ring bars
  and between the outer ring and the ticks. Ring bars are as wide as the badge
  stripes. Detail pages share a 70 px margin, a 32 px row pitch and one bar size.
- **Fonts:** four roles mapped to Garmin system fonts: label, value, title and
  hero number.

The weather page's headline and hourly strip use a few one-off vertical
positions of their own. They are not in `Theme.mc`.

## Build

### In the devcontainer (recommended)

Open the repo in VS Code ("Reopen in Container") or a Codespace. The container
installs the Connect IQ SDK 9.2.0 and generates a local signing key
(`developer_key.der`, git-ignored). Downloading the Venu X1 device files needs a
Garmin account, so export these on the host before opening the container (or
set them as Codespaces/repo secrets):

```sh
export GARMIN_USERNAME="you@example.com"
export GARMIN_PASSWORD="..."
```

Accounts with two-factor auth may not work non-interactively. If login fails,
run `connect-iq-sdk-manager login` once inside the container, then
`connect-iq-sdk-manager device download --manifest manifest.xml`.

Then build:

```sh
./build.sh            # builds bin/bmw-m-watchface.prg for venux1
./build.sh <device>   # another product id listed in manifest.xml
```

or run the **Build (venux1)** task in VS Code (`Ctrl/Cmd+Shift+B`).

The container's `runArgs` has `--userns=keep-id` for rootless Podman. Docker
rejects that flag, so remove it (or use `--userns=host`) if you use Docker.

### Without the devcontainer

Install the Connect IQ SDK 9.x and the `venux1` device files yourself, generate a
developer key (`build.sh` prints the `openssl` commands), then run `./build.sh`.

### Running it

`build.sh` only compiles. To see the face you need the Connect IQ simulator
(`connectiq` + `monkeydo`), a GUI tool that isn't available in a headless
container. Use it on a desktop SDK install, or sideload the `.prg` to the watch.

## Status

Written without access to the Connect IQ SDK, so **it has not been compiled or
run yet**. Expect a few compile fixes on the first build. In particular:

- `WatchFaceDelegate.onPress` is used for taps; confirm it fires on the Venu X1.
- Weather `CONDITION_*` names in `BmwMDetail.mc` should be checked against the SDK.
- Layout positions come from a wireframe, not the simulator.

## Trademarks

BMW, the BMW roundel and the BMW M logo are trademarks of BMW AG. The badge and
roundel here are stylised redraws for personal use and are not endorsed by BMW.
Do not publish this face to the Connect IQ store with them.
