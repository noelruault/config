# Checks for internet connectivity.
if nc -zw1 google.com 443 &>/dev/null; then echo; else exit 1; fi

domain_expiry_date=$(whois noel.io | grep "Registry Expiry Date" | grep -oE '(\d{4})-(\d\d)-(\d\d)' | sed 's/[\._-]//g')

current_epoch_time=$(date -jf %Y%m%d $(date +%Y%m%d) +%s)
domain_expity_date_epoch=$(date -jf %Y%m%d $domain_expiry_date +%s)

days_until_expiration=$(((domain_expity_date_epoch - current_epoch_time) / 86400))

if [[ "$1" == "bash:request" ]]; then
    if ((days_until_expiration < 30)); then
        echo "DOMAIN ABOUT TO EXPIRE, $days_until_expiration days left."
    fi
else
    echo "Domain expiration is $days_until_expiration days ahead."
fi
