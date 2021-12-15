//
//  Daemon for IVPN Client Desktop
//  https://github.com/ivpn/desktop-app
//
//  Created by Stelnykovych Alexandr.
//  Copyright (c) 2021 Privatus Limited.
//
//  This file is part of the Daemon for IVPN Client Desktop.
//
//  The Daemon for IVPN Client Desktop is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The Daemon for IVPN Client Desktop is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License
//  along with the Daemon for IVPN Client Desktop. If not, see <https://www.gnu.org/licenses/>.
//

package splittun

import (
	"fmt"
	"net"
	"sync"

	"github.com/ivpn/desktop-app/daemon/logger"
)

var log *logger.Logger

func init() {
	log = logger.NewLogger("spltun")
}

var (
	mutex sync.Mutex
)

type ConfigAddresses struct {
	IPv4Public net.IP // OutboundIPv4
	IPv4Tunnel net.IP // VpnLocalIPv4
	IPv6Public net.IP // OutboundIPv6
	IPv6Tunnel net.IP // VpnLocalIPv6
}

// Information about running application
// https://man7.org/linux/man-pages/man5/proc.5.html
type RunningApp struct {
	Pid     int
	Ppid    int // The PID of the parent of this process.
	Pgrp    int // The process group ID of the process.
	Session int // The session ID of the process.
	Cmdline string
	Exe     string // The actual pathname of the executed command
}

// Initialize must be called first (before accessing any ST functionality)
// Normally, it should check if the ST functionality available
// Returns non-nil error object if Split-Tunneling functionality not available
func Initialize() error {
	mutex.Lock()
	defer mutex.Unlock()

	log.Info("Initializing Split-Tunnelling")
	err := implInitialize()
	if err != nil {
		return err
	}

	return nil
}

// IsFuncNotAvailableError returns non-nil error object if Split-Tunneling functionality not available
// The return value is the same as Initialize()
func GetFuncNotAvailableError() error {
	return implFuncNotAvailableError()
}

// ApplyConfig control split-tunnel functionality
func ApplyConfig(isStEnabled bool, isVpnEnabled bool, addrConfig ConfigAddresses, splitTunnelApps []string) error {
	mutex.Lock()
	defer mutex.Unlock()

	if !isVpnEnabled {
		addrConfig.IPv4Tunnel = nil
		addrConfig.IPv6Tunnel = nil
	}

	return implApplyConfig(isStEnabled, isVpnEnabled, addrConfig, splitTunnelApps)
}

// AddPid adds process to Split-Tunnel environment
// (applicable for Linux)
func AddPid(pid int, commandToExecute string) error {
	log.Info(fmt.Sprintf("Adding PID:%d", pid))
	return implAddPid(pid, commandToExecute)
}

// Get information about active applications running in Split-Tunnel environement
// (applicable for Linux)
func GetRunningApps() ([]RunningApp, error) {
	return implGetRunningApps()
}
