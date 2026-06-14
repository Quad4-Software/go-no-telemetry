// Copyright 2024 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package telemetrycmd implements the "go telemetry" command.
// In this fork, telemetry is fully disabled everywhere.
package telemetrycmd

import (
	"cmd/go/internal/base"
	"context"
	"fmt"
)

var CmdTelemetry = &base.Command{
	UsageLine: "go telemetry [off|local|on]",
	Short:     "manage telemetry data and settings",
	Long: `Telemetry is used to manage Go telemetry data and settings.

Telemetry is disabled in this Go fork. The "go telemetry" command
is a no-op stub provided for compatibility.
`,
	Run: func(ctx context.Context, cmd *base.Command, args []string) {
		if len(args) == 0 {
			fmt.Println("off")
			return
		}
		switch args[0] {
		case "off", "local", "on":
			fmt.Printf("go: telemetry is disabled in this Go fork; mode '%s' not applied\n", args[0])
		default:
			fmt.Printf("go: unknown telemetry mode %q\n", args[0])
		}
	},
}
