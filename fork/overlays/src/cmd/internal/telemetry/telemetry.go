// Copyright 2024 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package telemetry is a no-op stub. Telemetry is disabled in this fork.
package telemetry

func MaybeParent()              {}
func MaybeChild()               {}
func Mode() string              { return "" }
func SetMode(mode string) error { return nil }
func Dir() string               { return "" }
