# shellcheck shell=sh

# pip configuration
if command -v pip > /dev/null; then
    # Disable the pip version check if any Salt packages are installed. With
    # Salt we typically will be running an older pip version due to frequent
    # incompatible changes introduced upstream which Salt needs to handle.
    if command -v salt-call > /dev/null; then
        export PIP_DISABLE_PIP_VERSION_CHECK=true
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
