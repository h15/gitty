How to install
    Admin access - admin:nimda

  Prepare git user
    Install soft. Run as root.

      aptitude install openssh-server git-core

      adduser --system --shell /bin/sh --gecos 'git version control' --group \
              --disabled-password --home /home/git git

    Create ssh key for git.

      sudo -u git ssh-keygen

    Allow ssh support for git. Edit manually file "/etc/ssh/sshd_config".
    Add user "git" into line "AllowUsers".

      /etc/init.d/ssh restart

  Install Gitolite
    Run as root.

      aptitude install gitolite

    Run as git.

      gl-setup ~/root.pub

    Get admin repo (run as git-admin user).

      git clone git@server:gitolite-admin

  Install Perl modules
      sudo cpan Mojolicious DBI DBD::SQLite

