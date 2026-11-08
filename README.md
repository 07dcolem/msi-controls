# MSI Controls

Animated Omarchy bar panel for the [msi-ec](https://github.com/BeardOverflow/msi-ec) driver. It reads `/sys/devices/platform/msi-ec` and shows only the controls that driver exposes on the laptop in front of it.

<p>
  <a href="https://github.com/tcballard/omarchy-badges"><img alt="Built for Omarchy: Plugin" height="20" src="https://raw.githubusercontent.com/tcballard/omarchy-badges/75975e5b5bf75e7ede3764bcd2950046f7abfe2c/badges/v1/omarchy-plugin.svg"></a>
  <a href="LICENSE"><img alt="Licence: MIT" height="20" src="https://img.shields.io/badge/licence-MIT-blue"></a>
</p>

Source and issues: [github.com/07dcolem/msi-controls](https://github.com/07dcolem/msi-controls).

## Requirements

- Omarchy 4 with shell plugins. Checked on Omarchy 4.0.6.
- The `msi-ec` driver, checked at 0.13, on an MSI laptop that driver already recognizes.
- Your user in the `wheel` group, to change a setting. Reading works without it.

## What it controls

The panel is for MSI laptops whose embedded-controller firmware msi-ec already recognizes. It is not a control for every MSI machine, and it does not talk to the controller directly.

On a matched laptop the driver publishes a subset of these files. Missing files stay hidden:

- shift mode (`eco`, `comfort`, `sport`, `turbo`, or whatever `available_shift_modes` lists)
- fan mode (`auto`, `silent`, `basic`, `advanced`, from `available_fan_modes`)
- cooler boost
- CPU and GPU temperature, and fan speed as a percent of maximum
- charge end threshold, when the driver hooked the battery
- webcam and webcam block
- Fn and Win key swap
- super battery, on firmware that has it

Keyboard backlight, fan curves, raw EC registers, and Omarchy's own power profiles are out of scope. On the WS75 10TK firmware `17G3EWS1.113` the panel shows live temperatures and fan percents, fan mode, cooler boost, both camera switches, the Fn key, and the charge limit. Cooler boost runs the fans up. Shift is shown as a stored value: storing it does not change the CPU power cap. The panel says so for that firmware, and it does not write settings to discover this. Super battery is not in that map. Shift can read `unspecified` until a listed mode is chosen.

Setting a charge limit writes `charge_control_end_threshold`. This driver cannot turn that limit back off. While no limit is set, the battery row says "No limit" and the slider is labeled as a draft. The panel says a limit stays on before the first apply, and it will not write `0`.

## Install

`omarchy plugin add` clones this repository, validates it, and copies it into `~/.config/omarchy/plugins/`. Review the code before you enable it. Plugins run as unsandboxed code inside `omarchy-shell`.

```bash
omarchy plugin add https://github.com/07dcolem/msi-controls.git
omarchy plugin enable io.github.07dcolem.msi-controls --section right --before omarchy.power
```

From a local checkout of this repository:

```bash
omarchy plugin add "$(pwd)"
omarchy plugin enable io.github.07dcolem.msi-controls --section right --before omarchy.power
```

The widget can read sysfs as your user. Writes are mode `0660` and group `wheel`, applied by a root-owned copy of `bin/grant`. The plugin never runs `sudo` itself. Install the grant once, from the copy `omarchy plugin add` just placed:

```bash
plugin="$HOME/.config/omarchy/plugins/io.github.07dcolem.msi-controls"
sudo install -d -o root -g root -m 0755 /usr/local/libexec/io.github.07dcolem.msi-controls
sudo install -o root -g root -m 0755 "$plugin/bin/grant" /usr/local/libexec/io.github.07dcolem.msi-controls/grant
echo 'ACTION=="add", SUBSYSTEM=="platform", KERNEL=="msi-ec", RUN+="/usr/local/libexec/io.github.07dcolem.msi-controls/grant"' | sudo tee /etc/udev/rules.d/70-msi-controls.rules
sudo /usr/local/libexec/io.github.07dcolem.msi-controls/grant
```

Log in again if `wheel` was added in this session. The panel says it is read only until that grant is in place.

## Use

The bar button opens a keyboard panel: arrows move, Enter applies, Escape closes. Right-click the bar icon to stop its fan. Right-click again to start it. That choice is stored on the bar entry in `shell.json` (`barFanSpin`).

## Update

```bash
omarchy plugin update io.github.07dcolem.msi-controls
```

That updates the plugin checkout only. The root-owned grant is a separate file. When `bin/grant` changes, install that file again with the `sudo install` command above.

## Removing

```bash
omarchy plugin remove io.github.07dcolem.msi-controls
```

That removes the shell plugin. It leaves these root-owned files in place, because they are outside the plugin directory:

- `/usr/local/libexec/io.github.07dcolem.msi-controls/grant`
- `/etc/udev/rules.d/70-msi-controls.rules`

Delete those two paths yourself if you also want the write grant gone. Reloading the `msi-ec` module restores the original root-only permissions on the sysfs files. The plugin writes no cache or credential. The only preference it stores is the bar-icon fan, through the shell's own bar entry. A charge limit already stored in the controller stays there.

## Security

Read `bin/grant` before you install it. It is a root program, started by udev, and its only job is to give group `wheel` write access on the msi-ec files listed in that script. The panel itself does not raise privileges. It has no network access and stores no account or token.

Report a vulnerability or a broken control as a [GitHub issue](https://github.com/07dcolem/msi-controls/issues).

## Licence

[MIT](LICENSE) © 2026 Dylan Coleman
