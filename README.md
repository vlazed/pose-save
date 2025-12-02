# Ragdoll Pose Save <!-- omit from toc -->

Preserve ragdoll poses when changing physics models between GMod saves

## Table of Contents <!-- omit from toc -->

- [Description](#description)
  - [Features](#features)
  - [Rational](#rational)
  - [Remarks](#remarks)
- [Disclaimer](#disclaimer)
- [Pull Requests](#pull-requests)
- [Credits](#credits)

## Description

This keeps ragdolls in the same pose when the user switches their ragdoll's physics models. This can be toggled via `ragdoll_pose_save` convar.

### Features

- **Save support**: This adds an additional entity modifier to save ragdoll poses only when the physics object count differs
  - Physics models with the same number of physics objects may produce subtle differences in pose

### Rational

One may want to take advantage of different physics overrides. The different TF2 physics overrides on the GMOd workshop helps illustrate the following case:

- An artist works with a set of TF2 ragdolls: `set T`.
- An artist finishes a save with different TF2 ragdolls with `physics model A`, which is applied on `set T`. They are all posed in a specific way, which I'll call `pose A`.
- The artist wants to use `physics model B`, which also replaces the physics of `set T`.
- They subscribe to `physics model B` and reload the save
- While all the save's ragdolls of `set T` have `physics model B`, their pose differs from the desired `pose A`. I'll call this different pose `pose B`

The goal is to achieve `pose A` from `physics model B`. This addon sets out to achieve that

### Remarks

WIP

## Disclaimer

**This tool has been tested in singleplayer.** Report any bugs that you observe in the issue tracker.

## Pull Requests

When making a pull request, make sure to confine to the style seen throughout. Try to add types for new functions or data structures. I used the default [StyLua](https://github.com/JohnnyMorganz/StyLua) formatting style.

## Credits

I reused code from my Ragdoll Puppeteer tool and my fork of Stop Motion Helper
