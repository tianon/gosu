# gosu

[![Build Status](https://travis-ci.org/tianon/gosu.svg)](https://travis-ci.org/tianon/gosu)

This is a simple tool grown out of the simple fact that `su` and `sudo` have very strange and often annoying TTY and signal-forwarding behavior.  They're also somewhat complex to setup and use (especially in the case of `sudo`), which allows for a great deal of expressivity, but falls flat if all you need is "run this specific application as this specific user and get out of the pipeline".

The core of how `gosu` works is stolen directly from how Docker/libcontainer itself starts an application inside a container (and in fact, is using the `/etc/passwd` processing code directly from libcontainer's codebase).

```console
$ gosu
Usage: ./gosu user-spec command [args]
   ie: ./gosu tianon bash
       ./gosu nobody:root bash -c 'whoami && id'
       ./gosu 1000:1 id

./gosu version: 1.1 (go1.3.1 on linux/amd64; gc)
```

Once the user/group is processed, we switch to that user, then we `exec` the specified process and `gosu` itself is no longer resident or involved in the process lifecycle at all.  This avoids all the issues of signal passing and TTY, and punts them to the process invoking `gosu` and the process being invoked by `gosu`, where they belong.

## Warning

The core use case for `gosu` is to step _down_ from `root` to a non-privilged user during container startup (specifically in the `ENTRYPOINT`, usually).

Uses of `gosu` beyond that could very well suffer from vulnerabilities such as CVE-2016-2779 (from which the Docker use case naturally shields us); see [`tianon/gosu#37`](https://github.com/tianon/gosu/issues/37) for some discussion around this point.

## Installation

High-level steps:

1. download `gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }')` as `gosu`
2. download `gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }').asc` as `gosu.asc`
3. fetch my public key (to verify your download): `gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4`
4. `gpg --batch --verify gosu.asc gosu`
5. `chmod +x gosu`

For explicit `Dockerfile` instructions, see [`INSTALL.md`](INSTALL.md).

## Why?

```console
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

Additionally, due to the fact that `gosu` is using Docker's own code for processing these `user:group`, it has exact 1:1 parity with Docker's own `--user` flag.

If you're curious about the edge cases that `gosu` handles, see [`Dockerfile.test`](Dockerfile.test) for the "test suite" (and the associated [`test.sh`](test.sh) script that wraps this up for testing arbitrary binaries).

## Alternatives

### `su-exec`

As mentioned in `INSTALL.md`, [`su-exec`](https://github.com/ncopa/su-exec) is a very minimal re-write of `gosu` in C, making for a much smaller binary, and is available in the `main` Alpine package repository.

### `chroot`

With the `--userspec` flag, `chroot` can provide similar benefits/behavior:

```console
$ docker run -it --rm ubuntu:trusty chroot --userspec=nobody / ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
nobody       1  5.0  0.0   7136   756 ?        Rs+  17:04   0:00 ps aux
```

### Others

I'm not terribly familiar with them, but a few other alternatives I'm aware of include:

- `chpst` (part of `runit`)
