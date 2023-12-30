# Assuming the Strawberry Perl distribution, you may want to install:
# - Log::Log4perl
# - Module::Signature

$CPAN::Config = {
    # Build & cache directory
    'cpan_home' => q[D:\\Cache\\CPAN],
    # Source directory
    'keep_source_where' => q[D:\\Cache\\CPAN\\sources],
    # Build directory
    'build_dir' => q[D:\\Cache\\CPAN\\build],
    # Preferences directory
    'prefs_dir' => q[D:\\Cache\\CPAN\\prefs],

    # Paths to external programs
    'applypatch' => q[],
    'bzip2' => q[],
    'curl' => qq[$ENV{SystemRoot}\\System32\\curl.exe],
    'gpg' => q[],
    'gzip' => q[],
    'make' => q[C:\\DevEnvs\\Perl\\c\\bin\\gmake.exe],
    'pager' => q[],
    'patch' => q[C:\\DevEnvs\\Perl\\c\\bin\\patch.exe],
    'shell' => qq[$ENV{SystemRoot}\\System32\\cmd.exe],
    'tar' => qq[$ENV{SystemRoot}\\System32\\tar.exe],
    'unzip' => q[],
    'wget' => q[],

    # Prefer external tar command (instead of Archive::Tar)
    'prefer_external_tar' => q[0],

    # Proxy configuration
    'ftp_proxy' => q[],
    'http_proxy' => q[],
    'no_proxy' => q[],

    # Always use FTP passive mode
    'ftp_passive' => q[1],

    # Suppress startup greeting message
    'inhibit_startup_message' => q[0],

    # Automatically save configuration changes
    #
    # Note: Enabling will result in CPAN removing all comments, formatting, and
    #       ordering of statements whenever it saves an updated configuration.
    'auto_commit' => q[0],

    # Terminal uses ISO-8859-1 character set (aka. Latin-1)
    #
    # Note: Disabling is equivalent to enabling UTF-8.
    'term_is_latin' => q[0],

    # Display the current command number in the prompt
    'commandnumber_in_prompt' => q[0],

    # Enable terminal ornaments (requires Term::ReadLine)
    'term_ornaments' => q[1],

    # Enable colourised terminal output (requires Term::ANSIColor)
    #
    # Note: Windows requires Win32::Console::ANSI.
    'colorize_output' => q[1],
    # Colour for normal output
    'colorize_print' => q[bold green],
    # Colour for warnings
    'colorize_warn' => q[bold red],
    # Colour for debugging messages
    'colorize_debug' => q[black on_cyan],

    # Path to the history file (requires Term::ReadLine)
    'histfile' => qq[$ENV{USERPROFILE}\\.cpan\\histfile],
    # Maximum number of commands in the history
    'histsize' => q[1000],

    # If urllist has not been configured, permit connecting to the built-in
    # default sites without asking (the default is to ask once per session).
    'connect_to_internet_ok' => q[1],
    # List of CPAN mirrors to use
    'urllist' => [q[https://www.cpan.org/]],
    # Always use the official CPAN site for downloads. HTTPS will be preferenced
    # with HTTP fallback if it cannot be used (e.g. missing dependencies). Usage
    # of HTTP will emit a warning. Enabling this option will ignore any urllist.
    'pushy_https' => q[1],
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
    'makepl_arg' => q[],
    # Arguments to pass to "make"
    'make_arg' => q[],
    # "make" command to run when running "make install"
    'make_install_make_command' => q[C:\\DevEnvs\\Perl\\c\\bin\\gmake.exe],
    # Arguments to pass to "make install"
    'make_install_arg' => q[],

    # Arguments to pass to Build.pl
    'mbuildpl_arg' => q[],
    # Arguments to pass to ".\Build"
    'mbuild_arg' => q[],
    # Arguments to pass to ".\Build install"
    'mbuild_install_arg' => q[],

    # Generate test reports (requires CPAN::Reporter)
    'test_report' => q[0],
    # Skip tests if a matching distribution passed
    'trust_test_report_history' => q[0],

    # Permit installation of outdated distributions
    #
    # Note: Any option other than "yes" requires CPAN::DistnameInfo.
    #
    # Valid options: yes, no, ask/yes, ask/no
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
    # Note: Not used when use_sqlite is on and SQLite is running.
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
    # Verbosity level when using the tar command
    #
    # Valid options:
    # - none              Quiet
    # - v                 File names
    # - vv                Full listing
    'tar_verbosity' => q[none],
};
1;
__END__
