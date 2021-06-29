#!/usr/bin/env bash

# Starts the server
# {1} port
# {2} response
function start_mock_server() {
  RESPONSE="HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n${2:-"OK"}\r\n"
  while { echo -en "$RESPONSE"; } | nc -l "${1:-8080}"; do
      echo "==============================="
  done
}

