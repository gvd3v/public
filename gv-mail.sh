#!/bin/bash

# Configuration folder and default profile file
CONFIG_FOLDER="$HOME/.gv-mail"
DEFAULT_PROFILE="default"

# Ensure configuration folder exists
mkdir -p "$CONFIG_FOLDER"

# Install sendemail if not installed
if ! command -v sendemail &>/dev/null; then
    echo "sendemail not found. Installing..."
    sudo apt-get update && sudo apt-get install -y sendemail libnet-ssleay-perl libio-socket-ssl-perl
fi

# Function to set up SMTP configuration
setup_config() {
    local PROFILE=${1:-$DEFAULT_PROFILE}
    local PROFILE_FILE="$CONFIG_FOLDER/$PROFILE"

    echo "Setting up SMTP configuration for profile: $PROFILE"
    read -p "SMTP server: " SMTP_SERVER
    read -p "SMTP port: " SMTP_PORT
    read -p "SMTP username: " SMTP_USER
    read -sp "SMTP password: " SMTP_PASS
    echo
    read -p "Use TLS (yes/no): " USE_TLS
    read -p "Default FROM email address: " FROM_EMAIL

    cat >"$PROFILE_FILE" <<EOL
SMTP_SERVER=$SMTP_SERVER
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASS=$SMTP_PASS
USE_TLS=$USE_TLS
FROM_EMAIL=$FROM_EMAIL
EOL
    echo "Configuration saved to $PROFILE_FILE"
}

# Function to display usage
usage() {
    echo "Usage: $0 [-t TO] [-s SUBJECT] [-b BODY] [--html HTML_FILE] [-cc CC] [-bcc BCC] [-a ATTACHMENTS] [-f FROM] [--profile PROFILE]"
    echo "  -t TO          Recipient email address(es) (optional if CC or BCC is provided)"
    echo "  -s SUBJECT     Email subject (optional)"
    echo "  -b BODY        Email body (optional)"
    echo "  --html HTML_FILE Email body as HTML (optional)"
    echo "  -cc CC         CC recipients (comma-separated, optional)"
    echo "  -bcc BCC       BCC recipients (comma-separated, optional)"
    echo "  -a ATTACHMENTS Attachments (comma-separated, optional)"
    echo "  -f FROM        Sender email address (optional, overrides config)"
    echo "  --profile PROFILE Specify a profile (defaults to 'default')"
    exit 1
}

# Parse arguments
TO=""
SUBJECT=""
BODY=""
HTML_FILE=""
CC=""
BCC=""
ATTACHMENTS=""
FROM=""
PROFILE=$DEFAULT_PROFILE

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t) TO="$2"; shift 2 ;;
        -s) SUBJECT="$2"; shift 2 ;;
        -b) BODY="$2"; shift 2 ;;
        --html) HTML_FILE="$2"; shift 2 ;;
        -cc) CC="$2"; shift 2 ;;
        -bcc) BCC="$2"; shift 2 ;;
        -a) ATTACHMENTS="$2"; shift 2 ;;
        -f) FROM="$2"; shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        *) usage ;;
    esac
done

# Load configuration file based on profile
PROFILE_FILE="$CONFIG_FOLDER/$PROFILE"
if [[ ! -f $PROFILE_FILE ]]; then
    echo "Configuration file for profile '$PROFILE' not found."
    echo "Run the script with '--profile $PROFILE' to set it up."
    setup_config "$PROFILE"
fi
source "$PROFILE_FILE"

# Use default FROM email if not specified in the parameters
if [[ -z $FROM ]]; then
    FROM="$FROM_EMAIL"
fi

# Validate required arguments
if [[ -z $TO && -z $CC && -z $BCC ]]; then
    echo "Error: At least one recipient must be specified via -t, -cc, or -bcc."
    usage
fi

if [[ -z $BODY && -z $HTML_FILE ]]; then
    echo "Error: A message body must be specified via -b or --html."
    usage
fi

# Construct email options

EMAIL_OPTIONS=" -f \"$FROM\" -s \"$SMTP_SERVER:$SMTP_PORT\" -xu \"$SMTP_USER\" -xp \"$SMTP_PASS\""

if [[ $USE_TLS == "yes" ]]; then
    EMAIL_OPTIONS+=" -o tls=yes"
fi

if [[ -n $TO ]]; then
    EMAIL_OPTIONS+=" -t \"$TO\""
fi

if [[ -n $CC ]]; then
    EMAIL_OPTIONS+=" -cc \"$CC\""
fi

if [[ -n $BCC ]]; then
    EMAIL_OPTIONS+=" -bcc \"$BCC\""
fi

if [[ -n $BODY && -z $HTML_FILE ]]; then
    EMAIL_OPTIONS+=" -m \"$BODY\""
elif [[ -n $HTML_FILE ]]; then
    EMAIL_OPTIONS+=" -o message-file=$HTML_FILE"
fi

if [[ -n $SUBJECT ]]; then
    EMAIL_OPTIONS+=" -u \"$SUBJECT\""
fi

if [[ -n $ATTACHMENTS ]]; then
    IFS=',' read -ra ATTACH_ARRAY <<<"$ATTACHMENTS"
    for ATTACHMENT in "${ATTACH_ARRAY[@]}"; do
        EMAIL_OPTIONS+=" -a \"$ATTACHMENT\""
    done
fi

echo $EMAIL_OPTIONS

# Send email
eval sendemail $EMAIL_OPTIONS

EXIT_STATUS=$?
if [[ $EXIT_STATUS -eq 0 ]]; then
    echo "Email sent successfully."
else
    echo "Failed to send email. Exit status: $EXIT_STATUS"
fi
