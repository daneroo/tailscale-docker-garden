// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

// The tailscale-web-server demonstrates how to use Tailscale as a library.
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"net/netip"

	"tailscale.com/tsnet"
)

var (
	addr = flag.String("addr", ":80", "address to listen on")
)

const (
	tsDir = "./data/tailscale"
	// serverNamePrefix is the prefix for the server name - (hostname -s) will be appended
	serverNamePrefix = "embedded-tailscale-web-server"
)

func main() {
	flag.Parse()

	// Get local hostname
	hostname, err := os.Hostname()
	if err != nil {
		log.Fatal(err)
	}
	// Get first component of hostname (before any dots)
	shortHostname := firstLabel(hostname)

	// Validate that we have a valid Tailscale AuthKey
	tsAuthKey := os.Getenv("TS_AUTHKEY")
	// TS_AUTHKEY=tskey-auth-kxztzrzyzrz-zzyzyzzzyzyzyyyzyzyz
	if tsAuthKey == "" {
		log.Fatal("TS_AUTHKEY is not set - check ../common/common.env")
	}
	// validate that tsauthkey is a valid Tailscale AuthKey format
	if !strings.HasPrefix(tsAuthKey, "tskey-auth-") {
		log.Fatal("TS_AUTHKEY is not a valid Tailscale AuthKey format")
	}
	// make sure the tailscale directory exists
	if _, err := os.Stat(tsDir); os.IsNotExist(err) {
		log.Printf("Creating tailscale directory: %s", tsDir)
		if err := os.MkdirAll(tsDir, 0755); err != nil {
			log.Fatalf("Failed to create tailscale directory: %v", err)
		}
	}

	s := &tsnet.Server{
		AuthKey:  tsAuthKey,
		Dir:      tsDir,
		Hostname: fmt.Sprintf("%s-%s", serverNamePrefix, shortHostname),
	}
	defer s.Close()
	ln, err := s.Listen("tcp", *addr)
	if err != nil {
		log.Fatal(err)
	}
	defer ln.Close()

	lc, err := s.LocalClient()
	if err != nil {
		log.Fatal(err)
	}

	// Get our own IP address
	ctx := context.Background()
	log.Printf("Waiting for Tailscale IP...")
	var selfIP netip.Addr
	for {
		status, err := lc.Status(ctx)
		if err != nil {
			log.Fatal(err)
		}
		if len(status.TailscaleIPs) > 0 {
			selfIP = status.TailscaleIPs[0]
			log.Printf("Server running at http://%s%s", selfIP, *addr)
			// Write IP to temp file for the Justfile to read
			if err := os.WriteFile("tailscale-ip.tmp", []byte(selfIP.String()), 0644); err != nil {
				log.Printf("Warning: Failed to write IP to file: %v", err)
			}
			break
		}
		time.Sleep(time.Second)
	}

	log.Fatal(http.Serve(ln, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		who, err := lc.WhoIs(r.Context(), r.RemoteAddr)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		fmt.Fprintf(w, `{"server":{"tailscaleIp":"%s","port":"%s"},"client":{"loginName":"%s","host":"%s","remoteAddr":"%s"}}`,
			selfIP.String(),
			strings.TrimPrefix(*addr, ":"),
			who.UserProfile.LoginName,
			firstLabel(who.Node.ComputedName),
			r.RemoteAddr)
	})))
}

func firstLabel(s string) string {
	s, _, _ = strings.Cut(s, ".")
	return s
}
