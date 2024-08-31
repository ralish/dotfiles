# shellcheck shell=sh

# APT configuration
if df_app_load 'APT [apt]' 'command -v apt-get > /dev/null'; then
    # Show configuration files which have been modified from the defaults
    # Via: https://serverfault.com/a/90401/850629
    # shellcheck disable=SC2142,SC2154
    alias apt-cfgs='dpkg-query -W -f="\${Conffiles}\n" "*" | awk "OFS=\"  \"{print \$2,\$1}" | md5sum --quiet -c 2> /dev/null | cut -d : -f 1'

    # List packages which have been manually installed (i.e. not dependencies)
    # Via: https://askubuntu.com/a/492343/1602916
    alias apt-pkgs='comm -23 <(apt-mark showmanual | sort -u) <(gzip -dc /var/log/installer/initial-status.gz | sed -n "s/^Package: //p" | sort -u)'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
