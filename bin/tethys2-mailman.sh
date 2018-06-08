#!/bin/sh

MAILMAN_PATH="/usr/local/mailman/"

exec sudo -u mailman $MAILMAN_PATH/mail/mailman $*
