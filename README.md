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

If you're curious about the edge cases that `gosu` handles, see [`Dockerfile.test`](Dockerfile.test) for the "test suite" (and the associated [`test.sh`](test.sh) script that wraps this up for testing arbitrary binaries)
