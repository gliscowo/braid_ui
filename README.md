<h1 align="center">
<picture>
    <source media="(prefers-color-scheme: dark)" srcset="web_assets/logo_text_dark.png">
    <img alt="braid-ui" src="web_assets/logo_text_light.png">
</picture>
</h1>

braid is a modern, declarative desktop UI framework (currently supporting Windows 10/11 and Linux) written in [Dart](https://dart.dev). Its core concepts are strongly inspired by frameworks like [React](https://react.dev) and especially [Flutter](https://flutter.dev).

> [!NOTE]
> braid is currently in early development, highly experimental and has no stable API.

This repository contains the reference implementation, the Minecraft-specific implementation (written in Java and likely more stable) can, for now, be found in the `braid-ui` branch of the [owo-lib repository](https://github.com/wisp-forest/owo-lib).

<p align="center">
<picture>
    <source media="(prefers-color-scheme: dark)" srcset="web_assets/app_preview_dark.png">
    <img alt="an example braid app" src="web_assets/app_preview_light.png">
</picture>
</p>

## Setup

Add a `git` dependency on braid to your pubspec:
```yaml
dependencies:
  braid_ui:
    git:
      url: https://github.com/gliscowo/braid_ui
      ref: main # ideally, replace this with a concrete commit or tag reference
```