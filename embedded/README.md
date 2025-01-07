# Embedding both NATS and tailscale into a service

We are trying to combine both NATS and tailscale into a service.
This would create a reusable component that only requires user-space privileges.

WIP: *This was not yet successful*

While both NATS and tailscale are individually embeddable, we have not yet been able to integrate them both.

Still investigating possible approaches to combine both in user-space without requiring OS privileges.

## NATS Slack Question

```txt
Question about embedding NATS server:

Is itt be possible to provide a custom `net.Listener` (or provider of such) to an embedded NATS server for handling connections? 

Similar to how `http.Serve(ln net.Listener, handler Handler)` accepts a standard `net.Listener`,
I would like to provide my own listener implementation instead of having NATS create one via `natsListen()`.

Context: Looking to integrate embedded NATS with Tailscale's `tsnet` package which provides a `net.Listener` that handles Tailscale networking in user-space.

Any insights on whether this is possible with the current NATS server architecture would be appreciated.
```

## Tailscale Embedding (tsnet)

- Can be embedded using `tsnet` package
- Provides userspace networking without OS privileges
- Offers a standard `net.Listener` interface
- Can provide SOCKS5 proxy functionality

## NATS Server Embedding

- Can be embedded using the NATS server package
- Creates its own listeners for client connections
  - Listener are created with [`natsListen function:`](https://github.com/nats-io/nats-server/blob/d3bcbfc1bb5663550bd5dadea78b0d1e8917282b/server/util.go#L251)
- No built-in SOCKS proxy support found
- Provides in-process connections, but those are for local use only

## Challenges in Combining Both

1. NATS server creates its own listeners
2. No direct way to inject a custom listener into NATS
3. NATS doesn't support SOCKS proxying (which could have been a workaround)
