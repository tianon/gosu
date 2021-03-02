[![GitHub release](https://img.shields.io/github/release/tianon/gosu.svg?style=flat-square)](https://github.com/tianon/gosu/releases/latest)
[![Total downloads](https://img.shields.io/github/downloads/tianon/gosu/total.svg?style=flat-square)](https://github.com/tianon/gosu/releases/latest)
[![Build Status](https://img.shields.io/github/workflow/status/tianon/gosu/build?label=build&logo=github&style=flat-square)](https://github.com/tianon/gosu/actions?query=workflow%3Abuild)
[![Docker Stars](https://img.shields.io/docker/stars/tianon/gosu.svg?style=flat-square&logo=docker)](https://hub.docker.com/r/tianon/gosu/)
[![Docker Pulls](https://img.shields.io/docker/pulls/tianon/gosu.svg?style=flat-square&logo=docker)](https://hub.docker.com/r/tianon/gosu/)
[![Go Report Card](https://goreportcard.com/badge/github.com/tianon/gosu)](https://goreportcard.com/report/github.com/tianon/gosu)

___

* [About](#about)
* [Warning](#warning)
* [Installation](#installation)
  * [From binary](#from-binary)
  * [From Dockerfile](#from-dockerfile)
* [Build](#build)
* [Why?](#why)
* [Alternatives](#alternatives)
  * [`su-exec`](#su-exec)
  * [`chroot`](#chroot)
  * [`setpriv`](#setpriv)
  * [Others](#others)

# About

This is a simple tool grown out of the simple fact that `su` and `sudo` have very strange and often annoying TTY and
signal-forwarding behavior.  They're also somewhat complex to setup and use (especially in the case of `sudo`), which
allows for a great deal of expressivity, but falls flat if all you need is "run this specific application as this
specific user and get out of the pipeline".

The core of how `gosu` works is stolen directly from how Docker/libcontainer itself starts an application inside a
container (and in fact, is using the `/etc/passwd` processing code directly from libcontainer's codebase).

```shell
$ gosu
Usage: ./gosu user-spec command [args]
   eg: ./gosu tianon bash
       ./gosu nobody:root bash -c 'whoami && id'
       ./gosu 1000:1 id

./gosu version: 1.1 (go1.3.1 on linux/amd64; gc)
```

Once the user/group is processed, we switch to that user, then we `exec` the specified process and `gosu` itself is no
longer resident or involved in the process lifecycle at all.  This avoids all the issues of signal passing and TTY,
and punts them to the process invoking `gosu` and the process being invoked by `gosu`, where they belong.

## Warning

The core use case for `gosu` is to step _down_ from `root` to a non-privileged user during container startup
(specifically in the `ENTRYPOINT`, usually).

Uses of `gosu` beyond that could very well suffer from vulnerabilities such as CVE-2016-2779 (from which the Docker
use case naturally shields us); see [`tianon/gosu#37`](https://github.com/tianon/gosu/issues/37) for some discussion
around this point.

## Installation

### From binary

`gosu` binaries are available on [releases page](https://github.com/tianon/gosu/releases/latest).

Choose the archive matching the destination platform:

```shell
wget -qO- https://github.com/tianon/gosu/releases/download/v1.13.0/gosu_1.13.0_linux_x86_64.tar.gz | tar -zxvf - gosu
```

### From Dockerfile

| Registry                                                                                         | Image                           |
|--------------------------------------------------------------------------------------------------|---------------------------------|
| [Docker Hub](https://hub.docker.com/r/tianon/gosu/)                                              | `tianon/gosu`                   |
| [GitHub Container Registry](https://github.com/users/tianon/packages/container/package/gosu)     | `ghcr.io/tianon/gosu`           |

Here is how to use `gosu` inside your Dockerfile:

```Dockerfile
ARG GOSU_VERSION=1.13.0

FROM alpine
ARG GOSU_VERSION
COPY --from=tianon/gosu:${GOSU_VERSION} / /
RUN gosu --version
RUN gosu nobody true
```

As the [Docker image](https://hub.docker.com/r/tianon/gosu/) is multi-platform with
[BuildKit](https://github.com/moby/buildkit) you can also use `gosu` through the
[automatic platform ARGs in the global scope](https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope):

```Dockerfile
ARG GOSU_VERSION=1.13.0

FROM --platform=${TARGETPLATFORM:-linux/amd64} alpine
ARG GOSU_VERSION
COPY --from=tianon/gosu:${GOSU_VERSION} / /
RUN gosu --version
RUN gosu nobody true
```

## Build

You only need Docker to build `gosu`:

```shell
git clone https://github.com/tianon/gosu.git gosu
cd gosu

# validate (lint, vendors)
docker buildx bake validate

# test (test-alpine and test-debian bake targets)
docker buildx bake test

# build docker image and output to docker with gosu:local tag (default)
docker buildx bake

# build multi-platform image
docker buildx bake image-all

# create artifacts in ./dist
docker buildx bake artifact-all
```

## Why?

```shell
$ docker run -it --rm ubuntu:trusty su -c 'exec ps aux'
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0  46636  2688 ?        Ss+  02:22   0:00 su -c exec ps a
root         6  0.0  0.0  15576  2220 ?        Rs   02:22   0:00 ps aux
$ docker run -it --rm ubuntu:trusty sudo ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  3.0  0.0  46020  3144 ?        Ss+  02:22   0:00 sudo ps aux
root         7  0.0  0.0  15576  2172 ?        R+   02:22   0:00 ps aux
$ docker run -it --rm -v $PWD/gosu-amd64:/usr/local/bin/gosu:ro ubuntu:trusty gosu root ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0   7140   768 ?        Rs+  02:22   0:00 ps aux
```

Additionally, due to the fact that `gosu` is using Docker's own code for processing these `user:group`, it has
exact 1:1 parity with Docker's own `--user` flag.

If you're curious about the edge cases that `gosu` handles, see [`Dockerfile.test`](Dockerfile.test) for the
"test suite" (and the associated [`test.sh`](test.sh) script that wraps this up for testing arbitrary binaries).

(Note that `sudo` has different goals from this project, and it is *not* intended to be a `sudo` replacement;
for example, see [this Stack Overflow answer](https://stackoverflow.com/a/48105623) for a short explanation of
why `sudo` does `fork`+`exec` instead of just `exec`.)

## Alternatives

### `su-exec`

As mentioned in `INSTALL.md`, [`su-exec`](https://github.com/ncopa/su-exec) is a very minimal re-write of `gosu` in C,
making for a much smaller binary, and is available in the `main` Alpine package repository.

### `chroot`

With the `--userspec` flag, `chroot` can provide similar benefits/behavior:

```shell
$ docker run -it --rm ubuntu:trusty chroot --userspec=nobody / ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
nobody       1  5.0  0.0   7136   756 ?        Rs+  17:04   0:00 ps aux
```

### `setpriv`

Available in newer `util-linux` (`>= 2.32.1-0.2`, in Debian; https://manpages.debian.org/buster/util-linux/setpriv.1.en.html):

```shell
$ docker run -it --rm buildpack-deps:buster-scm setpriv --reuid=nobody --regid=nogroup --init-groups ps faux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
nobody       1  5.0  0.0   9592  1252 pts/0    RNs+ 23:21   0:00 ps faux
```

### Others

I'm not terribly familiar with them, but a few other alternatives I'm aware of include:

* `chpst` (part of `runit`)
