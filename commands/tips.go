package commands

import (
	"fmt"
	"os"
	"path/filepath"
	"text/tabwriter"
)

type TipType uint

const (
	TipHelp            TipType = iota
	TipHelpFull        TipType = iota
	TipHelpCommand     TipType = iota
	TipLogout          TipType = iota
	TipLogin           TipType = iota
	TipForceLogin      TipType = iota
	TipServers         TipType = iota
	TipConnectHelp     TipType = iota
	TipDisconnect      TipType = iota
	TipFirewallDisable TipType = iota
	TipFirewallEnable  TipType = iota
	TipLastConnection  TipType = iota
)

func PrintTips(tips []TipType) {
	if len(tips) == 0 {
		return
	}

	writer := tabwriter.NewWriter(os.Stdout, 0, 0, 1, ' ', 0)

	fmt.Println("")
	fmt.Fprintln(writer, "Tips:")
	for _, t := range tips {
		PrintTip(writer, t)
	}

	writer.Flush()
	fmt.Println("")
}

func PrintTip(w *tabwriter.Writer, tip TipType) {

	str := ""
	switch tip {
	case TipHelp:
		str = newTip("-h", "Show all commands")
		break
	case TipHelpFull:
		str = newTip("-h -full", "Show detailed description about all commands")
		break
	case TipHelpCommand:
		str = newTip("COMMAND -h", "Show detailed description of command")
		break
	case TipLogout:
		str = newTip("logout", "Logout from this device")
		break
	case TipLogin:
		str = newTip("login ACCOUNT_ID", "Log in with your Account ID")
		break
	case TipForceLogin:
		str = newTip("login -force ACCOUNT_ID", "Log in with your Account ID and logout from all other devices")
		break
	case TipServers:
		str = newTip("servers", "Show servers list")
		break
	case TipConnectHelp:
		str = newTip("connect -h", "Show usage of 'connect' command")
		break
	case TipDisconnect:
		str = newTip("disconnect", "Stop current VPN connection")
		break
	case TipFirewallDisable:
		str = newTip("firewall -off", "Disable firewall (to allow connectivity outside VPN)")
		break
	case TipFirewallEnable:
		str = newTip("firewall -on", "Enable firewall (to block all connectivity outside VPN)")
		break
	case TipLastConnection:
		str = newTip("connect -last", "Connect with last successful connection parameters")
		break
	}

	if len(str) > 0 {
		fmt.Fprintln(w, str)
	}
}

func newTip(command string, description string) string {
	return fmt.Sprintf("\t%s %s\t        %s", filepath.Base(os.Args[0]), command, description)
}
