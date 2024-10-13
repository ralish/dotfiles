Load order
==========

Settings are loaded in the order they're returned when enumerating the directory. This is expected to be lexical order, and so settings are prefixed with a two digit integer to configure when they're loaded relative to other settings. A set of categories are also defined, each allocated a range, so that settings of the same general type are grouped together and loaded at the same time.

| Range     | Category                                                          |
| --------- | ----------------------------------------------------------------- |
| `0 - 4`   | Settings for loading dotfiles themselves                          |
| `5 - 9`   | Global or "meta" settings which may impact subsequent settings    |
| `10 - 19` | Operating system settings                                         |
| `20 - 29` | Console or terminal settings                                      |
| `30 - 39` | PowerShell customisation (e.g. prompt enhancements)               |
| `40 - 49` | Miscellaneous console, terminal, or PowerShell settings           |
| `50 - 54` | Microsoft modules settings (local)                                |
| `55 - 59` | Microsoft modules settings (cloud)                                |
| `60 - 64` | 3rd-party modules settings (local)                                |
| `65 - 69` | 3rd-party modules settings (cloud)                                |
| `70 - 74` | Microsoft software settings (local)                               |
| `75 - 79` | Microsoft software settings (cloud)                               |
| `80 - 84` | 3rd-party software settings (local)                               |
| `85 - 89` | 3rd-party software settings (cloud)                               |
| `90 - 94` | Late PowerShell settings                                          |
| `95 - 99` | Late environment settings                                         |
