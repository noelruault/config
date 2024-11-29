#!/bin/bash
# This script helps you configure global Git settings for user name, email, and repositories.
# It also configures a global gitignore and gitconfig, and lets you choose between GitHub and GitLab, or both, for your repository management.

# Function to prompt the user for Git configuration details
configure_git_user() {
    echo "📝 Let's start by configuring your Git user details."
    
    read -p "Enter the name you want to associate with your Git commits (or 'skip' to skip): " NAME
    if [[ "$NAME" != "skip" ]]; then
        read -p "Enter the email address associated with your Git commits: " EMAIL
        git config --global user.name "$NAME"
        git config --global user.email "$EMAIL"
        echo "✅ Git user.name and user.email configured."
    else
        echo "⏩ Skipping Git user configuration."
    fi
}

# Function to configure global gitignore and gitconfig
configure_git_global() {
    echo "🛠 Configuring global Git ignore file and Git configuration..."
    git config --global core.excludesfile ~/.config/git/gitignore_global
    git config --global include.path ~/.config/git/gitconfig_global
    echo "✅ Global .gitignore and .gitconfig have been set up."
}

# Function to configure GitHub repository
configure_github() {
    echo "🔗 Setting up GitHub repository..."
    read -p "Enter your GitHub username or company namespace (or 'skip' to skip): " GITHUB_USERNAME
    if [[ "$GITHUB_USERNAME" != "skip" ]]; then
        git config --global url."ssh://git@github.com/$GITHUB_USERNAME/".insteadOf "https://github.com/$GITHUB_COMPANY/"
        echo "✅ GitHub repository for $GITHUB_COMPANY configured."
    else
        echo "⏩ Skipping GitHub repository configuration."
    fi
}

# Function to configure GitLab repository
configure_gitlab() {
    echo "🔗 Setting up GitLab repository..."
    read -p "Enter your GitLab username or company namespace (or 'skip' to skip): " GITLAB_USERNAME
    if [[ "$GITLAB_USERNAME" != "skip" ]]; then
        git config --global url."ssh://git@gitlab.com/$GITLAB_USERNAME/".insteadOf "https://gitlab.com/$GITLAB_USERNAME/"
        echo "✅ GitLab repository for $GITLAB_USERNAME configured."
    else
        echo "⏩ Skipping GitLab repository configuration."
    fi
}

# Function to configure both GitHub and GitLab repositories
configure_both() {
    echo "🔗 Setting up both GitHub and GitLab repositories..."

    configure_github
    configure_gitlab
}

# Function to prompt for repository selection: GitHub, GitLab, or both
configure_git_remotes() {
    echo "🌐 Next, let's configure your remote repositories."
    echo "You can select from the following options for repository configurations:"
    echo "1) GitHub"
    echo "2) GitLab"
    echo "3) Both GitHub and GitLab"
    echo "4) Skip repository configuration"

    read -p "Please select your repository platform (1, 2, 3, or 4 to skip): " REPO_CHOICE

    case $REPO_CHOICE in
        1) configure_github ;;
        2) configure_gitlab ;;
        3) configure_both ;;
        4) echo "⏩ Skipping repository configuration." ;;
        *)
            echo "⚠️ Invalid option. Please run the script again and choose 1, 2, 3, or 4."
            exit 1
            ;;
    esac
}

# Function to display the current Git configuration
show_git_config() {
    echo "📄 Here is your current global Git configuration:"
    git -c core.pager=cat config --list --show-origin
}

# Main execution
# configure_git_user    # Step 1: Configure user.name and user.email
# configure_git_global  # Step 2: Set up global .gitignore and .gitconfig
configure_git_remotes # Step 3: Choose and configure remote repositories
show_git_config       # Step 4: Display the current Git configuration

echo "🎉 Git setup complete! You can manually review or edit your configuration in ~/.gitconfig if needed."
