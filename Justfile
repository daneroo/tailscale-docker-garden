# Install just on Ubuntu:
# curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | sudo bash -s -- --to /usr/local/bin/
# Install just on macOS:
# brew install just

# This will expose the docker host's name as HOSTALIAS
export HOSTALIAS := `hostname -s`

# Colors and symbols
# weird escape for Just, could not get octal 33 any other way
green := `printf "\033[32m"`
red := `printf "\033[31m"`
reset := `printf "\033[0m"`
green_check := green + "✔" + reset
red_xmark := red + "✗" + reset
# centralize the format command to style (theme=light)
gum_fmt_cmd := "gum format --theme=light"

# List available commands
default:
  just -l

# stop all services
down-all: 
  just nats-client-down
  just nats-server-down 


# Smoke Test: confirm we can bring up a tailscale host
smoketest:
  #!/usr/bin/env bash
  set -eu # exit if fail or undefined variable
  echo "# Smoke test for tailscale container" | {{ gum_fmt_cmd }}
  just check_common_env

  echo "## Spinning up containers" | {{ gum_fmt_cmd }}
  cd smoketest
  gum spin --title "Spinning up containers" -- docker compose up -d
  gum spin --title "Waiting for ts-sidecar" -- just waitForServiceRunning smoketest ts-sidecar
  echo "{{ green_check }} - ts-sidecar is running"
  gum spin --title "Waiting for tailscale ip" -- just waitForTailscaleIP smoketest ts-sidecar
  ipv4=$(docker compose exec -T ts-sidecar tailscale ip -4)
  echo "{{ green_check }} - ts-sidecar got ip: ${ipv4}"
 
  echo "## Checking tailscale status:" | {{ gum_fmt_cmd }}
  docker compose exec -it ts-sidecar tailscale status
  sleep 5
  echo "## Shutting down tailscale container" | {{ gum_fmt_cmd }}
  docker compose down
  echo "# All done" | {{ gum_fmt_cmd }}

# Bring up a web server with a tailscale sidecar
web-server:
  #!/usr/bin/env bash
  set -eu # exit if fail or undefined variable
  echo "# Web Server with Privileged Tailscale Sidecar" | {{ gum_fmt_cmd }}
  just check_common_env

  echo "## Spinning up containers" | {{ gum_fmt_cmd }}
  cd web-server
  gum spin --title "Spinning up containers" -- docker compose up -d
  gum spin --title "Waiting for ts-sidecar" -- just waitForServiceRunning web-server ts-sidecar
  echo "{{ green_check }} - ts-sidecar is running"
  gum spin --title "Waiting for tailscale ip" -- just waitForTailscaleIP web-server ts-sidecar
  ipv4=$(docker compose exec -T ts-sidecar tailscale ip -4)
  echo "{{ green_check }} - ts-sidecar got ip: ${ipv4}"

# Shut down the web server
web-server-down:
  #!/usr/bin/env bash
  echo "## Spinning down containers" | {{ gum_fmt_cmd }}
  cd web-server
  docker compose down
  
# Bring up a nats server with a tailscale sidecar
nats-server:
  #!/usr/bin/env bash
  set -eu # exit if fail or undefined variable
  echo "# Nats Server with Privileged Tailscale Sidecar" | {{ gum_fmt_cmd }}
  just check_common_env

  echo "## Spinning up containers" | {{ gum_fmt_cmd }}
  cd nats-server
  gum spin --title "Spinning up containers" -- docker compose up -d
  gum spin --title "Waiting for ts-sidecar" -- just waitForServiceRunning nats-server ts-sidecar
  echo "{{ green_check }} - ts-sidecar is running"
  gum spin --title "Waiting for tailscale ip" -- just waitForTailscaleIP nats-server ts-sidecar
  ipv4=$(docker compose exec -T ts-sidecar tailscale ip -4)
  echo "{{ green_check }} - ts-sidecar got ip: ${ipv4}"

# Shut down the nats server
nats-server-down:
  #!/usr/bin/env bash
  echo "## Spinning down containers" | {{ gum_fmt_cmd }}
  cd nats-server
  docker compose down

# Bring up a nats client with a tailscale sidecar
nats-client:
  #!/usr/bin/env bash
  set -eu # exit if fail or undefined variable
  echo "# Nats Client with Privileged Tailscale Sidecar" | {{ gum_fmt_cmd }}
  just check_common_env

  echo "## Spinning up containers" | {{ gum_fmt_cmd }}
  cd nats-client
  export NATS_SERVER_IP=NOTYETDEFINED
  gum spin --title "Spinning up only tailscale sidecar container" -- docker compose up -d ts-sidecar
  gum spin --title "Waiting for ts-sidecar" -- just waitForServiceRunning nats-client ts-sidecar
  echo "{{ green_check }} - ts-sidecar is running"
  gum spin --title "Waiting for tailscale ip" -- just waitForTailscaleIP nats-client ts-sidecar
  ipv4=$(docker compose exec -T ts-sidecar tailscale ip -4)
  echo "{{ green_check }} - ts-sidecar got ip: ${ipv4}"
  # now get the nats servers ip, from tailscale status
  # we are looking for a server with a hostname that matches the nats-server pattern: ts-sidecar-nats-server-.*
  # because it might be running on another host
  nats_server_ip=$(docker compose exec -T ts-sidecar tailscale status --json | jq -r '.Peer | .[] | select(.HostName | test("ts-sidecar-nats-server-.*")) | .TailscaleIPs[0]')
  if [ -z "${nats_server_ip}" ]; then
    echo "{{ red_xmark }} - nats server ip not found: no server with hostname matching ts-sidecar-nats-server-.*"
    echo "  You shoud run **just nats-server** first to bring up the nats server." | {{ gum_fmt_cmd }}
    exit 1
  fi
  echo "{{ green_check }} - nats server ip: ${nats_server_ip}"
  export NATS_SERVER_IP=${nats_server_ip}
  gum spin --title "Spinning up ALL containers" -- docker compose up -d

# Show the client subscriber output
nats-client-show:
  #!/usr/bin/env bash
  echo "## Showing nats client subscriber output" | {{ gum_fmt_cmd }}
  cd nats-client
  docker compose logs -f nats-subscriber

# Shut down the nats client
nats-client-down:
  #!/usr/bin/env bash
  echo "## Spinning down containers" | {{ gum_fmt_cmd }}
  cd nats-client
  export NATS_SERVER_IP=NOTYETDEFINED
  docker compose down


# Check if common/common.env file exists and has an auth key
[private]
check_common_env:
  #!/usr/bin/env bash
  echo "## Checking setup" | {{ gum_fmt_cmd }}
  if [ ! -f common/common.env ]; then
    echo "{{ red_xmark }} - common/common.env file does not exist"
    exit 1;
  else
    echo "{{ green_check }} - common/common.env file exists"
  fi
  if ! grep -q "^TS_AUTHKEY=" common/common.env; then
    echo "{{ red_xmark }} - common/common.env file does not contain TS_AUTHKEY"
    exit 1;
  else
    echo "{{ green_check }} - common/common.env file contains TS_AUTHKEY"
  fi


# Wait for compose service to be running (compose file in the specified directory)
[private]
waitForServiceRunning directory service:
  #!/usr/bin/env bash
  cd {{directory}}
  echo "## Waiting for container service {{service}} to be running in directory {{directory}}" | {{ gum_fmt_cmd }}
  while [[ "$(docker compose ps --format json {{service}} | jq -r '.State')" != "running" ]]; do
    docker compose ps --format json {{service}} | jq -r '.State'
    echo "{{ red_xmark }} - Service {{service}} is not yet running"
    sleep 1
  done
  echo "{{ green_check }} - Service {{service}} is running"

# Wait for compose service to be running (compose file in the specified directory)
[private]
waitForTailscaleIP directory service:
  #!/usr/bin/env bash
  cd {{directory}}
  # Now wait for the tailscale ip to be assigned
  echo "## Waiting for tailscale ip to be assigned in service {{service}} of directory {{directory}}" | {{ gum_fmt_cmd }}
  while ! docker compose exec -T {{service}} tailscale ip -4 >/dev/null 2>&1; do
    echo "{{ red_xmark }} - Tailscale ip not yet assigned"
    sleep 1
  done
