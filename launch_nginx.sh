#!/bin/bash

PID_FILE=/var/run/nginx.pid

if test -f "$PID_FILE"; then
  /usr/sbin/nginx -s reload
else
  /usr/sbin/nginx -g "daemon off;"
fi


