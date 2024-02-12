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

# Sanity check; confirm we can bring up a tailscale host
sanity:
  #!/usr/bin/env sh
  set -ueo pipefail # -x makes bash print each script line before it’s run.
  echo "# Smoke test for tailscale container" | {{ gum_fmt_cmd }}
  just check_common_env

  echo "## Spinning up tailscale container" | {{ gum_fmt_cmd }}
  cd sanity
  gum spin --title "Spinning up containers" -- docker compose up -d
  gum spin --title "Waiting for ts-sidecar" -- just waitForServiceRunning sanity ts-sidecar
  echo "{{ green_check }} - ts-sidecar is running"
  gum spin --title "Waiting for tailscale ip" -- just waitForTailscaleIP sanity ts-sidecar
  ipv4=$(docker compose exec -T ts-sidecar tailscale ip -4)
  echo "{{ green_check }} - ts-sidecar got ip: ${ipv4}"
 
  echo "## Checking tailscale status:" | {{ gum_fmt_cmd }}
  docker compose exec -it ts-sidecar tailscale status
  sleep 5
  echo "## Shutting down tailscale container" | {{ gum_fmt_cmd }}
  docker compose down
  echo "# All done" | {{ gum_fmt_cmd }}

# Write a target that will cd into 01-authkey and run docker compose up -d
# This will start the container in the background
web:
  cd 01-authkey && docker-compose up -d

weblog:
  cd 01-authkey && docker-compose logs -f

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
