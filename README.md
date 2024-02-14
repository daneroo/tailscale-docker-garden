# Tailscale and Docker examples

This demonstrates how to use Tailscale with Docker using a sidecar pattern.

Forked from [tailscale-dev/docker-guide-code-examples](https://github.com/tailscale-dev/docker-guide-code-examples)

The goal of the experiment is to determine if and when it is possible tu run the tailscale sidecar container without the `net_admin` and `sys_module` privileged capabilities.

Also there is a difference between the requirements of the tailscale container as to the direction of the traffic.

- outgoing: e.g. a nats client subscribes or publishes as an outgoing connection to the nats server. This is specifically regarding traffic that originates from the container, to another node on our tailnet
- incoming: e.g. a web server or proxy, or the nats server itself, must serve incoming traffic.

A secondary objective was to determine how to refactor/reuse docker `compose.yaml` files with `extends` and `env_file` to avoid duplication.

## TODO

- [ ] Good a place as any to get nix+direnv to work!
- [ ] Minimum requirements:
  - [ ] `- /dev/net/tun:/dev/net/tun` mapping is NOT required as it does not even exist on MacOS

## Usage

pre-requisites: docker, just (make replacement), gum, tailscale account

```sh
just smoketest

just web-server
just web-server-down

just nats-server

just nats-client
just nats-client-show
just nats-client-down

just nats-server-down

just down-all
```

## Authentication to tailscale

Although it would be more complete to use **OAuth Secrets** to provide scopes and tags to our provisioned containers, we will only use **Auth Keys** for simplicity. This is because we don't want the burden of managing **tags** which must be done in _Tailscale's Access Controls_ (for now).

### Generate your Auth Key

Go to: <https://login.tailscale.com/admin/settings/keys> to generate your auth key.

- It will expire in at most 90 days.
- Make it reusable, so we can use it for all our exerimet's tailscale containers.
- Make it ephemaeral, so it the devices will be automatically removed after going offline
- Copy [`./common/common.example.dev`](./common/common.example.env) to [`./common/common.env`](./common/common.env) and fill in the `TS_AUTHKEY` with your key. (`common/common.env` is gitignored)

## Compose File Inheritance

We will use the `extends` feature of docker-compose to create a common file that will be used by all our examples. for example to extend the `tailscale-base` service:

```yaml
version: "3.7"
services:
  ts-sidecar:
    extends:
      file: ../common/compose.yaml
      service: ts-sidecar-base
```

and this base config will load the `common.env` file to set environment variables like `TS_AUTHKEY`.

```yaml
version: "3.7"
services:
  ts-sidecar-base:
    image: tailscale/tailscale:latest
    env_file: ./common.env
```

## Privileged Container mode

## Unprivileged Container mode

## References

- [Multiple Compose Files](https://docs.docker.com/compose/multiple-compose-files/extends/#multiple-compose-files)

## Upstream

This repository supports:

- [YouTube video](https://youtu.be/tqvvZhGrciQ)
- [Blog post](https://tailscale.com/blog/docker-tailscale-guide)

[![The Definitive Guide for using Tailscale and Docker](https://img.youtube.com/vi/tqvvZhGrciQ/maxresdefault.jpg)](https://youtu.be/tqvvZhGrciQ)
