# CPAN
# https://perldoc.perl.org/CPAN
#
# Last reviewed release: 2.38
# Default file path: ~/.cpan/CPAN/MyConfig.pm
#
# On Debian you may want to install:
# - libcpan-distnameinfo-perl (CPAN::DistnameInfo)
# - liblog-log4perl-perl (Log::Log4perl)
# - libmodule-build-perl (Module::Build)
# - libmodule-signature-perl (Module::Signature)
# - libterm-readline-gnu-perl (Term:ReadLine::Gnu)
# - libyaml-libyaml-perl (YAML::XS)
#
# On Strawberry Perl you may want to install:
# - Log::Log4perl
# - Module::Signature

# Are we running on Windows?
my $IsWin = $^O eq "MSWin32" ? 1 : 0;

$CPAN::Config = {
    # List of modules to skip loading (via CPAN::has_inst())
    'dontload_list' => [],
    # List of enabled plugins (see CPAN::Plugin)
    'plugin_list' => [],

    # Build & cache directory
    'cpan_home'         => $IsWin ? q[D:\\Cache\\CPAN] : qq[$ENV{HOME}/.cpan],
    # Source directory
    'keep_source_where' => $IsWin ? q[D:\\Cache\\CPAN\\sources] : qq[$ENV{HOME}/.cpan/sources],
    # Patches directory
    'patches_dir'       => q[],
    # Build directory
    'build_dir'         => $IsWin ? q[D:\\Cache\\CPAN\\build] : qq[$ENV{HOME}/.cpan/build],
    # Preferences directory
    'prefs_dir'         => $IsWin ? qq[$ENV{USERPROFILE}\\.cpan\\prefs] : qq[$ENV{HOME}/.cpan/prefs],

    # Paths to external programs
    #
    # Entries marked "space" use a Perl module when set to a space.
    'applypatch' => $IsWin ? q[] : q[/usr/bin/applypatch],
    'bzip2'      => $IsWin ? q[ ] : q[/usr/bin/bzip2], # space
    'curl'       => $IsWin ? qq[$ENV{SystemRoot}\\System32\\curl.exe] : q[/usr/bin/curl],
    'ftp'        => $IsWin ? qq[$ENV{SystemRoot}\\System32\\ftp.exe] : q[/usr/bin/ftp],
    'gpg'        => $IsWin ? q[] : q[/usr/bin/gpg],
    'gpg'        => q[],
    'gzip'       => $IsWin ? q[ ] : q[/usr/bin/gzip], # space
    'lynx'       => q[],
    'make'       => $IsWin ? q[C:\\DevEnvs\\Perl\\c\\bin\\gmake.exe] : q[/usr/bin/make],
    'ncftp'      => q[],
    'ncftpget'   => q[],
    'pager'      => $IsWin ? qq[$ENV{SystemRoot}\\System32\\more.com] : q[/usr/bin/less],
    'patch'      => $IsWin ? q[C:\\DevEnvs\\Perl\\c\\bin\\patch.exe] : q[/usr/bin/patch],
    'shell'      => $IsWin ? qq[$ENV{SystemRoot}\\System32\\cmd.exe] : q[/usr/bin/zsh],
    'tar'        => $IsWin ? qq[$ENV{SystemRoot}\\System32\\tar.exe] : q[/usr/bin/tar], # space
    'unzip'      => $IsWin ? q[] : q[/usr/bin/unzip],
    'wget'       => $IsWin ? q[] : q[/usr/bin/wget],

    # Character to use for quoting external commands
    #
    # Defaults to a single quote on all platforms except Windows, which uses a
    # double quote. Setting it to a space will disable quoting (bad idea!).
    #'commands_quote' => q[],
    # Prefer external "tar" command (instead of Archive::Tar)
    'prefer_external_tar' => $IsWin ? q[0] : q[1],

    # Username and optional password for CPAN server
    'username' => q[],
    'password' => q[],

    # Always use FTP passive mode
    'ftp_passive' => q[1],
    # Duration to retain download statistics (days)
    'ftpstats_period' => q[14],
    # Number of items to keep in the download statistics
    'ftpstats_size' => q[99],

    # Address of HTTP and/or FTP proxy
    'http_proxy' => q[],
    'ftp_proxy' => q[],
    # List of addresses to bypass proxy (comma-separated)
    'no_proxy' => q[],
    # Username and optional password for proxy server
    'proxy_user' => q[],
    'proxy_pass' => q[],

    # Suppress startup greeting message
    'inhibit_startup_message' => q[0],

    # Automatically save configuration changes
    #
    # Enabling will result in CPAN removing all comments, formatting, and
    # ordering of statements on saving the configuration.
    'auto_commit' => q[0],

    # Terminal uses ISO-8859-1 character set (aka. Latin-1)
    #
    # Disabling is equivalent to enabling UTF-8.
    'term_is_latin' => q[0],

    # Enable terminal ornaments (requires Term::ReadLine)
    'term_ornaments' => q[1],

    # Enable colourised terminal output (requires Term::ANSIColor)
    #
    # Windows also requires Win32::Console::ANSI.
    'colorize_output' => $IsWin ? q[1] : q[0],
    # Colour for normal output
    'colorize_print' => q[bold green],
    # Colour for warnings
    'colorize_warn' => q[bold red],
    # Colour for debugging messages
    'colorize_debug' => q[black on_cyan],

    # Display the current command number in the prompt
    'commandnumber_in_prompt' => q[0],

    # Path to the history file (requires Term::ReadLine)
    'histfile' => $IsWin ? qq[$ENV{USERPROFILE}\\.cpan\\histfile] : qq[$ENV{HOME}/.cpan/histfile],
    # Maximum number of commands in the history
    'histsize' => q[1000],

    # If urllist has not been configured, permit connecting to the built-in
    # default sites without asking (the default is to ask once per session).
    'connect_to_internet_ok' => q[1],
    # List of CPAN mirrors to use
    'urllist' => [
        $IsWin ? q[https://cpan.strawberryperl.com/] : (),
        q[https://www.cpan.org/]
    ],
    # Randomize the mirror selected from "urllist"
    'randomize_urllist' => q[0],
    # Use external "ping" command when automatically selecting mirrors
    'urllist_ping_external' => q[0],
    # Increase output verbosity when automatically selecting mirrors
    'urllist_ping_verbose' => q[0],
    # Always use the official CPAN site for downloads
    #
    # HTTPS will be preferenced with fallback to HTTP if it cannot be used
    # (e.g. missing dependencies), in which case a warning will be emitted.
    # Enabling this option will ignore any "urllist".
    'pushy_https' => q[1],

    # List of CPAN WAIT servers to use
    'wait_list' => [],

    # Validity period of downloaded indexes (days)
    'index_expire' => q[1],

    # Policy for handling build prerequisites
    #
    # Valid options:
    # - follow            Automatically build
    # - ask               Ask for confirmation
    # - ignore            Ignore dependencies
    'prerequisites_policy' => q[follow],
    # Policy for installing build_requires modules
    #
    # Valid options: yes, no, ask/yes, ask/no
    'build_requires_install_policy' => q[ask/no],
    # Include recommended module dependencies
    'recommends_policy' => q[1],
    # Include suggested module dependencies
    'suggests_policy' => q[0],

    # Verify module signatures (requires Module::Signature)
    'check_sigs' => q[1],

    # Use default values for interactive prompts during builds
    'use_prompt_default' => q[0],

    # Preferred installer module
    #
    # Valid options:
    # - EUMM              ExtUtils::MakeMaker (Makefile.pl)
    # - MB                Module::Build (Build.pl)
    # - RAND              Randomised
    'prefer_installer' => q[MB],

    # Arguments to pass to Makefile.pl
    'makepl_arg' => $IsWin ? q[] : q[INSTALLDIRS=site],
    # Arguments to pass to "make"
    'make_arg' => $IsWin ? qq[-j$ENV{NUMBER_OF_PROCESSORS}] : q[],
    # Command to run instead of "make" when running "make install"
    'make_install_make_command' => $IsWin ? q[C:\\DevEnvs\\Perl\\c\\bin\\gmake.exe] : q[/usr/bin/make],
    # Arguments to pass to "make install"
    'make_install_arg' => q[UNINST=1],

    # Arguments to pass to Build.pl
    'mbuildpl_arg' => $IsWin ? q[] : q[--installdirs site],
    # Arguments to pass to "./Build"
    'mbuild_arg' => q[],
    # Command to run instead of "./Build" when running "./Build install"
    'mbuild_install_build_command' => $IsWin ? q[] : q[./Build],
    # Arguments to pass to "./Build install"
    'mbuild_install_arg' => q[--uninst=1],

    # Generate test reports (requires CPAN::Reporter)
    'test_report' => q[0],
    # Skip tests if a matching distribution passed
    'trust_test_report_history' => q[0],

    # Permit installation of outdated distributions
    #
    # Valid options: yes, no, ask/yes, ask/no
    #
    # Any option other than "yes" requires CPAN::DistnameInfo.
    'allow_installing_outdated_dists' => q[ask/no],
    # Permit installation of module downgrades
    #
    # Valid options: yes, no, ask/yes, ask/no
    'allow_installing_module_downgrades' => q[ask/no],

    # Store build state for reuse between sessions
    'build_dir_reuse' => q[1],
    # Cleanup build directories after successful install
    'cleanup_after_install' => q[1],

    # Halt on the first failed build target or dependency
    'halt_on_failure' => q[1],

    # Timeout for parsing $VERSION from a module (secs)
    'version_timeout' => q[15],
    # Timeout to kill Makefile.pl and Build.pl processes (secs)
    'inactivity_timeout' => q[0],

    # Method for obtaining the current working directory
    #
    # Valid options:
    # - cwd               Cwd::cwd
    # - getcwd            Cwd::getcwd
    # - fastcwd           Cwd::fastcwd
    # - getdcwd           Cwd::getdcwd
    'getcwd' => q[cwd],

    # Preferred YAML implementation
    #
    # Valid options:
    # - YAML
    # - YAML::Syck        Requires a C compiler
    # - YAML::XS          Requires a C compiler
    'yaml_module' => q[YAML::XS],
    # Permit deserialising code in YAML
    'yaml_load_code' => q[0],

    # Show module and distribution upload dates
    'show_upload_date' => q[1],
    # Print modules with a version number of zero
    'show_zero_versions' => q[0],
    # Print modules that do not have a version
    'show_unparsable_versions' => q[0],

    # Cache metadata (requires Storable)
    #
    # Not used when "use_sqlite" is enabled and SQLite is running.
    'cache_metadata' => q[1],
    # Cache metadata with SQLite (requires CPAN::SQLite)
    'use_sqlite' => q[1],

    # Maximum size of the build cache (MB)
    'build_cache' => q[250],
    # When to perform cache scanning
    #
    # Valid options:
    # - atstart           On starting CPAN
    # - atexit            On exiting CPAN
    # - never             Never scan
    'scan_cache' => q[atstart],

    # Report loading of modules
    #
    # Valid options:
    # - none              Quiet
    # - v                 Module name and version
    'load_module_verbosity' => q[v],
    # Report extending of @INC via PERL5LIB
    #
    # Valid options:
    # - none              Quiet
    # - v                 List of added directories
    'perl5lib_verbosity' => q[none],
    # Verbosity level when using the "tar" command
    #
    # Valid options:
    # - none              Quiet
    # - v                 File names
    # - vv                Full listing
    'tar_verbosity' => q[none],
};
1;
__END__

# vim: syntax=perl cc=80 tw=79 ts=4 sw=4 sts=4 et sr
