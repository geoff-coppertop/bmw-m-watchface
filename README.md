# bmw-m-watchface

An analog BMW M Motorsport watch face for Garmin Connect IQ. Target device:
**Venu X1** (`venux1`).

## Wireframe

![Watch face wireframe](docs/wireframe.png)

Tap zones: yellow opens weather, red opens heart rate, blue opens the
activity rings page.

![Tap zones](docs/tap-zones.png)

These are mock-ups rendered from the same geometry the code uses, with example
values and the time set to 10:08:35. They are not simulator screenshots.

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
  BmwMWatchDelegate.mc  forwards taps to the view
resources/            strings and launcher icon
build.sh              compile to bin/bmw-m-watchface.prg
```

## Build

Needs the Connect IQ SDK (9.x), device files for `venux1`, and a developer
key. `build.sh` prints the `openssl` commands if `developer_key.der` is missing.

```sh
./build.sh            # builds for venux1
```

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
