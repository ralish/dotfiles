# CPAN configuration
# https://metacpan.org/pod/CPAN
#
# Last reviewed release: v2.38
# Default file path: ~/.cpan/CPAN/MyConfig.pm
#
# On Debian (or derived) distributions you may want to install:
# - libcpan-distnameinfo-perl (CPAN::DistnameInfo)
# - libcpan-sqlite-perl (CPAN::SQLite) [Many deps]
# - liblog-log4perl-perl (Log::Log4perl) [Many deps]
# - libmodule-build-perl (Module::Build) [Many deps]
# - libmodule-signature-perl (Module::Signature)
# - libterm-readline-gnu-perl (Term:ReadLine::Gnu)
# - libyaml-libyaml-perl (YAML::XS)
#
# On Windows using Strawberry Perl you may want to install:
# - Log::Log4perl
# - Module::Signature (but see the "check_sigs" setting)

use strict;
use warnings;

# Core module since Perl v5.9.5 (2007/07/07)
use IPC::Cmd qw[can_run run];

# Running on Windows?
my $IsWin = $^O eq 'MSWin32' ? 1 : 0;

# Executable paths
my $exe_applypatch = can_run('applypatch');
my $exe_bzip2 = can_run('bzip2');
my $exe_curl = can_run('curl');
my $exe_ftp = can_run('ftp');
my $exe_gpg = can_run('gpg');
my $exe_gzip = can_run('gzip');
my $exe_lynx = can_run('lynx');
my $exe_make = can_run('make');
my $exe_make_win32 = q[C:\\DevEnvs\\Perl\\c\\bin\\gmake.exe];
my $exe_ncftp = can_run('ncftp');
my $exe_ncftpget = can_run('ncftpget');
my $exe_pager = can_run($ENV{'PAGER'});
my $exe_pager_less = can_run('less');
my $exe_pager_more = can_run('more');
my $exe_patch = can_run('patch');
my $exe_patch_win32 = q[C:\\DevEnvs\\Perl\\c\\bin\\patch.exe];
my $exe_shell = $IsWin ? can_run($ENV{'COMSPEC'}) : can_run($ENV{'SHELL'});
my $exe_tar = can_run('tar');
my $exe_unzip = can_run('unzip');
my $exe_wget = can_run('wget');

# Determine number of processors
my $num_procs = 1;
if ($IsWin) {
    $num_procs = $ENV{'NUMBER_OF_PROCESSORS'};
} elsif ($^O eq 'linux') {
    my $exe_nproc = can_run('nproc');
    if (defined $exe_nproc) {
        run( command => $exe_nproc,
             verbose => 0,
             buffer => \$num_procs,
             timeout => 3 );
        chomp($num_procs);
    }
}

$CPAN::Config = {
    ###############
    ### Startup ###
    ###############

    # Suppress startup greeting message
    'inhibit_startup_message' => q[0],

    # List of enabled plugins (see CPAN::Plugin)
    'plugin_list' => [],

    # List of modules to skip loading (via CPAN::has_inst())
    'dontload_list' => [],

    ###################
    ### Directories ###
    ###################

    # Build & cache
    'cpan_home'         => $IsWin ? q[D:\\Cache\\CPAN] : qq[$ENV{HOME}/.cpan],
    # Sources
    'keep_source_where' => $IsWin ? q[D:\\Cache\\CPAN\\sources] : qq[$ENV{HOME}/.cpan/sources],
    # Patches
    'patches_dir'       => q[],
    # Build
    'build_dir'         => $IsWin ? q[D:\\Cache\\CPAN\\build] : qq[$ENV{HOME}/.cpan/build],
    # Preferences
    'prefs_dir'         => $IsWin ? qq[$ENV{USERPROFILE}\\.cpan\\prefs] : qq[$ENV{HOME}/.cpan/prefs],

    #####################
    ### Interactivity ###
    #####################

    # Terminal uses ISO-8859-1 character set (aka. Latin-1)
    #
    # Disabling is equivalent to enabling UTF-8.
    'term_is_latin' => q[0],

    # Enable terminal ornaments (requires Term::ReadLine)
    'term_ornaments' => q[1],

    # Enable colourised terminal output (requires Term::ANSIColor)
    #
    # Windows also requires Win32::Console::ANSI.
    'colorize_output' => q[1],
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

    # Use default values for interactive prompts during builds
    'use_prompt_default' => q[0],

    # Automatically save configuration changes
    #
    # Be aware that CPAN will remove all comments, formatting, and ordering of
    # statements when saving the configuration.
    'auto_commit' => q[0],

    ###############
    ### Network ###
    ###############

    # If urllist has not been configured, permit connecting to the built-in
    # default sites without asking (the default is to ask once per session).
    'connect_to_internet_ok' => q[1],

    # Always use the official CPAN site for downloads
    #
    # HTTPS will be preferenced with fallback to HTTP if it cannot be used
    # (e.g. missing dependencies), in which case a warning will be emitted.
    # Enabling this option will ignore any "urllist".
    'pushy_https' => q[1],

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

    # List of CPAN WAIT servers to use
    'wait_list' => [],

    # Username and optional password for CPAN server
    'username' => q[],
    'password' => q[],

    # Use FTP passive mode
    'ftp_passive' => q[1],
    # Duration to retain download statistics (days)
    'ftpstats_period' => q[14],
    # Number of items to keep in the download statistics
    'ftpstats_size' => q[100],

    # Address of HTTP and/or FTP proxy
    'http_proxy' => q[],
    'ftp_proxy' => q[],
    # List of addresses to bypass proxy (comma-separated)
    'no_proxy' => q[],
    # Username and optional password for proxy server
    'proxy_user' => q[],
    'proxy_pass' => q[],

    ################
    ### Security ###
    ################

    # Verify module signatures (requires Module::Signature and gpg)
    #
    # Disabled as apart from the dependency requirements it also doesn't work
    # on Windows due to CPAN hardcoding the temporary directory path to "/tmp".
    # This path will be resolved to "C:\tmp" and if it doesn't exist (which it
    # typically won't) then creating the temporary file will fail. Verified to
    # still be broken as of CPAN v2.38.
    'check_sigs' => $IsWin ? q[0] : q[1],

    #######################
    ### Build & install ###
    #######################

    # Include recommended module dependencies
    'recommends_policy' => q[1],
    # Include suggested module dependencies
    'suggests_policy' => q[0],

    # Policy for handling build prerequisites
    #
    # Valid values:
    # - follow      Automatically build
    # - ask         Ask for confirmation
    # - ignore      Ignore dependencies
    'prerequisites_policy' => q[follow],
    # Policy for installing build prerequisites
    #
    # Valid values: yes, no, ask/yes, ask/no
    'build_requires_install_policy' => q[ask/no],

    # Preferred installer module
    #
    # Valid values:
    # - EUMM        ExtUtils::MakeMaker (Makefile.pl)
    # - MB          Module::Build (Build.pl)
    # - RAND        Randomised
    'prefer_installer' => q[MB],

    # Arguments to pass to Makefile.pl
    'makepl_arg' => $IsWin ? q[] : q[INSTALLDIRS=site],
    # Arguments to pass to "make"
    'make_arg' => qq[-j${num_procs}],
    # Command to run instead of "make" when running "make install"
    'make_install_make_command' => $IsWin && -x $exe_make_win32 ?
                                       $exe_make_win32 :
                                       defined $exe_make ? $exe_make : q[],
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
    # Valid values: yes, no, ask/yes, ask/no
    #
    # Any option other than "yes" requires CPAN::DistnameInfo.
    'allow_installing_outdated_dists' => q[ask/no],
    # Permit installation of module downgrades
    #
    # Valid values: yes, no, ask/yes, ask/no
    'allow_installing_module_downgrades' => q[ask/no],

    # Show module and distribution upload dates
    'show_upload_date' => q[1],
    # Print modules with a version number of zero
    'show_zero_versions' => q[0],
    # Print modules that do not have a version
    'show_unparsable_versions' => q[0],

    # Halt on the first failed build target or dependency
    #
    # If enabled, this seems to have the annoying side-effect of aborting an
    # install if permanently installing a build or test only dependency is
    # declined, as set with the "build_requires_install_policy" setting.
    'halt_on_failure' => q[0],
    # Timeout for parsing $VERSION from a module (secs)
    'version_timeout' => q[15],
    # Timeout to kill Makefile.pl and Build.pl processes (secs)
    'inactivity_timeout' => q[0],

    # Store build state for reuse between sessions
    'build_dir_reuse' => q[1],
    # Cleanup build directories after successful install
    'cleanup_after_install' => q[1],

    ################
    ### Programs ###
    ################

    # Paths to external programs
    #
    # Entries marked "space" use a Perl module when set to a space.
    'applypatch' => defined $exe_applypatch ? $exe_applypatch : q[],
    'bzip2'      => defined $exe_bzip2 ? $exe_bzip2 : q[ ], # space
    'curl'       => defined $exe_curl ? $exe_curl : q[],
    'ftp'        => defined $exe_ftp ? $exe_ftp : q[],
    'gpg'        => defined $exe_gpg ? $exe_gpg : q[],
    'gzip'       => defined $exe_gzip ? $exe_gzip : q[ ], # space
    'lynx'       => defined $exe_lynx ? $exe_lynx : q[],
    'make'       => $IsWin && -x $exe_make_win32 ? $exe_make_win32 :
                        defined $exe_make ? $exe_make : q[],
    'ncftp'      => defined $exe_ncftp ? $exe_ncftp : q[],
    'ncftpget'   => defined $exe_ncftpget ? $exe_ncftpget : q[],
    'pager'      => defined $exe_pager ? $exe_pager :
                        defined $exe_pager_less ? $exe_pager_less :
                        defined $exe_pager_more ? $exe_pager_more : q[],
    'patch'      => $IsWin && -x $exe_patch_win32 ? $exe_patch_win32 :
                        defined $exe_patch ? $exe_patch : q[],
    'shell'      => defined $exe_shell ? $exe_shell : q[],
    'tar'        => defined $exe_tar ? $exe_tar : q[ ], # space
    'unzip'      => defined $exe_unzip ? $exe_unzip : q[],
    'wget'       => defined $exe_wget ? $exe_wget : q[],

    # Character to use for quoting external commands
    #
    # Defaults to a single quote on all platforms except Windows, which uses a
    # double quote. Setting it to a space will disable quoting (bad idea!).
    #'commands_quote' => q[],

    # Prefer external "tar" command (instead of Archive::Tar)
    'prefer_external_tar' => $IsWin ? q[0] : q[1],

    #############
    ### Cache ###
    #############

    # Validity period of downloaded indexes (days)
    'index_expire' => q[1],

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
    # Valid values:
    # - atstart     On start
    # - atexit      On exit
    # - never       Never scan
    'scan_cache' => q[atstart],

    #################
    ### Internals ###
    #################

    # Method for obtaining the current working directory
    #
    # Valid values:
    # - cwd             Cwd::cwd
    # - getcwd          Cwd::getcwd
    # - fastcwd         Cwd::fastcwd
    # - getdcwd         Cwd::getdcwd
    'getcwd' => q[cwd],

    # Preferred YAML implementation
    #
    # Valid values:
    # - YAML
    # - YAML::Syck      Requires a C compiler
    # - YAML::XS        Requires a C compiler
    'yaml_module' => q[YAML::XS],
    # Permit deserialising code in YAML
    'yaml_load_code' => q[0],

    ###############
    ### Logging ###
    ###############

    # Report loading of modules
    #
    # Valid values:
    # - none        Quiet
    # - v           Module name and version
    'load_module_verbosity' => q[v],

    # Report extending of @INC via PERL5LIB
    #
    # Valid values:
    # - none        Quiet
    # - v           List of added directories
    'perl5lib_verbosity' => q[none],

    # Verbosity level when using the "tar" command
    #
    # Valid values:
    # - none        Quiet
    # - v           File names
    # - vv          Full listing
    'tar_verbosity' => q[none],
};
1;

# vim: syntax=perl cc=80 tw=79 ts=4 sw=4 sts=4 et sr
