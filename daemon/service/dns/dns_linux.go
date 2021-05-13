//
//  Daemon for IVPN Client Desktop
//  https://github.com/ivpn/desktop-app
//
//  Created by Stelnykovych Alexandr.
//  Copyright (c) 2020 Privatus Limited.
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

package dns

import (
	"fmt"
	"net"
	"os"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/ivpn/desktop-app-daemon/helpers"
)

var (
	resolvFile             string      = "/etc/resolv.conf"
	resolvBackupFile       string      = "/etc/resolv.conf.ivpnsave"
	defaultFilePermissions os.FileMode = 0644

	isPaused  bool   = false
	manualDNS net.IP = nil

	done chan struct{}
)

func init() {
	done = make(chan struct{})
}

// implInitialize doing initialization stuff (called on application start)
func implInitialize() error {
	// check if backup DNS file exists
	if _, err := os.Stat(resolvBackupFile); err != nil {
		// nothing to restore
		return nil
	}

	log.Info("Detected DNS configuration from the previous VPN connection. Restoring OS-default DNS values ...")
	// restore it
	if err := implDeleteManual(nil); err != nil {
		return fmt.Errorf("failed to restore DNS to default: %w", err)
	}

	return nil
}

func implPause() error {
	if isBackupExists(resolvBackupFile) == false {
		// The backup for the OS-defined configuration not exists.
		// It seems, we are not connected. Nothing to pause.
		return nil
	}

	// stop file change monitoring
	stopDNSChangeMonitoring()

	// restore original OS-default DNS configuration
	// (the backup file will not be deleted)
	isDeleteBackup := false // do not delete backup file
	ret := restoreBackup(resolvBackupFile, isDeleteBackup)

	isPaused = true
	return ret
}

func implResume(defaultDNS net.IP) error {
	isPaused = false

	if manualDNS != nil {
		// set manual DNS (if defined)
		return implSetManual(manualDNS, nil)
	}

	if defaultDNS != nil {
		return implSetManual(defaultDNS, nil)
	}

	return nil
}

// Set manual DNS.
// 'addr' parameter - DNS IP value
// 'localInterfaceIP' - not in use for Linux implementation
func implSetManual(addr net.IP, localInterfaceIP net.IP) error {
	if isPaused {
		// in case of PAUSED state -> just save manualDNS config
		// it will be applied on RESUME
		manualDNS = addr
		return nil
	}

	stopDNSChangeMonitoring()

	if addr == nil {
		return implDeleteManual(nil)
	}

	createBackupIfNotExists := func() (created bool, er error) {
		isOwerwriteIfExists := false
		return createBackup(resolvBackupFile, isOwerwriteIfExists)
	}

	saveNewConfig := func() error {
		createBackupIfNotExists()

		// create new configuration
		out, err := os.OpenFile(resolvFile, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, defaultFilePermissions)
		if err != nil {
			return fmt.Errorf("failed to update DNS configuration (%w)", err)
		}

		if _, err := out.WriteString(fmt.Sprintln(fmt.Sprintf("# resolv.conf autogenerated by '%s'\n\nnameserver %s", os.Args[0], addr.String()))); err != nil {
			return fmt.Errorf("failed to change DNS configuration: %w", err)
		}

		if err := out.Sync(); err != nil {
			return fmt.Errorf("failed to change DNS configuration: %w", err)
		}
		return nil
	}

	_, err := createBackupIfNotExists()
	if err != nil {
		return err
	}

	// Save new configuration
	if err := saveNewConfig(); err != nil {
		return err
	}

	manualDNS = addr

	// enable file change monitoring
	go func() {
		w, err := fsnotify.NewWatcher()
		if err != nil {
			log.Error(fmt.Errorf("failed to start DNS-change monitoring (fsnotify error): %w", err))
			return
		}

		log.Info("DNS-change monitoring started")
		defer func() {
			w.Close()
			log.Info("DNS-change monitoring stopped")
		}()

		for {
			// start watching file
			err = w.Add(resolvFile)
			if err != nil {
				log.Error(fmt.Errorf("failed to start DNS-change monitoring (fsnotify error): %w", err))
				return
			}

			// wait for changes
			var evt fsnotify.Event
			select {
			case evt = <-w.Events:
				break
			case <-done:
				// monitoring stopped
				return
			}

			//stop watching file
			if err := w.Remove(resolvFile); err != nil {
				log.Error(fmt.Errorf("failed to remove warcher (fsnotify error): %w", err))
			}

			// wait 2 seconds for reaction (in case if we are stopping of when multiple consecutive file changes)
			select {
			case <-time.After(time.Second * 2):
			case <-done:
				// monitoring stopped
				return
			}

			// restore DNS configuration
			log.Info(fmt.Sprintf("DNS-change monitoring: DNS was changed outside [%s]. Restoring ...", evt.Op.String()))
			if err := saveNewConfig(); err != nil {
				log.Error(err)
			}
		}
	}()

	return nil
}

// DeleteManual - reset manual DNS configuration to default
// 'localInterfaceIP' (obligatory only for Windows implementation) - local IP of VPN interface
func implDeleteManual(localInterfaceIP net.IP) error {
	if isPaused {
		// in case of PAUSED state -> just save manualDNS config
		// it will be applied on RESUME
		manualDNS = nil
		return nil
	}
	// stop file change monitoring
	stopDNSChangeMonitoring()
	isDeleteBackup := true // delete backup file
	return restoreBackup(resolvBackupFile, isDeleteBackup)
}

func stopDNSChangeMonitoring() {
	// stop file change monitoring
	select {
	case done <- struct{}{}:
		break
	default:
		break
	}
}

func isBackupExists(backupFName string) bool {
	_, err := os.Stat(backupFName)
	return err == nil
}

func createBackup(backupFName string, isOwerwriteIfExists bool) (created bool, er error) {
	if _, err := os.Stat(resolvFile); err != nil {
		// source file not exists
		return false, fmt.Errorf("failed to backup DNS configuration (file availability check failed): %w", err)
	}

	if _, err := os.Stat(backupFName); err == nil {
		// backup file already exists
		if isOwerwriteIfExists == false {
			return false, nil
		}
	}

	if err := os.Rename(resolvFile, backupFName); err != nil {
		return false, fmt.Errorf("failed to backup DNS configuration: %w", err)
	}
	return true, nil
}

func restoreBackup(backupFName string, isDeleteBackup bool) error {
	if _, err := os.Stat(backupFName); err != nil {
		// nothing to restore
		return nil
	}

	// restore original configuration
	if isDeleteBackup {
		if err := os.Rename(backupFName, resolvFile); err != nil {
			return fmt.Errorf("failed to restore DNS configuration: %w", err)
		}
	} else {
		tmpFName := resolvFile + ".tmp"
		if err := helpers.CopyFile(backupFName, tmpFName); err != nil {
			return fmt.Errorf("failed to restore DNS configuration: %w", err)
		}
		if err := os.Chmod(tmpFName, defaultFilePermissions); err != nil {
			return fmt.Errorf("failed to restore DNS configuration: %w", err)
		}
		if err := os.Rename(tmpFName, resolvFile); err != nil {
			return fmt.Errorf("failed to restore DNS configuration: %w", err)
		}
	}

	return nil
}
