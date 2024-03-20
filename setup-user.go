package main

import (
	"os"

	"github.com/moby/sys/user"
	"golang.org/x/sys/unix"
)

// this function comes from https://github.com/opencontainers/runc/blob/18c313be729dd02b17934af41e32116a28b4b3bf/libcontainer/init_linux.go#L472-L561
// we don't use that directly because it isn't exported *and* we don't want that whole package/runc imported here
// (also, because we need minor modifications)

// SetupUser changes the groups, gid, and uid for the user inside the container
func SetupUser(u string) error {
	// Set up defaults.
	defaultExecUser := user.ExecUser{
		Uid:  unix.Getuid(),
		Gid:  unix.Getgid(),
		Home: "/",
	}
	passwdPath, err := user.GetPasswdPath()
	if err != nil {
		return err
	}
	groupPath, err := user.GetGroupPath()
	if err != nil {
		return err
	}
	execUser, err := user.GetExecUserPath(u, &defaultExecUser, passwdPath, groupPath)
	if err != nil {
		return err
	}
	if err := unix.Setgroups(execUser.Sgids); err != nil {
		return err
	}
	if err := unix.Setgid(execUser.Gid); err != nil {
		return err
	}
	if err := unix.Setuid(execUser.Uid); err != nil {
		return err
	}
	// if we didn't get HOME already, set it based on the user's HOME
	if envHome := os.Getenv("HOME"); envHome == "" {
		if err := os.Setenv("HOME", execUser.Home); err != nil {
			return err
		}
	}
	return nil
}
