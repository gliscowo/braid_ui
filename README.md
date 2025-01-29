<h1 align="center">
<picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo_text_dark.png">
    <img alt="braid-ui" src="assets/logo_text_light.png">
</picture>
</h1>

braid is an experimental, retained-mode desktop UI framework (currently supporting Windows 10/11 and Linux) written in [Dart](https://dart.dev). It is primarily being developed as a testing ground for an eventual replacement of [owo-lib](https://github.com/wisp-forest/owo-lib)'s owo-ui framework, but standalone use will be possible and this implementation will always serve as the primary one where development efforts are focused.

## Setup

Add a `git` dependency on braid to your pubspec:
```yaml
...
dependencies:
  braid_ui:
    git:
      url: https://github.com/gliscowo/braid_ui
      ref: main # ideally, replace this with a concrete commit or tag reference
...
```

Then, after running the usual `dart pub get`, use braid's `setup_natives` utility for downloading the native libraries required for braid to run:

```
$ dart run braid_ui:install_natives resources/lib
Building package executable... 
Built braid_ui:install_natives.

installing natives into: resources/lib
downloading...
extracting...
success
```
