#!/bin/bash
# Configures SSH-based commit signing for Git.
# Optionally generates a dedicated signing key or reuses an existing one.

select_or_generate_key() {
    echo ""
    echo "🔑 SSH Commit Signing Setup"
    echo ""

    local existing_keys
    existing_keys=(~/.ssh/*.pub)

    if [[ ${#existing_keys[@]} -gt 0 && -f "${existing_keys[0]}" ]]; then
        echo "Existing public keys:"
        for i in "${!existing_keys[@]}"; do
            echo "  $((i+1))) ${existing_keys[$i]}"
        done
        echo "  $((${#existing_keys[@]}+1))) Generate a new key"
        echo ""
        read -p "Select key to use for signing (or 'skip' to skip): " CHOICE </dev/tty

        if [[ "$CHOICE" == "skip" ]]; then
            echo "⏩ Skipping key selection."
            return 1
        fi

        local gen_opt=$(( ${#existing_keys[@]} + 1 ))
        if [[ "$CHOICE" == "$gen_opt" ]]; then
            _generate_signing_key
        elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#existing_keys[@]} )); then
            SIGNING_KEY_PUB="${existing_keys[$((CHOICE-1))]}"
            echo "✅ Using existing key: $SIGNING_KEY_PUB"
        else
            echo "⚠️  Invalid choice."
            return 1
        fi
    else
        echo "No existing SSH keys found."
        read -p "Generate a new signing key? ([y]/n) " answer </dev/tty
        answer=${answer:-y}
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            _generate_signing_key
        else
            echo "⏩ Skipping."
            return 1
        fi
    fi
}

_generate_signing_key() {
    read -p "Enter email for the signing key: " EMAIL </dev/tty
    local key_file=~/.ssh/id_ed25519_signing
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$key_file" -N ""
    ssh-add --apple-use-keychain "$key_file"
    echo "✅ Signing key generated: ${key_file}.pub"
    SIGNING_KEY_PUB="${key_file}.pub"
}

configure_git_signing() {
    local pub_key_file="$1"
    local pub_key_content
    pub_key_content=$(cat "$pub_key_file")

    git config --global gpg.format ssh
    git config --global gpg.ssh.program ssh-keygen
    git config --global user.signingkey "$pub_key_content"
    git config --global commit.gpgsign true
    echo "✅ Git configured to sign commits with SSH."
}

configure_allowed_signers() {
    local pub_key_file="$1"
    local email
    email=$(git config --global user.email)

    if [[ -z "$email" ]]; then
        read -p "Enter the email address associated with your Git commits: " email </dev/tty
    fi

    local allowed_signers_file=~/.ssh/allowed_signers
    local pub_key_content
    pub_key_content=$(cat "$pub_key_file")

    # Add entry if not already present
    if ! grep -qF "$pub_key_content" "$allowed_signers_file" 2>/dev/null; then
        echo "$email $pub_key_content" >> "$allowed_signers_file"
        echo "✅ Added to allowed signers: $allowed_signers_file"
    else
        echo "ℹ️  Key already in allowed signers file."
    fi

    git config --global gpg.ssh.allowedSignersFile "$allowed_signers_file"
    echo "✅ gpg.ssh.allowedSignersFile configured."
}

show_github_instructions() {
    local pub_key_file="$1"
    echo ""
    echo "📋 Add the following public key to GitHub as a Signing Key:"
    echo "   GitHub → Settings → SSH and GPG keys → New SSH key → Key type: Signing Key"
    echo ""
    cat "$pub_key_file"
    echo ""
    pbcopy < "$pub_key_file" && echo "📃 Public key copied to clipboard."
    echo ""
    echo "   https://github.com/settings/keys"
    echo ""
}

# Main execution
SIGNING_KEY_PUB=""

select_or_generate_key || exit 0

if [[ -z "$SIGNING_KEY_PUB" || ! -f "$SIGNING_KEY_PUB" ]]; then
    echo "⚠️  No key selected. Aborting."
    exit 1
fi

configure_git_signing "$SIGNING_KEY_PUB"
configure_allowed_signers "$SIGNING_KEY_PUB"
show_github_instructions "$SIGNING_KEY_PUB"

echo "🎉 SSH commit signing setup complete!"
echo "   Test with: git commit --allow-empty -m 'test: verify signing' && git log --show-signature -1"
