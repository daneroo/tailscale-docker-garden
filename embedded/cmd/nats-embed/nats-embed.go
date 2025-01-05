package main

import (
	"fmt"
	"log"
	"time"

	"github.com/nats-io/nats-server/v2/server"
	"github.com/nats-io/nats.go"
)

func main() {
	nc, ns, err := RunEmbeddedServer(true, true)
	if err != nil {
		log.Fatal(err)
	}
	defer nc.Close()

	// Simple subscription to test the server
	nc.Subscribe("hello", func(msg *nats.Msg) {
		payload := string(msg.Data)
		log.Printf("NATS-Handler: Received: %s\n", payload)
		msg.Respond([]byte(fmt.Sprintf("Hello back (%s)!", payload)))
	})

	// Test publish
	resp, err := nc.Request("hello", []byte("Hello NATS (internal client)!"), time.Second)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Internal-Client: Got response: %s\n", string(resp.Data))

	// Keep the server running
	ns.WaitForShutdown()
}

func RunEmbeddedServer(inProcess bool, enableLogging bool) (*nats.Conn, *server.Server, error) {
	// Basic server options
	opts := &server.Options{
		ServerName: "embedded_server",
		Host:       "127.0.0.1",
		Port:       4222,
		DontListen: false, // Changed to false to allow external connections
	}

	// Create the server
	ns, err := server.NewServer(opts)
	if err != nil {
		return nil, nil, err
	}

	if enableLogging {
		ns.ConfigureLogger()
	}

	// Start the server
	go ns.Start()

	if !ns.ReadyForConnections(5 * time.Second) {
		return nil, nil, err
	}

	// Connect a client
	clientOpts := []nats.Option{}
	if inProcess {
		clientOpts = append(clientOpts, nats.InProcessServer(ns))
	}

	nc, err := nats.Connect(nats.DefaultURL, clientOpts...)
	if err != nil {
		return nil, nil, err
	}

	return nc, ns, nil
}
