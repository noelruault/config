# Checks for internet connectivity. Silent exit if no connection
if nc -zw1 google.com 443 &>/dev/null; then echo; else exit 1; fi

domain_status=$(whois noel.io | grep -m1 "Domain Status")
domain_expiry_date=$(whois noel.io | grep "Registry Expiry Date" | grep -oE '(\d{4})-(\d\d)-(\d\d)' | sed 's/[\._-]//g')

gdate=$HOMEBREW_PREFIX/bin/gdate
current_epoch_time=$(gdate +%s)
domain_expity_date_epoch=$(gdate --date=$domain_expiry_date +%s)
days_until_expiration=$(((domain_expity_date_epoch - current_epoch_time) / 86400))

if [[ "$1" == "bash:request" ]]; then
    if ((days_until_expiration < 30)); then
        echo "DOMAIN ABOUT TO EXPIRE, $days_until_expiration days left."
        echo "$domain_status"
    fi
else
    echo "Domain expiration is $days_until_expiration days ahead."
fi
