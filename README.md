# Trading 212 for Rainmeter

A small Rainmeter skin that shows your Trading 212 account value in EUR and
how much it has changed today.

```
TRADING 212
€12,345.67
+€84.20   +0.69% today
Updated 14:32
```

## Requirements

- Windows with [Rainmeter](https://www.rainmeter.net/) 4.x
- A Trading 212 Invest or Stocks ISA account in EUR

## Install

1. Download `Installer/Trading212-1.0.rmskin` and double-click it.
2. In the Trading 212 app open **Settings → API →
   Generate key**. Turn on only the **Account data** permission. Copy the key
   and the secret; the secret is shown only once.
3. Right-click the skin, choose **Custom skin actions → Edit settings**, fill
   in `ApiKey` and `ApiSecret`, and save. The skin starts within 5 seconds.

Upgrading with a newer `.rmskin` keeps your key and secret.
`Settings.inc` is stored as plain text, so never share it.

## Settings

| Variable | Default | Meaning |
| --- | --- | --- |
| `ApiKey` / `ApiSecret` | empty | Trading 212 API credentials |
| `RefreshSeconds` | `60` | How often to poll the API. The limit is 1 request every 5 s, so keep this at 10 or more. |

Colours, fonts and layout are in `@Resources/Variables.inc`.

## How it works

The skin makes one call, `GET /api/v0/equity/account/summary`, using HTTP Basic
auth (`base64(key:secret)`), and displays `totalValue`. "Today" is measured
from the first value the skin reads each day, not from the market close.

Left-click the skin to refresh it now. Settings, refresh and reload are under right-click → **Custom skin actions**.

## Troubleshooting

| Message | Cause |
| --- | --- |
| `No API key / secret set` | A field in `Settings.inc` is empty. |
| `Key or secret rejected?` | The key or secret is wrong, it was created in Practice mode, or the Account data permission is off. |
| `Rate limited` | `RefreshSeconds` is too low, or something else is using the same key. |
| `Offline - showing last value` | No network connection. |

## Building

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

This writes `Installer\Trading212-<version>.rmskin`, taking the version and
author from `Portfolio.ini`. The build stops if `Settings.inc` contains
credentials.

## License

[GPL-3.0-or-later](LICENSE).
