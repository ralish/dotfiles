# CPANPLUS::Config
# https://metacpan.org/pod/CPANPLUS::Config
#
# Last reviewed release: v0.9916
# Default file path: ~/.cpanplus/User.pm

package CPANPLUS::Config::User;

use strict;
use warnings;

# Core module since Perl v5.9.5 (2007/07/07)
use IPC::Cmd qw[can_run run];

# Running on Windows?
my $IsWin = $^O eq 'MSWin32' ? 1 : 0;

# Executable paths
my $exe_editor_editor = can_run($ENV{'EDITOR'});
my $exe_editor_vi = can_run('vi');
my $exe_editor_visual = can_run($ENV{'VISUAL'});
my $exe_make = can_run('make');
my $exe_make_win32 = q[C:\\DevEnvs\\Perl\\c\\bin\\gmake.exe];
my $exe_pager = can_run($ENV{'PAGER'});
my $exe_pager_less = can_run('less');
my $exe_pager_more = can_run('more');
my $exe_perlwrapper = can_run('cpanp-run-perl');
my $exe_shell = $IsWin ? can_run($ENV{'COMSPEC'}) : can_run($ENV{'SHELL'});

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

sub setup {
    my $conf = shift;

    ###############
    ### Startup ###
    ###############

    # Display a random tip on startup
    $conf->set_conf( show_startup_tip => 0 );

    # List of directories to add to `@INC`
    $conf->set_conf( lib => [] );

    ###################
    ### Directories ###
    ###################

    # Build & state
    #
    # Overridden by the `PERL5_CPANPLUS_HOME` environment variable.
    $conf->set_conf( base => $IsWin ? qq[$ENV{USERPROFILE}\\.cpanplus] : qq[$ENV{HOME}/.cpanplus] );

    # Fetched archives
    #
    # If an empty string, a directory under the `base` directory will be used.
    $conf->set_conf( fetchdir => $IsWin ? q[D:\\Cache\\CPANPLUS\\sources] : qq[$ENV{HOME}/.cpanplus/sources] );

    # Extracted archives
    #
    # If an empty string, a directory under the `base` directory will be used.
    $conf->set_conf( extractdir => $IsWin ? q[D:\\Cache\\CPANPLUS\\build] : qq[$ENV{HOME}/.cpanplus/build] );

    #####################
    ### Interactivity ###
    #####################

    # Shell class to use in interactive mode
    $conf->set_conf( shell => 'CPANPLUS::Shell::Default' );

    # Path to the history file
    $conf->set_conf( histfile => $IsWin ? qq[$ENV{USERPROFILE}\\.cpanplus\\history] : qq[$ENV{HOME}/.cpanplus/history] );

    # Permit interactive prompts during builds
    $conf->set_conf( allow_build_interactivity => 1 );

    ###############
    ### Network ###
    ###############

    # List of CPAN mirrors to use
    $conf->set_conf( hosts => [
        $IsWin ? {
            'scheme' => 'https',
            'host' => 'www.strawberryperl.com',
            'path' => '/'
        } : {},
        {
            'scheme' => 'https',
            'host' => 'www.cpan.org',
            'path' => '/'
        }
    ] );

    # Email address used for:
    # - Anonymous FTP access
    # - `FROM` email address
    $conf->set_conf( email => 'cpanplus@metacpan.org' );

    # Use FTP passive mode
    $conf->set_conf( passive => 1 );

    # Duration to wait for a fetch request to complete (secs)
    $conf->set_conf( timeout => 300 );

    ################
    ### Security ###
    ################

    # Check the SHA-256 hash of fetched archives (requires `Digest::SHA`)
    $conf->set_conf( md5 => 1 );

    # Verify signatures of signed packages (requires `gpg` or `Crypt::OpenPGP`)
    $conf->set_conf( signature => 1 );

    #######################
    ### Build & install ###
    #######################

    # Policy for handling build prerequisites
    #
    # Valid options:
    # - 0       Do not install
    # - 1       Install
    # - 2       Ask
    # - 3       Ignore
    $conf->set_conf( prereqs => 1 );

    # Permit unresolveable module prerequisites
    $conf->set_conf( allow_unknown_prereqs => 0 );

    # Prefer `Makefile.pl` over `Build.pl` (if both are present)
    $conf->set_conf( prefer_makefile => !!1 );

    # Arguments to pass to `Makefile.pl`
    $conf->set_conf( makemakerflags => $IsWin ? q[] : q[INSTALLDIRS=site] );
    # Arguments to pass to `make`
    $conf->set_conf( makeflags => qq[-j${num_procs}] );

    # Arguments to pass to `Build.pl`
    $conf->set_conf( buildflags => $IsWin ? q[] : q[--installdirs site] );

    # Default distribution type when building packages (see `CPANPLUS::Dist`)
    #
    # If an empty string, no package building software will be used.
    $conf->set_conf( dist_type => '' );

    # Skip running tests before module installations
    $conf->set_conf( skiptest => 0 );
    # Send test results from module installations
    $conf->set_conf( cpantest => 0 );
    # Email server to use when sending test results
    #
    # If an empty string, will use the system settings.
    $conf->set_conf( cpantest_mx => '' );
    # Dictionary passed to the `Test::Reporter` constructor
    $conf->set_conf( cpantest_reporter_args => {} );

    # Forces operations to succeed where possible
    #
    # This includes overwriting existing files, installing modules which fail
    # tests, and more. Obviously, it's potentially dangerous.
    $conf->set_conf( force => 0 );

    ################
    ### Programs ###
    ################

    # Paths to external programs
    $conf->set_program( editor => defined $exe_editor_editor ? $exe_editor_editor :
                                      defined $exe_editor_visual ? $exe_editor_visual :
                                      defined $exe_editor_vi ? $exe_editor_vi : q[] );
    $conf->set_program( make => $IsWin && -x $exe_make_win32 ? $exe_make_win32 :
                                    defined $exe_make ? $exe_make : q[] );
    $conf->set_program( pager => defined $exe_pager ? $exe_pager :
                                     defined $exe_pager_less ? $exe_pager_less :
                                     defined $exe_pager_more ? $exe_pager_more : q[] );
    $conf->set_program( shell => defined $exe_shell ? $exe_shell : q[] );
    $conf->set_program( sudo => undef );
    $conf->set_program( perlwrapper => defined $exe_perlwrapper ? $exe_perlwrapper : q[] );

    # Prefer external programs (instead of `Compress::Zlib`)
    $conf->set_conf( prefer_bin => 0 );

    #############
    ### Cache ###
    #############

    # Cache metadata (requires `Storable`)
    $conf->set_conf( storable => 1 );

    # Flush temporary data after every operation
    $conf->set_conf( flush => 1 );

    #################
    ### Internals ###
    #################

    # Source engine class (see `CPANPLUS::Internals::Source`)
    $conf->set_conf( source_engine => 'CPANPLUS::Internals::Source::Memory' );

    # Permit custom sources (see `CPANPLUS::Backend`)
    $conf->set_conf( enable_custom_sources => 1 );

    # Skip updating source files
    $conf->set_conf( no_update => 0 );

    ###############
    ### Logging ###
    ###############

    # Verbose output (recommended)
    #
    # Overridden by the `PERL5_CPANPLUS_VERBOSE` environment variable.
    $conf->set_conf( verbose => 1 );

    # Debug output
    $conf->set_conf( debug => 0 );

    # Write install logs for module installations
    $conf->set_conf( write_install_logs => 1 );

    return 1;
}
1;

# vim: syntax=perl cc=80 tw=79 ts=4 sw=4 sts=4 et sr
