#!/bin/bash
##This is a logger module for main.sh...
log_setup() {
    mkdir -p /tmp/bedrockinstaller/logs
    touch /tmp/bedrockinstaller/logs/{log.txt,errors.txt}
}

log() {
    ##First of all, echoing which command is being run in both the txt files.
    echo -e "\n\nRunning command:$@" | sudo tee -a /tmp/bedrockinstaller/logs/log.txt >> /tmp/bedrockinstaller/logs/errors.txt
    "$@" 1>>/tmp/bedrockinstaller/logs/log.txt 2>>/tmp/bedrockinstaller/logs/errors.txt
    echo "This command has completed."
}

log_msg() {
    echo "$@" >> /tmp/bedrockinstaller/logs/log.txt
}
