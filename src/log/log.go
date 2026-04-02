package log

import "fmt"

const (
	BlueConsoleColorChar  = "\033[34m"
	RedConsoleColorChar   = "\033[31m"
	ResetConsoleColorChar = "\033[0m"
)

// PrintStep print yello info with indent
func PrintStep(msg string, indent int) {
	fmt.Println(BlueConsoleColorChar + prefix(indent) + " => " + msg + ResetConsoleColorChar)
}

// OpenProcess print yello info with indent
func OpenProcess(msg string, indent int) {
	fmt.Println(prefix(indent) + "[*] " + msg)
}

// EndProcess print yello info with indent
func EndProcess(msg string, indent int) {
	fmt.Println(BlueConsoleColorChar + prefix(indent) + ResetConsoleColorChar + "[*] " + msg)
}

// FailProcess print red info with indent, indent is optional, default is 0
func FailProcess(msg string, indent int) {
	fmt.Println(BlueConsoleColorChar + prefix(indent) + RedConsoleColorChar + "[x] " + msg + ResetConsoleColorChar)
}

func prefix(indent int) string {
	p := ""
	for j := 0; j < indent; j++ {
		p += " => "
	}
	return p
}
