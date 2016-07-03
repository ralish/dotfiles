# APT configuration

if command -v apt-get > /dev/null; then
    # Super useful alias to determine manually installed packages
    # Via: https://askubuntu.com/questions/2389/generating-list-of-manually-installed-packages-and-querying-individual-packages
    alias apt-pkgs="comm -23 <(apt-mark showmanual | sort -u) \
                             <(gzip -dc /var/log/installer/initial-status.gz \
                               | sed -n \"s/^Package: //p\" | sort -u)"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
