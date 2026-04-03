package log

import (
	"fmt"
	"os"
	"strings"
)

const (
	BlueConsoleColorChar  = "\033[34m"
	RedConsoleColorChar   = "\033[31m"
	ResetConsoleColorChar = "\033[0m"
)

// helper: join msg parts with space
func joinMsg(msg ...any) string {
	parts := make([]string, len(msg))
	for i, m := range msg {
		parts[i] = fmt.Sprint(m)
	}
	return strings.Join(parts, " ")
}

// PrintStep prints blue info with indent
func PrintStep(indent int, msg ...any) {
	fmt.Println(
		BlueConsoleColorChar +
			prefix(indent) +
			" => " +
			joinMsg(msg...) +
			ResetConsoleColorChar,
	)
}

// OpenProcess prints info with indent
func OpenProcess(indent int, msg ...any) {
	fmt.Println(
		prefix(indent) +
			"[*] " +
			joinMsg(msg...),
	)
}

// EndProcess prints blue info with indent
func EndProcess(indent int, msg ...any) {
	fmt.Println(
		BlueConsoleColorChar +
			prefix(indent) +
			ResetConsoleColorChar +
			"[*] " +
			joinMsg(msg...) +
			ResetConsoleColorChar,
	)

	if indent == 0 {
		os.Exit(0)
	}
}

// FailProcess prints red info with indent
func FailProcess(indent int, msg ...any) {
	fmt.Println(
		BlueConsoleColorChar +
			prefix(indent) +
			RedConsoleColorChar +
			"[x] " +
			joinMsg(msg...) +
			ResetConsoleColorChar,
	)

	if indent == 0 {
		os.Exit(1)
	}
}

func prefix(indent int) string {
	p := ""
	for j := 0; j < indent; j++ {
		p += " => "
	}
	return p
}
