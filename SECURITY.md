# CVEs

This project does not rebuild/release to "fix" CVEs which do not apply to actual builds of `gosu`.  For example, this includes any CVE in Go which applies to interfaces that `gosu` does not ever invoke, such as `net/http`, `archive/tar`, `encoding/xml`, etc.

Before reporting that `gosu` is "vulnerable" to a particular CVE, please run our [`./govulncheck-with-excludes.sh`](govulncheck-with-excludes.sh) wrapper around [`govulncheck`](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) to determine whether the latest release is *actually* using the vulnerable functionality.  See [this excellent blog post](https://go.dev/blog/vuln) from the Go team for more information about the `govulncheck` tool and the methodology by which it is maintained.

If you have a tool which is reporting that `gosu` is vulnerable to a particular CVE but `govulncheck` does not agree, **please** report this as a false positive to your CVE scanning vendor so that they can improve their tooling.  (If you wish to verify that your reported CVE is part of `govulncheck`'s dataset and thus covered by their tool, you can check [the vulndb repository](https://github.com/golang/vulndb) where they track those.)

Our `govulncheck` wrapper script ([`govulncheck-with-excludes.sh`](govulncheck-with-excludes.sh)) may include a small set of vulnerabilities that will be reported by `govulncheck` which do not apply (due to other mitigations or otherwise).  See comments in that script for details.

## Version Updates

Similar to the how traditional Linux distributions such as Debian handle rebuilding binaries between stable releases / for updated compilers (or rather, the situations and reasons for which they do *not* do so), and in the same spirit as the above CVE policy and [Go's "Minimal Version Selection"](https://research.swtch.com/vgo-mvs), we do *not* update the compiler/rebuild with a newer compiler unless there is a compelling functional or security reason in the code that ends up as part of the `gosu` binary that warrants doing so.

As above, if you have a "security scanning" tool which does not agree with this policy, please take that up with your scanning tool vendor (report as a false positive, improve the tool to use `govulncheck`, etc).

## See Also

- https://words.filippo.io/dependabot/

# Reporting Vulnerabilities

The surface area of `gosu` itself is really limited -- it only directly contains a small amount of Go code to instrument an interface that is part of [`github.com/moby/sys/user` (the Docker Engine's `--user` parsing code, to be exact)](https://github.com/moby/sys/tree/main/user) (and which itself is a pretty limited interface) intended for providing the same behavior as Docker's `--user` flag (switching from `root` to a less privileged user), but from within an already running container.

If you believe you have found a new vulnerability in `gosu`, chances are very high that it's actually a vulnerability in `github.com/moby/sys/user` or `golang.org/x/sys`, and should be [reported appropriately and responsibly](https://github.com/moby/moby/blob/HEAD/SECURITY.md).

After all this, if you still believe you have discovered a novel vulnerability in the limited code that is `gosu` itself, please [use GitHub's (private) advisory reporting feature](https://github.com/tianon/gosu/security/advisories/new) to responsibly report it.
