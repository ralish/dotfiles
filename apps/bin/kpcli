#!/usr/bin/perl

###########################################################################
#
# kpcli - KeePass Command Line Interface
#
# Author: Lester Hightower <hightowe at cpan dot org>
#
# This program was inspired by "kedpm -c" and resulted despite illness
# (or more likely because of it) over the USA Thanksgiving holiday in
# late November of 2010. As a long-time user of the Ked Password Manager
# I really missed a command line interface after getting an Android cell
# phone and switching to KeePass, so that I could access my password
# database on my phone. This program scratches that itch.
#
###########################################################################

# The required perl modules
use strict;                                   # core
use version;                                  # core
use FileHandle;                               # core
use Getopt::Long;                             # core
use File::Basename;                           # core
use Digest::file;                             # core
use Digest::SHA qw(sha256);                   # core
use Data::Dumper qw(Dumper);                  # core
use Term::ReadLine;                           # core
use Term::ANSIColor;                          # core
use Carp qw(longmess);                        # core
use English qw(-no_match_vars);               # core
use Time::HiRes qw(gettimeofday tv_interval); # core
use POSIX;                   # core, required for unsafe signal handling
use Crypt::Rijndael;         # non-core, libcrypt-rijndael-perl on Ubuntu
use Sort::Naturally;         # non-core, libsort-naturally-perl on Ubuntu
use Term::ReadKey;           # non-core, libterm-readkey-perl on Ubuntu
use Term::ShellUI;           # non-core, libterm-shellui-perl on Ubuntu
                             #  - add Term::ReadLine::Gnu for cli history
use File::KeePass 0.03;      # non-core, libfile-keepass-perl on Ubuntu
                             #  - >=v0.03 needed due critical bug fixes
# Pull in optional perl modules with run-time loading
my %OPTIONAL_PM=();
# Data::Password is needed for the pwck command (check password quality).
if (runtime_load_module(\%OPTIONAL_PM,'Data::Password',[qw(IsBadPassword)])) {
  no warnings 'once';
  $Data::Password::MINLEN = 8;
  $Data::Password::MAXLEN = 0;
}
# Capture::Tiny is needed to safely optionally-load Clipboard.
# Clipboard is needed by the clipboard copy commands (xw, xu, xp, and xx).
if (runtime_load_module(\%OPTIONAL_PM,'Capture::Tiny',[qw(capture)])) {
  # Clipboard tests its dependencies at import() and writes warnings to STDERR.
  # Tiny::Capture is used to catch those warnings and we silently hold them
  # until and unless someone tries to use dependant functions.
  my ($out, $err, @result) = capture(
		sub { runtime_load_module(\%OPTIONAL_PM,'Clipboard',undef); } );
  if (length($err)) {
    # Cleanup the error message for for better viewing by the user
    $err =~ s/^\s+//g; $err =~ s/\s+$//g; $err =~ s/^(.*)$/ > $1/mg;
    $OPTIONAL_PM{'Clipboard'}->{error} = $err;
  }
} else {
  # If we didn't get Capture::Tiny, also mark Clipboard as not loaded.
  $OPTIONAL_PM{'Clipboard'}->{loaded} = 0;
}
# Win32::Console::ANSI is needed to emulate ANSI colors on Windows
if (lc($OSNAME) =~ m/^mswin/) {
  if (! runtime_load_module(\%OPTIONAL_PM,'Win32::Console::ANSI',undef)) {
    # If we don't have Win32::Console::ANSI then we want to override
    # &main::color() and colored() from Term::ANSIColor with NOOPs.
    no strict 'refs';
    *color = sub { my $color = shift @_; return ''; };
    *colored = sub { my $color = shift @_; my $text=shift @_; return $text; };
  }
}

$|=1; # flush immediately after writes or prints to STDOUT

my $DEBUG=0;
$Data::Dumper::Useqq = 1;    # Have Dumper escape special chars (like \0)
my $DEFAULT_ENTRY_ICON = 0;  # In keepassx, icon 0 is a golden key
my $DEfAULT_GROUP_ICON = 49; # In keepassx, icon 49 is an opened file folder
my $FOUND_DIR = '_found';    # The find command's results go in /_found/

# Application name and version
my $APP_NAME = basename($0);  $APP_NAME =~ s/\.(pl|exe)$//;
my $VERSION = "2.4";

our $HISTORY_FILE = ""; # Gets set in the MyGetOpts() function
my $opts=MyGetOpts();   # Will only return with options we think we can use

# Setup our Term::ShellUI object
my $term = new Term::ShellUI(
    app => $APP_NAME,
    term => get_readline_term(\%OPTIONAL_PM, $APP_NAME),
    history_file => $HISTORY_FILE,
    keep_quotes => 0,
    commands => {
         #"" => { args => sub { shift->complete_history(@_) } },
         "history" => { desc => "Prints the command history",
            doc => "\nSpecify a number to list the last N lines of history.\n" .
            "Pass -c to clear the command history.\n" .
            "Pass -d NUM to delete a single item.\n",
            args => "[-c] [-d] [number]",
            method => sub { shift->history_call(@_) },
	    exclude_from_history => 1,
         },
         "ver" => {
             desc => "Print the version of this program",
             doc => "\n" .
		"Add the -v option to get an inventory of the versions\n" .
		"of the various dependencies being used. Please provide\n" .
		"that information in any bug reports filed.\n" .
		"",
             method => \&cli_version,
             minargs => 0, maxargs => 1,
	     exclude_from_history => 1,
         },
         "version" => { alias => "ver",
		exclude_from_completion=>1, exclude_from_history => 1,},
         "vers" => {
             desc => "Same as \"ver -v\"",
             minargs => 0, maxargs => 0,
             method => sub { cli_version(shift, { args => ['-v'] }); },
		exclude_from_completion=>1, exclude_from_history => 1,
         },
         "versions" => { alias => "vers",
		exclude_from_completion=>1, exclude_from_history => 1,},
         "help" => {
             desc => "Print helpful information",
             args => sub { shift->help_args(undef, @_); },
             method => sub { my_help_call(@_); },
	     exclude_from_history => 1,
             #method => sub { shift->help_call(undef, @_); }
         },
         "h" => { alias => "help",
		exclude_from_completion=>1, exclude_from_history => 1,},
         "?" => { alias => "help",
		exclude_from_completion=>1, exclude_from_history => 1,},
         "cl" => {
             desc => "Change directory and list entries (cd+ls)",
             doc => "\n" .
		"Change the pwd to an absolute or relative path\n" .
		"and list the entries there. This is a useful way\n" .
		"to quickly navigate to a path and have the entries\n" .
		"listed in preparation to run the show command.\n",
             maxargs => 1,
             args => \&complete_groups,
             method => sub { if(cli_cd(@_) == 0) { cli_ls() } },
         },
	 "cls" => {
	     desc => 'Clear screen ("clear" command also works)',
	     doc  => "\n" .
		"Clear the screen, which is useful when guests arrive.\n",
	     maxargs => 0,
	     method => sub { print "\033[2J\033[0;0H"; },
	     exclude_from_history => 1,
	 },
         "clear" => { alias => "cls", exclude_from_history => 1, },
         "cd" => {
             desc => "Change directory (path to a group)",
             doc => "\n" .
		"Change the pwd to an absolute or relative path.\n" .
		"Slashes in names are escaped with backslashes:\n" .
		"(i.e. \"cd /personal/Comcast\\/Xfinity\").\n",
             maxargs => 1,
             args => \&complete_groups,
             method => \&cli_cd,
         },
         "chdir" => { alias => 'cd' },
         "saveas" => {
             desc => "Save to a specific filename " .
				"(saveas <file.kdb> [<file.key>])",
             minargs => 1, maxargs => 2,
             args => [\&Term::ShellUI::complete_files,
					\&Term::ShellUI::complete_files],
             proc => \&cli_saveas,
         },
         "export" => {
             desc => "Export entries to a new KeePass DB " .
				"(export <file.kdb> [<file.key>])",
             doc => "\n" .
		"Use this command to export the full tree of groups\n" .
		"and entries to another KeePass database file on disk,\n" .
		"starting at your current path (pwd).\n" .
		"\n" .
		"This is also a \"safer\" way to change your database\n" .
		"password. Export from /, verify that the new file is\n" .
		"good, and then remove your original file.\n",
             minargs => 1, maxargs => 2,
             args => [\&Term::ShellUI::complete_files,
					\&Term::ShellUI::complete_files],
             proc => \&cli_export,
         },
         "import" => {
             desc => "Import another KeePass DB " .
				"(import <file.kdb> <path> [<file.key>])",
             doc => "\n" .
		"Use this command to import the entire KeePass DB\n" .
		"specified by <file.kdb> into a new group at <path>.\n",
             minargs => 2, maxargs => 3,
             args => [\&Term::ShellUI::complete_files,\&complete_groups,
					\&Term::ShellUI::complete_files],
             proc => \&cli_import,
         },
         "open" => {
             desc => "Open a KeePass database file " .
				"(open <file.kdb> [<file.key>])",
             minargs => 1, maxargs => 2,
             args => [\&Term::ShellUI::complete_files,
					\&Term::ShellUI::complete_files],
             proc => \&cli_open,
         },
         "mkdir" => {
             desc => "Create a new group (mkdir <group_name>)",
             minargs => 1, maxargs => 1,
             args => \&complete_groups,
             method => \&cli_mkdir,
         },
         "rmdir" => {
             desc => "Delete a group (rmdir <group_name>)",
             minargs => 1, maxargs => 1,
             args => \&complete_groups,
             method => \&cli_rmdir,
         },
         "ls" => {
             desc => "Lists entries in pwd or in the specified path",
             minargs => 0, maxargs => 99,
             args => \&complete_groups,
             method => \&cli_ls,
         },
         "new" => {
             desc => "Create a new entry: new <optional path&|title>",
             doc => "\n" .
		"The new command is used to create a new entry.\n" .
		"\n" .
		"Usage is straightforward. For password generation, the\n" .
		"\"g\" method produces a string of random characters while\n" .
		"the \"w\" method creates a 4-word string inspired by\n" .
		"\"correct horse battery staple\" (http://xkcd.com/936/)\n" .
		"",
             minargs => 0, maxargs => 1,
             args => [\&complete_groups],
             method => \&cli_new,
         },
         "rm" => {
             desc => "Remove an entry: rm <path to entry|entry number>",
             minargs => 1, maxargs => 1,
             args => \&complete_groups_and_entries,
             method => \&cli_rm,
         },
         "xu" => {
             desc => "Copy username to clipboard: xu <entry path|number>",
             minargs => 1, maxargs => 1,
             args => \&complete_groups_and_entries,
             method => sub { cli_xN('xu', @_); }
         },
         "xw" => {
             desc => "Copy URL (www) to clipboard: xw <entry path|number>",
             minargs => 1, maxargs => 1,
             args => \&complete_groups_and_entries,
             method => sub { cli_xN('xw', @_); }
         },
         "xp" => {
             desc => "Copy password to clipboard: xp <entry path|number>",
             minargs => 1, maxargs => 1,
             args => \&complete_groups_and_entries,
             method => sub { cli_xN('xp', @_); }
         },
         "xx" => {
             desc => "Clear the clipboard: xx",
             minargs => 0, maxargs => 0,
             method => sub { cli_xN('xx'); }
         },
         "pwck" => {
             desc => "Check password quality: pwck <entry|group>",
             doc => "\n" .
		"The pwck command test password quality for entries.\n" .
		"You can check an individual entry or all entries inside\n" .
		"of a group, recursively. To check every password in your\n" .
		"database, use: pwck /\n" .
		"",
             minargs => 1, maxargs => 1,
             args => \&complete_groups_and_entries,
             method => \&cli_pwck,
         },
         "stats" => {
             desc => "Prints statistics about the open KeePass file",
             method => \&cli_stats,
         },
         "show" => {
             desc => "Show an entry: show [-f] [-a] <entry path|entry number>",
             doc => "\n" .
		"The show command tries to intelligently determine\n" .
		"what you want to see and to make it easy to display.\n" .
		"Show can take a path to an entry as its argument or\n" .
		"an entry number as shown by the ls command.\n" .
		"\n" .
		"When using entry numbers, they will refer to the last\n" .
		"path when an ls was performed or pwd if ls has not\n" .
		"yet been run.\n" .
		"\n" .
		"By default, passwords are \"hidden\" by being displayed as\n" .
		"\"red on red\" where they can be copied to the clip board\n" .
		"but not seen. Provide the -f option to show passwords.\n" .
		"Use the -a option to see create and modified times, and\n" .
		"the index of the icon set for the entry.\n" .
		"",
             minargs => 1, maxargs => 3,
             args => \&complete_groups_and_entries,
             method => \&cli_show,
         },
         "edit" => {
             desc => "Edit an entry: edit <path to entry|entry number>",
             doc => "\n" .
		"The edit command is used to modify an entry.\n" .
		"\n" .
		"Usage is straightforward. For password generation, the\n" .
		"\"g\" method produces a string of random characters while\n" .
		"the \"w\" method creates a 4-word string inspired by\n" .
		"\"correct horse battery staple\" (http://xkcd.com/936/)\n" .
		"",
             minargs => 1, maxargs => 1,
             args => \&complete_groups_and_entries,
             method => \&cli_edit,
         },
         "mv" => {
             desc => "Move an entry: mv <path to entry> <path to group>",
             minargs => 2, maxargs => 2,
             args => [\&complete_groups_and_entries, \&complete_groups],
             method => \&cli_mv,
         },
         "rename" => {
             desc => "Rename a group: rename <path to group>",
             minargs => 1, maxargs => 1,
             args => \&complete_groups,
             method => \&cli_rename,
         },
         "save" => {
             desc => "Save the database to disk",
             minargs => 0, maxargs => 0, args => "",
             method => \&cli_save,
         },
         "close" => {
             desc => "Close the currently opened database",
             minargs => 0, maxargs => 0, args => "",
             method => \&cli_close,
         },
         "find" => {
             desc => "Finds entries by Title",
             doc => "\n" .
		"Searches for entries with the given search term\n" .
		"in their title and places matches into \"/$FOUND_DIR/\".\n" .
		"\n" .
		"Add -a to search data fields beyond just the title.\n",
             minargs => 1, maxargs => 2, args => "<search string>",
             method => \&cli_find,
         },
         "pwd" => {
             desc => "Print the current working directory",
             maxargs => 0, proc => \&cli_pwd,
         },
         "icons" => {
             desc => "Change group or entry icons in the database",
             maxargs => 0, proc => \&cli_icons,
         },
         "quit" => {
             desc => "Quit this program (EOF and exit also work)",
             maxargs => 0, method => \&cli_quit,
	     exclude_from_history => 1,
         },
         "exit" => { alias => "quit", exclude_from_history => 1,}
       },
    );
$term->prompt(\&term_set_prompt);

# Seed our state global variable
our $state={
	'appname' => $APP_NAME,
	'term' => $term,
	'OPTIONAL_PM' => \%OPTIONAL_PM,
	'kdb_has_changed' => 0,
	'last_ls_path' => '',
	'put_master_passwd' => \&put_master_passwd,
	'get_master_passwd' => \&get_master_passwd,
	};
# If given --kdb=, open that file
if (length($opts->{kdb})) {
  my $err = open_kdb($opts->{kdb}, $opts->{key}); # Sets $state->{'kdb'}
  if (length($err)) {
    print "Error opening file: $err\n";
  }
} else {
  new_kdb($state);
}

# Enter the interative kpcli shell session
print "\n" .
	"KeePass CLI ($APP_NAME) v$VERSION is ready for operation.\n" .
	"Type 'help' for a description of available commands.\n" .
	"Type 'help <command>' for details on individual commands.\n";
if ($DEBUG) {print 'Using '.$term->{term}->ReadLine." for readline.\n"; }
if (! $DEBUG && $term->{term}->ReadLine ne 'Term::ReadLine::Gnu') {
  print color('yellow') . "\n" .
	"* NOTE: You are using " . $term->{term}->ReadLine . ".\n" .
	"  Term::ReadLine::Gnu will provide better functionality.\n" .
	color('clear');
}
# My patch made it into Term::ShellUI v0.9, but I still chose not to make
# this program demand >=0.9 and instead look for the add_eof_exit_hook()
# and use it if it exists and warn if not.
if (Term::ShellUI->can('add_eof_exit_hook')) {
  $term->add_eof_exit_hook(\&eof_exit_hook);
} else {
  warn "* Please upgrade Term::ShellUI to version 0.9 or newer.\n";
}
print "\n";

setup_signal_handling(); # Exactly what the name indicates...

$term->run();

exit;

############################################################################
############################################################################
############################################################################

sub open_kdb {
  my $file=shift @_;
  my $key_file=shift @_;
  our $state;

  # Make sure the file exists, is readable, and is a keepass file
  if (! -f $file) {
    return "File does not exist: $file";
  }
  if (! -r $file) {
    return "File is not readable: $file";
  }
  if (magic_file_type($file) ne 'keepass') {
    return "Does not appear to be a KeePass file: $file";
  }

  # Look for lock file and warn if it is found
  my $lock_file = $file . '.lock'; # KeePassX style
  if (-f $lock_file) {
    print color('bold yellow') .
	"WARNING:" .
	color('clear') . color('red') .
	       " A KeePassX-style lock file is in place for this file.\n" .
		"         It may be opened elsewhere." .
		" " . color('bold yellow') . "Be careful of saving!\n" .
	color('clear');
  } else {
    $state->{placed_lock_file} = $lock_file;
  }

  # Ask the user for the master password and then open the kdb
  my $master_pass=GetMasterPasswd();
  if (recent_sigint()) { return undef; } # Bail on SIGINT
  $state->{kdb} = File::KeePass->new;
  if (! eval { $state->{kdb}->load_db($file,
			composite_master_pass($master_pass, $key_file)) }) {
    die "Couldn't load the file $file: $@";
  }

  if ($state->{placed_lock_file}) {
    touch_file($state->{placed_lock_file});
  }

  $state->{kdb_file} = $file;
  $state->{key_file} = $key_file;
  $state->{put_master_passwd}($master_pass);
  $state->{kdb_has_changed}=0;
  $master_pass="\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

  # Build the %all_grp_paths_fwd and %all_grp_paths_rev structures
  refresh_state_all_paths();

  # Store the md5sum of the file so we can watch for unexpected changes
  $state->{kdb_file_md5} = Digest::file::digest_file_hex($file, "MD5");

  # Initialize our state into "/"
  cli_cd($term, {'args' => ["/"]});

  return ''; # If we return anything else it is an error message
}

# Called by Term::ShellUI to get the user prompt
sub term_set_prompt($$) {
  my $term=shift @_;
  my $raw_cmd=shift @_;
  our $state;

  my $app=$state->{appname};
  my $pwd=get_pwd();
  return "$app:$pwd> ";
}

# Walks through a tree of groups building a flat hash of NULL-separated
# paths to group IDs. Called on the root to build a full path tree.
sub build_all_group_paths {
  my $hash = shift @_;
  my $g = shift @_;
  my $root_path = shift @_ || [];

  foreach my $me (@{$g}) {
    my @path_to_me = @{$root_path};
    push @path_to_me, $me->{title};
    my $path=join("\0",@path_to_me);
    my $err_path = '/' . humanize_path($path);
    if (defined($hash->{$path})) {
      print color('bold yellow') .  "WARNING: " . color('clear') .
	color('red') . "Multiple groups titled: $err_path!\n" .
	color('red') . "This is unsupported and may cause data loss!\n" .
	color('clear');
    }
    $hash->{$path}=$me->{id};

    if (defined($me->{groups})) {
      build_all_group_paths($hash,$me->{groups},\@path_to_me);
    }
  }
  return (scalar(keys(%{$hash})));
}

# Walks through a tree of groups building a flat hash of NULL-separated
# paths to entry IDs. Called on the root to build a full path tree.
sub build_all_entry_paths {
  my $hash = shift @_;
  my $g = shift @_;
  my $root_path = shift @_ || [];

  my $red=color('red');

  foreach my $me (@{$g}) {
    my @path_to_me = @{$root_path};
    push @path_to_me, $me->{title};
    if (defined($me->{entries})) {
      foreach my $ent (@{$me->{entries}}) {
        my $path=join( "\0", (@path_to_me, $ent->{title}) );
        my $err_path = '/' . humanize_path($path);
        if ($ent->{title} eq '') {
          print color('bold yellow') . "WARNING: " . color('clear') .
		$red . "There is an entry with a blank title in $err_path!\n" .
		color('clear');
        }
        if (defined($hash->{$path}) &&
				$err_path !~ m/\/Backup\/|\/Meta-Info$/) {
          print color('bold yellow') . "WARNING: " . color('clear') .
		$red . "Multiple entries titled: $err_path!\n" .
		$red . "This is unsupported and may cause data loss!\n" .
		color('clear');
        }
        $hash->{$path}=$ent->{id};
      }
    }

    if (defined($me->{groups})) {
      build_all_entry_paths($hash,$me->{groups},\@path_to_me);
    }
  }
  return (scalar(keys(%{$hash})));
}

# Returns the current path the user is sitting in.
sub get_pwd {
  my $pwd='';
  if (defined($state->{all_grp_paths_rev}->{$state->{path}->{id}})) {
    $pwd=$state->{all_grp_paths_rev}->{$state->{path}->{id}};
  }
  $pwd =~ s%/%\\/%g;
  $pwd =~ s/\0/\//g;
  $pwd = '/' . $pwd;
return $pwd;
}

# Destroys our /_found group (where we place search results)
sub destroy_found {
  our $state;
  # Look for an exising /_found and kill it if it exists
  my $k=$state->{kdb};
  my $found_group=$k->find_group({level=>0,title=>$FOUND_DIR});
  if (defined($found_group)) {
    my @oldents = $k->find_entries({group=>$found_group->{id}});
    foreach my $ent (@oldents) {
      $k->delete_entry({id => $ent->{id}});
    }
    $k->delete_group({level=>0,title=>$FOUND_DIR});

    # Because we destroyed /_found we must refresh our $state paths
    refresh_state_all_paths();
  }
}

# Refreshes $state->{all_grp_paths_fwd} and $state->{all_grp_paths_rev}
sub refresh_state_all_paths() {
  our $state;

  # Build all group paths
  my %all_grp_paths_fwd;
  build_all_group_paths(\%all_grp_paths_fwd,$state->{kdb}->groups);
  my %all_grp_paths_rev = reverse %all_grp_paths_fwd;
  $state->{all_grp_paths_fwd}=\%all_grp_paths_fwd;
  $state->{all_grp_paths_rev}=\%all_grp_paths_rev;

  # Build all entry paths
  my %all_ent_paths_fwd;
  build_all_entry_paths(\%all_ent_paths_fwd,$state->{kdb}->groups);
  my %all_ent_paths_rev = reverse %all_ent_paths_fwd;
  $state->{all_ent_paths_fwd}=\%all_ent_paths_fwd;
  $state->{all_ent_paths_rev}=\%all_ent_paths_rev;
}

# Gathers the list of groups and entries for the pwd we're sitting in
sub get_current_groups_and_entries {
 return get_groups_and_entries(get_pwd());
}
sub get_groups_and_entries {
  my $path=shift @_;
  our $state;

  my $k=$state->{kdb};

  my @groups=();
  my @entries=();
  my $norm_path = normalize_path_string($path);
  if (length($norm_path) < 1) {
    @groups = $k->find_groups({level=>0});
    @entries = $k->find_entries({level => 0});
  } else {
    my $id=$state->{all_grp_paths_fwd}->{$norm_path};
    my ($this_grp,@trash) = $k->find_groups({id=>$id});
    if (defined($this_grp->{groups})) { # subgroups
      @groups = @{$this_grp->{groups}};
    }
    @entries = $k->find_entries({group_id => $id});
  }

  @groups = sort group_sort @groups;
  @entries = sort { ncmp($a->{title},$b->{title}); } @entries;

  return (\@groups,\@entries);
}

# This function takes a group ID and returns all of the child
# groups of that group, flattened.
sub all_child_groups_flattened {
  my $group_id=shift @_;
  our $state;

  my $k=$state->{kdb};
  my @groups=();
  my ($this_grp,@trash) = $k->find_groups({id=>$group_id});
  if (defined($this_grp->{groups})) { # subgroups
    @groups = @{$this_grp->{groups}};
    foreach my $child_group (@groups) {
      push @groups, all_child_groups_flattened($child_group->{id});
    }
  }

  return @groups;
}

# A function to properly sort groups by title
sub group_sort($$) {
  my $a=shift @_;
  my $b=shift @_;

  # _found at level 0 is a special case (from our find command).
  if ($a->{title} eq $FOUND_DIR && $a->{level} == 0) {
    return 1;
  } elsif ($b->{title} eq $FOUND_DIR && $b->{level} == 0) {
    return -1;
  # Backup at level=0 is a special case (KeePassX's Backup group).
  } elsif ($a->{title} eq 'Backup' && $a->{level} == 0) {
    return 1;
  } elsif ($b->{title} eq 'Backup' && $b->{level} == 0) {
    return -1;
  # Sort everything else naturally (Sort::Naturally::ncmp).
  } else {
    return ncmp($a->{title},$b->{title}); # Natural sort
  }


}

# -------------------------------------------------------------------------
# All of the cli_*() functions are below here
# -------------------------------------------------------------------------

# Checks passwords for their quality
sub cli_pwck {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  # If Data::Password is not avaiable we can't do this for the user
  if  (! $state->{OPTIONAL_PM}->{'Data::Password'}->{loaded}) {
    print "Error: pwck requires the Data::Password module.\n";
    return;
  }

  my @targets = ();
  my $target = $params->{args}->[0];
  # Start by trying to find a single entity with the paramter given.
  # If no single entity is found then try to find entities based on
  # assuming that the path given is a group.
  my $ent=find_target_entity_by_number_or_path($target);
  if (defined($ent)) {
    push @targets, $ent;
  } else {
    my @groups = ();
    my $target = normalize_path_string($target);
    if ($target eq '' || $target eq '.' && get_pwd() eq '/') {
      @groups = $state->{kdb}->find_groups({}); # Every group in the file!
    } elsif (defined($state->{all_grp_paths_fwd}->{$target})) {
      my $group_id = $state->{all_grp_paths_fwd}->{$target};
      my $this_grp = $state->{kdb}->find_group( { id => $group_id } );
      @groups = all_child_groups_flattened($group_id);
      push @groups, $this_grp; # Push this group onto its children
    }
    # Loop over each target group adding each of its entries as targets
    foreach my $group (@groups) {
      if (defined($group->{entries})) {
        push @targets, @{$group->{entries}};
      }
    }
  }

  # Test each password, collect the results and record empty passwords
  my %results=();
  my @empties = ();
  print "  working...\r";
  my @busy_chars = qw(\ | / -); my $i=0; my $in=10;
  foreach my $ent (@targets) {
    printf "%s\r", $busy_chars[int($i/$in)%($#busy_chars+1)] if (!($i++ % $in));
    my $pass = $state->{kdb}->locked_entry_password($ent);
    if (length($pass) == 0) {
      push @empties, $ent;
      $results{$ent->{id}} = '';
    } else {
      $results{$ent->{id}} = IsBadPassword($pass);
      if ($results{$ent->{id}} =~ m/dictionary word/i) {
        # IsBadPassword() reports dictionary words that it finds. I don't
        # like that from a security perspective so we change that here.
        $results{$ent->{id}} = "contains a dictionary word";
      }
    }
    # If the user hit ^C (SIGINT) then we need to stop
    if (recent_sigint()) {
       print "\r"; # Need to return to column 0 of the output line
       return 0;
    }
  }

  # If we only analyzed one password, return singular-style results
  if (scalar(@targets) == 1) {
    my $ent=$targets[0];
    if (length($results{$ent->{id}})) {
      print "Password concerns: " . $results{$ent->{id}} . "\n";
    } elsif (scalar(@empties) > 0) {
      print "Password field is empty.\n";
    } else {
      print "Password strength is good.\n";
    }
  } else {
  # If we analyzed more than one password, return multiple-style results
    my %problems=();
    foreach my $ent_id (keys %results) {
      if (length($results{$ent_id})) {
        $problems{$state->{all_ent_paths_rev}->{$ent_id}} = $ent_id;
      }
    }
    my $analyzed = scalar(@targets);
    my $problem_count = scalar(keys %problems);
    my $empty_count = scalar(@empties);
    print "$analyzed passwords analyzed, $empty_count blank, " .
					"$problem_count concerns found";
    if ($problem_count > 0) { print ":"; } else { print "."; }
    print "\n";
    foreach my $path (sort keys %problems) {
      print humanize_path($path) . ": $results{$problems{$path}}\n";
    }
  }

  return 0;
}

# Prints some statistics about the open KeePass file
sub cli_stats {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  # Group and entry counts
  my %stats;
  $stats{group_count} = scalar(keys(%{$state->{all_grp_paths_fwd}}));
  $stats{entry_count} = scalar(keys(%{$state->{all_ent_paths_fwd}}));

  # Password lengths
  my $k=$state->{kdb};
  my %password_lengths;
  print "  working...\r";
  my @busy_chars = qw(\ | / -); my $i=0; my $in=100;
  foreach my $ent_id (values(%{$state->{all_ent_paths_fwd}})) {
    printf "%s\r", $busy_chars[int($i/$in)%($#busy_chars+1)] if (!($i++ % $in));
    my $ent = $k->find_entry({id => $ent_id});
    my $pass_len = length($k->locked_entry_password($ent));
    if ($pass_len < 1) {
      $password_lengths{"0"}++;
    } elsif ($pass_len > 0 && $pass_len < 8) {
      $password_lengths{"1-7"}++;
    } elsif ($pass_len > 7 && $pass_len < 12) {
      $password_lengths{"8-11"}++;
    } elsif ($pass_len > 11 && $pass_len < 17) {
      $password_lengths{"12-16"}++;
    } elsif ($pass_len > 16 && $pass_len < 20) {
      $password_lengths{"17-19"}++;
    } elsif ($pass_len > 19) {
      $password_lengths{"20+"}++;
    }
    # If the user hit ^C (SIGINT) then we need to stop
    if (recent_sigint()) {
       print "\r"; # Need to return to column 0 of the output line
       return 0;
    }
  }

  print "KeePass file version: " . $k->{header}->{version} . "\n" .
	"Encryption type:      " . $k->{header}->{enc_type} . "\n" .
	"Encryption rounds:    " . $k->{header}->{rounds} . "\n" .
	"Number of groups:     $stats{group_count}\n" .
	"Number of entries:    $stats{entry_count}\n" .
	"Entries with passwords of length:\n".stats_print(\%password_lengths) .
	"\n" .
	"";
}

sub cli_pwd {
  print get_pwd() . "\n";
}

sub cli_cd {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  my $raw_pathstr = $params->{args}->[0];
  # "cd ."
  if ($raw_pathstr =~ m/^[.]$/) {
    return; # nothing to do
  }
  # "cd -"
  if ($raw_pathstr =~ m/^[-]$/) {
    return cli_cd($self, {'args' => [$state->{oldpwd}]});
  }
  # Everything else is handled by helpers
  return cli_cd_helper($state,normalize_path_string($raw_pathstr));
}

# Takes a possibly wacky path with ".."s and such and normalizes it into a
# NULL-separated path that can be used as a key into $state->{all_grp_paths_fwd}
sub normalize_path_string($) {
  my $path_string = shift @_;
  our $state;

  # Split the path into @path
  # http://efreedom.com/Question/1-3588341/Implement-Escape-Sequence-Using-Split-Perl
  my $delim="/";
  my $escape="\\";
  my @path = $path_string =~
	/(?:\Q$delim\E|^)((?>(?:\Q$escape\E.|(?!\Q$delim\E).)*))/gs;
	#/(?:\Q$delim\E|^)((?:\Q$escape\E.|(?!\Q$delim\E).)*+)/gs; # perl 5.10+
  s/\Q$escape$delim\E/$delim/g for @path;
  @path=grep(!/^$/, @path); # Drop meaningless (excess) deimiters (/foo//bar)

  # This block handles absolute and relative paths
  my $path_str='';
  if ($path_string =~ m%^/%) { # Absolute path
    $path_str=join("\0",@path);
  } else { # Relative path
    my $pwd=$state->{all_grp_paths_rev}->{$state->{path}->{id}};
    my @nwd=split("\0", $pwd);
    push @nwd, @path;
    $path_str=join("\0", @nwd);
  }

  # We should now have a NULL-separated, fully qualified path and
  # we just need to work on cleaning up things like "." and ".."
  # Squash single dots
  while ($path_str=~s/\0[.]\0|^[.]\0|\0[.]$/\0/) {}
  # Kill ".." and their parents
  while ($path_str=~s/[^\0]+\0+[.][.]//) {}
  $path_str=~s/\0\0+/\0/g; # squash any adjacent delimeters
  $path_str=~s/^\0+//; # squash any leading delimeters
  $path_str=~s/\0+$//; # squash any trailing delimeters

  return $path_str;
}

sub cli_cd_helper($$) {
  my $state=shift @_;
  my $path_str=shift @_;
  if (defined($state->{all_grp_paths_fwd}->{$path_str})) {
    $state->{oldpwd}=get_pwd();
    my $id=$state->{all_grp_paths_fwd}->{$path_str};
    $state->{path}->{id}=$id;
    return 0;
  } elsif ($path_str eq '') { # cd /
    $state->{oldpwd}=get_pwd();
    delete $state->{path};
    return 0;
  } else {
    print "Invalid path\n";
    return -1;
  }
}

sub cli_find($) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  destroy_found();

  # Users can provide a -a option to search more than just the title. We
  # use GetOpts to parse this command line.
  my $search_str='';
  my %opts=();
  {
    local @ARGV = @{$params->{args}};
    my $result = &GetOptions(\%opts, 'f', 'a');
    if (scalar(@ARGV) != 1) {
      return -1;
    }
    $search_str = $ARGV[0];
  }


  # Now do the search
  my $k=$state->{kdb};
  print "Searching for \"$search_str\" ...\n";

  # Make $search_str a case-insensitive regex
  my @letters=split(//, $search_str);
  foreach my $l (@letters) {
    if (uc($l) ne lc($l)) {
      $l='[' . uc($l) . lc($l) . ']';
    }
  }
  $search_str=join('', @letters);

  my @srch_flds = qw(title);
  if ($opts{'a'}) {
    @srch_flds = qw(title username comment url);
  }
  my @e = ();
  foreach my $fld (@srch_flds) {
    # Search entries by title, skipping the KeePassX /Backup group if it exists
    my $search_params = { "$fld =~" => $search_str };
    my $backup_dir_normalized=normalize_path_string("/Backup"); # /Backup
    if (defined($state->{all_grp_paths_fwd}->{$backup_dir_normalized})) {
      $search_params->{'group_id !'} =
		$state->{all_grp_paths_fwd}->{$backup_dir_normalized};
    }
    push @e, $k->find_entries($search_params);
  }

  if ( scalar(@e) < 1) {
    print "No matches.\n";
    return;
  }

  # If we get this far we have results to add to a new /_found
  my $found_group = $k->add_group({title => $FOUND_DIR}); # root level group
  my $found_gid = $found_group->{'id'};
  $k->unlock;
  my @matches=();
  my %duplicates=();
  FINDS: foreach my $ent (@e) {
    my %new_ent = %{$ent}; # Clone the entity
    $new_ent{id} = int(rand(1000000000000000)); # A random new id
    $new_ent{group} = $found_gid; # Place this entry clone into /_found
    # $new_ent{path} is _NOT_ a normal key for File::KeePass but this is
    # safe because we are adding it to entries in the /_found group which
    # will not be saved to a file.
    my $nulled_path=$state->{all_ent_paths_rev}->{$ent->{id}};
    $new_ent{path} = '/' . dirname(humanize_path($nulled_path)) . '/';
    $new_ent{full_path} = '/' . humanize_path($nulled_path);
    if (defined($duplicates{$new_ent{full_path}})) { next FINDS; }
    $duplicates{$new_ent{full_path}} = 1;
    $k->add_entry(\%new_ent);
    push(@matches, \%new_ent);
    # If the user hit ^C (SIGINT) then we need to stop
    if (recent_sigint()) {
      # If we delete the $FOUND_DIR group it should be safe to leave
      $k->delete_group({title => $FOUND_DIR});
      return undef;
    }
  }
  $k->lock;

  # Because we added a new /_found we must refresh our $state paths
  refresh_state_all_paths();

  # Tell the user what we found
  print " - ".scalar(@matches)." matches found and placed into /$FOUND_DIR/\n";

  # If we only found one, ask the user if they want to see it
  if (scalar(@matches) == 1) {
    print "Would you like to show this entry? [y/N] ";
    my $key=get_single_key();
    print "\n";
    if (lc($key) eq 'y') {
      my $search_params = { 'group_id =' => $found_gid };
      my ($e,@empty) = $k->find_entries($search_params);
      my $full_path="/$FOUND_DIR/" . $e->{title};
      cli_show($self, { args => [ $full_path ] });
    }
  }
}

# Something is going wrong between KeePassX and File::KeePass related to
# the unknown values read/written by File::KeePass from/to files written
# by KeePassX. Commenting out line 378 of File/KeePass.pm is one fix,
# this prevents me from needing to do that by just removing the unknown
# values before saving. If there is a downside to this on the KeePassX
# side I've not found it yet. I do have an email out to Paul, the author
# of File::KeePass, requesting some assistance in grokking the problem.
#
# NOTE: I thought that this should not be needed for File::Keepass >= 0.3,
#       but on 2011-02-02 I discovered that creating new groups with
#       File::Keepass and not scrubbing on save created corrupt files:
#               "Group header offset is out of range" errors.
#       Sourceforge bug# 3187054 demonstrated the problem as well.
sub scrub_unknown_values_from_all_groups {
  our $state;
  # No need to do this with newer versions of File::KeePass (fixed in 2.01)
  if (version->parse($File::KeePass::VERSION) >= version->parse('2.03')) {
    return;
  }
  my $k=$state->{kdb};
  my @all_groups_flattened = $k->find_groups({});
  my @unkown_field_groups=();
  foreach my $g (@all_groups_flattened) {
    if (defined($g->{unknown})) {
      #warn "LHHD: " . &Dumper($g->{unknown}) . "\n";
      delete $g->{unknown};
      push @unkown_field_groups, $g->{title};
    }
  }
  my $count = scalar(@unkown_field_groups);
  if ($count > 0) {
    warn "Deleted unknown fields from these $count groups: " .
					join(", ", @unkown_field_groups) . "\n";
  }
}

sub deny_if_readonly {
  our %opts;
  if (defined($opts->{readonly}) && int($opts->{readonly})) {
    print "Function not available with --readonly set.\n";
    return 1;
  }
  return 0;
}

sub cli_save($) {
  my $self = shift @_;
  my $params = shift @_;

  if (recent_sigint()) { return undef; } # Bail on SIGINT
  if (deny_if_readonly()) { return; }

  our $state;
  if (! length($state->{kdb_file})) {
    print "Please use the saveas command for new files.\n";
    return;
  }

  # If the user has asked for a *.kdbx file, check the File::KeePass version
  if (version->parse($File::KeePass::VERSION) < version->parse('2.03')) {
    if ($state->{kdb_file} =~ m/\.kdbx$/i) {
      print "KeePass v2 (*.kdbx files) require File::KeePass >= v2.03\n";
      return;
    }
  }

  if (warn_if_file_changed()) {
    return;
  }

  # Check for a lock file that we did not place there
  my $lock_file = $state->{kdb_file} . '.lock'; # KeePassX style
  if (-f $lock_file && $state->{placed_lock_file} ne $lock_file) {
    print color('bold yellow') .  "WARNING:" . color('clear') .
        color('red') .
               " A KeePassX-style lock file is in place for this file.\n" .
		"         It may be opened elsewhere. Save anyway? [y/N] " .
        color('clear');
    my $key=get_single_key();
    print "\n";
    if (lc($key) ne 'y') {
      return;
    }
  }

  # If we got this far the user is OK with us locking the file even
  # if we had a contention.
  touch_file($lock_file);
  $state->{placed_lock_file} = $lock_file;

  # Scrub the data and write the file
  destroy_found();
  scrub_unknown_values_from_all_groups(); # TODO - remove later
  my $k=$state->{kdb};
  $k->unlock;
  my $master_pass=
	composite_master_pass($state->{get_master_passwd}(),$state->{key_file});
  $k->save_db($state->{kdb_file},$master_pass);
  $state->{kdb_has_changed}=0; # set our state to no change since last save
  $master_pass="\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
  print "Saved to $state->{kdb_file}\n";
  $k->lock;

  # Update the md5sum of the file after we just saved it
  my $file = $state->{kdb_file};
  $state->{kdb_file_md5} = Digest::file::digest_file_hex($file, "MD5");
}

# This subroutine handles the clipboard commands (xw, xu, xp, and xx)
sub cli_xN($$) {
  my $xNcmd = shift @_;
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  # If Clipboard is not avaiable we can't do this for the user
  if  (! $state->{OPTIONAL_PM}->{'Clipboard'}->{loaded}) {
    print "Error: $xNcmd requires the Clipboard and Capture::Tiny modules:\n" .
	" - http://search.cpan.org/~king/Clipboard/\n" .
	" - http://search.cpan.org/~dagolden/Capture-Tiny/\n" .
	"";
    if (defined($state->{OPTIONAL_PM}->{'Clipboard'}->{error})) {
      print "\nThere was an error loading the Clipboard module, as follows:\n" .
		$state->{OPTIONAL_PM}->{'Clipboard'}->{error} . "\n";
    }
    return;
  }

  # If we're clearing the clipboard, just do that and return immediately.
  if ($xNcmd eq 'xx') {
    Clipboard->copy('');
    print "Clipboard cleared.\n";
    return;
  }

  # Find the entry that the user wants to copy to the clipboard from.
  my $target = $params->{args}->[0];
  my $ent=find_target_entity_by_number_or_path($target);
  if (! defined($ent)) {
    print "Don't see an entry at path: $target\n";
    return -1;
  }

  # Switch over the xN commands and place the data into $to_copy
  my $to_copy = '';
  SWITCH: {
    $xNcmd eq 'xu' && do { $to_copy = $ent->{username}; last SWITCH; };
    $xNcmd eq 'xw' && do { $to_copy = $ent->{url}; last SWITCH; };
    $xNcmd eq 'xp' && do {
			$to_copy = $state->{kdb}->locked_entry_password($ent);
			last SWITCH; };
    warn "Error: cli_xN() does not know how to handle the $xNcmd command.";
    $to_copy = undef;
  }

  # Copy to the clipboard and tell the user what we did.
  my $cp_map = {
	'xu' => 'username',
	'xw' => 'url',
	'xp' => 'password',
	};
  if (defined($to_copy)) {
    Clipboard->copy($to_copy);
    print "Copied $cp_map->{$xNcmd} for \"$ent->{title}\" to the clipboard.\n";
  }

  return;
}

sub cli_rm($) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint() || deny_if_readonly() || warn_if_file_changed()) {
    return;
  }

  my $target = $params->{args}->[0];
  my $ent=find_target_entity_by_number_or_path($target);
  if (! defined($ent)) {
    print "Don't see an entry at path: $target\n";
    return -1;
  }

  my $ent_id=$ent->{id};
  $state->{kdb}->delete_entry({ id => $ent_id });
  $state->{kdb_has_changed}=1;
  RequestSaveOnDBChange();
}

sub validate_entry_number($$) {
  my $item_number=shift @_;
  my $path=shift @_;
  our $state;

  if (normalize_path_string($path) eq '') {
    print "Entries cannot exist in the root path (/).\n";
    return -1;
  }

  if ($item_number !~ m/^[0-9]+$/) {
    print "Invalid item number (must be an integer).\n";
    return -1;
  }

  my ($rGrps,$rEnts) = get_groups_and_entries($path);
  my $entry_max=scalar(@{$rEnts}) - 1;
  if ($entry_max < 0) {
    print "Invalid item number. No valid entries in $path.\n";
    return -1;
  } elsif ($item_number > $entry_max) {
    print "Invalid item number. Valid entries in \"$path\" are 0-$entry_max.\n";
    return -1;
  }
return 0;
}

# This routine takes one parameter that will be either a path
# to an entity or an entity number as shown my the ls command
# and will use $state information such as last_ls_path to
# return a reference to that entity in the $state-{kdb} database,
# if possible (valid input).
sub find_target_entity_by_number_or_path($) {
  my $target=shift @_;
  our $state;

  my $ent=undef; # hope to populate this in a second...


  # This section looks for an entity by an "ls" number
  if ($target =~ m/^[0-9]+$/) {
    my $path=$state->{last_ls_path};
    if (!length($path)) { $path=get_pwd(); }
    if (! validate_entry_number($target,$path)) {
      my ($rGrps,$rEnts) = get_groups_and_entries($path);
      $ent=$rEnts->[$target];
    }
  }

  # This section looks by a path name
  if (defined $state->{all_ent_paths_fwd}->{normalize_path_string($target)}) {
    my $entry_id=$state->{all_ent_paths_fwd}->{normalize_path_string($target)};
    $ent = $state->{kdb}->find_entry( {id=>$entry_id} );
  }

  # If we found the entry, place the path to this entry in the entry record,
  # if it's not already there _and_ if the path we have != $FOUND_DIR.
  if (defined($ent) &&
	(!defined($ent->{path})) && $ent->{path} !~ m/^\Q$FOUND_DIR\E$/) {
    $ent->{full_path} = '/' .
		humanize_path($state->{all_ent_paths_rev}->{$ent->{id}});
    $ent->{path} = dirname($ent->{full_path});
  }

  return $ent;
}

sub cli_rename($$) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint() || deny_if_readonly() || warn_if_file_changed()) {
    return;
  }

  my $target_dir = $params->{args}->[0];
  my $dir_normalized=normalize_path_string($target_dir);
  my $grp=undef;
  if (defined($state->{all_grp_paths_fwd}->{$dir_normalized})) {
    my $grp_id = $state->{all_grp_paths_fwd}->{$dir_normalized};
    $grp=$state->{kdb}->find_group( { id => $grp_id } );
  }
  if (! defined($grp)) {
    print "Unknown group: $target_dir\n";
    return -1;
  }

  my $prompt = color('clear')."Enter the groups new Title: ";
  my $term = get_prepped_readline_term();
  my $new_title = $term->readline($prompt);
  # If the user hit ^C (SIGINT) then we need to stop
  if (recent_sigint()) { return undef; }
  chomp($new_title);
  if (length($new_title)) {
    if ($new_title =~ m/\//) {
      print "kpcli cannot support titles with slashes (/) in them.\n";
      return undef;
    }
    # If the titles are the same then there is nothing to do
    if ($new_title eq $grp->{title}) { return 0; }
    # Check the new title for same-name conflicts in its group
    my $path = dirname('/'.humanize_path($dir_normalized));
    my $testdir=normalize_path_string("$path/$new_title");
    if (defined($state->{all_grp_paths_fwd}->{$testdir})) {
      print "An entry titled \"$new_title\" is already in $path.\n";
      return undef;
    }
    # If we passed all of our sanity checks then set the new title
    $grp->{title} = $new_title;
  } else {
    return 0;
  }

  # Because we renamed a group we must refresh our $state paths
  refresh_state_all_paths();
  $state->{kdb_has_changed}=1;
  RequestSaveOnDBChange();
}

sub cli_mv($$) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint() || deny_if_readonly() || warn_if_file_changed()) {
    return;
  }

  my $target_ent = $params->{args}->[0];
  my $ent=find_target_entity_by_number_or_path($target_ent);
  if (! defined($ent)) {
    print "Unknown entry: $target_ent\n";
    return -1;
  }

  my $target_dir = $params->{args}->[1];
  my $dir_normalized=normalize_path_string($target_dir);
  my $grp=undef;
  if (defined($state->{all_grp_paths_fwd}->{$dir_normalized})) {
    my $grp_id = $state->{all_grp_paths_fwd}->{$dir_normalized};
    $grp=$state->{kdb}->find_group( { id => $grp_id } );
  }
  if (! defined($grp)) {
    print "Unknown group: $target_dir\n";
    return -1;
  }

  # Verify no entry title conflict at the new location
  my $new_entry_path=normalize_path_string($target_dir . "/" . $ent->{title});
  if (defined($state->{all_ent_paths_fwd}->{$new_entry_path})) {
    my $path = dirname(humanize_path($new_entry_path));
    print "There is already and entry named \"$ent->{title}\" at $path/.\n";
    return undef;
  }

  # Unlock the kdb, clone the entry, remove its ID and set its new group,
  # add it to the kdb, delete the old entry, then lock the kdb...
  $state->{kdb}->unlock;
  my %ent_copy = %{$ent};
  delete $ent_copy{id};
  $ent_copy{group} = $grp;
  if ($state->{kdb}->add_entry(\%ent_copy)) {
    $state->{kdb}->delete_entry({ id=>$ent->{id} });
  }
  $state->{kdb}->lock;

  # Because we moved an entry we must refresh our $state paths
  refresh_state_all_paths();
  $state->{kdb_has_changed}=1;
  RequestSaveOnDBChange();
}

sub cli_show($$) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  # Users can provide a -f option to show the password. We use GetOptions
  # to parse this command line, and $target holds that target.
  my $target='';
  my %opts=();
  {
    local @ARGV = @{$params->{args}};
    my $result = &GetOptions(\%opts, 'f', 'a');
    if (scalar(@ARGV) != 1) {
      return -1;
    }
    $target = $ARGV[0];
  }

  my $ent=find_target_entity_by_number_or_path($target);
  if (! defined($ent)) {
    return -1;
  }

  print "\n";
  if (defined($ent->{path})) {
    print show_format("Path",$ent->{path}) . "\n";
  }
  # Unless -f is specified, we "hide" the password as red-on-red.
  my $password = $state->{kdb}->locked_entry_password($ent);
  if (! defined($opts{f})) {
    $password = colored(['red on_red'], $password);
  }
  print
	show_format("Title",$ent->{title}) . "\n" .
	show_format("Uname",$ent->{username}) . "\n" .
	show_format("Pass",$password) . "\n" .
	show_format("URL",$ent->{url}) . "\n" .
	show_format("Notes",$ent->{comment}) . "\n" .
	($DEBUG ? show_format("ID",$ent->{id}) . "\n" : '');
  if (defined($opts{a})) {
    print
	show_format("Icon#",$ent->{icon}) . "\n" .
	show_format("Creat",$ent->{created}) . "\n" .
	show_format("Modif",$ent->{modified}) . "\n";
    if (defined($ent->{expires})) {
      print show_format("Xpire",$ent->{expires}) . "\n";
    }
  }
  print "\n";
  print &Dumper($ent) . "\n" if ($DEBUG > 2);
}

sub cli_edit($) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint() || deny_if_readonly() || warn_if_file_changed()) {
    return;
  }

  my $target = $params->{args}->[0];
  my $ent=find_target_entity_by_number_or_path($target);
  if (! defined($ent)) {
    print "Don't see an entry at path: $target\n";
    return -1;
  }

  # Loop through the fields taking edits the user wants to make
  my @fields = get_entry_fields();
  my %changes = ();
  foreach my $input (@fields) {
    my $val = '';
    if ($input->{multiline}) {
      $val = new_edit_multiline_input($input, $ent->{$input->{key}});
    } else {
      $val = new_edit_single_line_input($input, $ent->{$input->{key}});
    }
    # If the user hit ^C (SIGINT) then we need to stop
    if (recent_sigint()) { return undef; }
    # Check a new title for same-name conflicts in its group
    if ($input->{key} eq 'title' && length($val)) {
      if ($val =~ m/\//) {
        print "kpcli cannot support titles with slashes (/) in them.\n";
        return undef;
      }
      my $path = $ent->{path}; # The group's path of the entry we are editing
      my $new_entry = normalize_path_string("$path/$val");
      if (defined($state->{all_ent_paths_fwd}->{$new_entry})) {
        print "An entry titled \"$val\" is already in $path.\n";
        return undef;
      }
    }

    # If the field was not empty, we'll change it to the new $val
    if (length($val)) { $changes{$input->{key}} = $val; }
  }

  # If the user made changes, apply them, update modify time and prompt to save
  if (scalar(keys(%changes)) > 0) {
    $state->{kdb}->unlock; # Required for the password field
    foreach my $key (keys %changes) { $ent->{$key} = $changes{$key}; }
    $state->{kdb}->lock;
    $ent->{modified} = $state->{kdb}->now;
    refresh_state_all_paths();
    $state->{kdb_has_changed}=1;
    RequestSaveOnDBChange();
  }

return 0;
}

# A code-consolidation function...
sub get_prepped_readline_term() {
  our $state;

  # Note: A 2nd Term::ReadLine::Gnu->new() just returns the same
  # object as the one that Term::ShellUI is already using. With
  # Term::Readline::Perl, an attempt to call new a 2nd time results
  # in having a Term::Readline::Stub returned and a warning printed to
  # STDERR, which we also don't want, and so I coded this the way that
  # I did to make clear what is being done, and this comment for why.
  my $term = $state->{term}->{term}; # Term::ShellUI's readline
  $state->{active_readline} = $term;

  # Use Term::ReadLine::Gnu more advanced functionality...
  if ($term->ReadLine() eq 'Term::ReadLine::Gnu') {
    # Called roughly 10-times per second while Gnu readline waits for input
    $term->Attribs->{event_hook} = sub {
          if (recent_sigint()) {
             $term->Attribs->{event_hook} = undef;
             $term->set_prompt('');
             $term->Attribs->{line_buffer}='';
             $term->Attribs->{done} = 1;
	     $state->{active_readline} = undef;
          }
        };
  }

  return $term;
}

# Single line input helper function for cli_new and cli_edit.
sub new_edit_single_line_input($$) {
  my $input = shift @_;
  my $initial_value = shift @_;
  our $state;

  my $iv = ''; if (! $input->{hide_entry}) { $iv = $initial_value; }
  my $term = get_prepped_readline_term();
  if ($input->{genpasswd}) {
    print " "x25 . '("g" or "w" to generate a password)' . "\r";
  }
  my $prompt=$input->{txt} . ': ';
  my $val = '';
  if ($input->{hide_entry}) {
    $val = GetPassword($prompt, '');
  } else {
    $val = $term->readline($prompt, $iv);
  }
  chomp $val;
  if ($input->{genpasswd} && $val =~ m/^[wg]$/) {
    if ($val eq 'g') {
      $val = generatePasswordGobbledygook(20);
    } else {
      $val = generatePassword();
    }
  } elsif (length($val) && $input->{double_entry_verify}) {
    my $prompt = "Retype to verify: ";
    my $checkval = '';
    if ($input->{hide_entry}) {
      $checkval = GetPassword($prompt, '');
    } else {
      $checkval = $term->readline($prompt);
    }
    # If the user hit ^C (SIGINT) then we need to stop
    if (recent_sigint()) { return undef; }
    chomp $checkval;
    if ($checkval ne $val) {
      print "Entries mismatched. Please try again.\n";
      redo;
    }
  }
  # We are done with readline calls so let's cleanup.
  if ($term->ReadLine() eq 'Term::ReadLine::Gnu') {
    $term->Attribs->{startup_hook} = undef;
    $term->Attribs->{event_hook} = undef;
  }
  # This funciton is supposed to return blank if nothing changed
  if ($val eq $initial_value) { $val = ''; }
  return $val;
}
# Multi-line input helper function for cli_new and cli_edit.
sub new_edit_multiline_input($$) {
  my $input = shift @_;
  my $initial_value = shift @_;
  our $state;

  # Protect programmers from accidentally misusing this function
  if ($input->{genpasswd}) { die "genpasswd unsupported by this function"; }

  if ($input->{hide_entry}) {
    print $input->{txt} . ": ";
  } else {
    my $mlval = $initial_value;
    if ($mlval =~ m/\r|\n/) { $mlval = "\n$mlval\n"; }
    print $input->{txt} . " (\"".$mlval."\"): ";
  }

  my $yellow=color('yellow');
  my $clear=color('clear');
  print "\n$yellow(end multi-line input with a single \".\" on a line)$clear\n";

  my $term = get_prepped_readline_term();

  my $val = ''; my $unfinished = 1;
  while ($unfinished) {
    # Term::ReadLine::Perl seems to have a bug that requires a prompt
    # (it borks on ''), but after adding the pipe I liked it so left
    # it place for all readlines.
    my $line = $term->readline('| ');
    if ($line =~ m/^\.[\r\n]*$/) { # a lone "." ends our input
      $unfinished = 0;
    } else {
      $val .= $line;
      $val .= "\n" if ($val !~ m/\n$/); # ReadLine() vs. $term->readline().
      if ($val =~ m/^[\r\n]*$/) { $val = ''; $unfinished = 0; }
    }
    # If the user hit ^C (SIGINT) then we need to stop
    if (recent_sigint()) { return undef; }
  }
  chomp($val); # Remove extra line at the end
  return $val;
}

# Formats an entry for display for cli_show()
sub show_format($$) {
  my $title=shift @_;
  my $value=shift @_;
  my $val=$value;
  if ($val =~ m/\n/) {
    my @val_lines=split(/\n/, $val);
    $val=join("\n" . " "x(5+2), @val_lines);
  }
  return sprintf("%5s: %s", $title,$val);
}

# Formats a statistic display for cli_stats()
sub stats_print($) {
  my $stats_r = shift @_;

  my $max_key_len = 0;
  my $max_val_len = 0;
  foreach my $k (keys(%{$stats_r})) {
    if (length($k) > $max_key_len) { $max_key_len = length($k); }
  }
  foreach my $k (values(%{$stats_r})) {
    if (length($k) > $max_val_len) { $max_val_len = length($k); }
  }
  my $sprintf_format = "  - %$max_key_len" . "s: %$max_val_len" . "d\n";
  my $t='';
  foreach my $stat_key (sort {$a <=> $b} keys %{$stats_r}) {
    $t .= sprintf($sprintf_format, $stat_key, $stats_r->{$stat_key});
  }
  return $t;
}

sub get_entry_fields {
  my @fields = (
	{ key=>'title', txt=>'Title' },
	{ key=>'username', txt=>'Username' },
	{ key=>'password', txt=>'Password',
		hide_entry => 1, double_entry_verify => 1, genpasswd => 1 },
	{ key=>'url', txt=>'URL' },
	{ key=>'comment', txt=>'Notes/Comments', 'multiline' => 1 },
	);
  return @fields;
}

# Code consolidation function.
# Returns true if $state->{signals}->{INT} indicates a SIGINT more
# recently than the $timeframe given, which defaults to 0.25 secs.
sub recent_sigint() {
  my $timeframe = shift @_;
  if ($timeframe !~ m/^([0-9]*\.[0-9]+|[0-9]+)$/) { $timeframe = 0.25; }
  our $state;
  if (defined($state->{signals}->{INT}) &&
		tv_interval($state->{signals}->{INT}) < $timeframe) {
    return 1;
  }
  return 0;
}

sub cli_icons($) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  print "Change icons on Groups or Entries (g/e/Cancel)? ";
  my $groups_or_entries=lc(get_single_key());
  print "\n";
  if (recent_sigint() || $groups_or_entries !~ m/^[ge]$/) { return; }

  print "Change icons Here, Below here, or Globally (h/b/g/Cancel)? ";
  my $glob_or_rel=lc(get_single_key());
  print "\n";
  if (recent_sigint() || $glob_or_rel !~ m/^[hgb]$/) { return; }

  print "What would you line the new icon to be (0-64/Cancel)? ";
  my $term = get_prepped_readline_term();
  my $val = $term->readline('');
  # If the user hit ^C (SIGINT) then we need to stop
  if (recent_sigint()) { return undef; }
  chomp($val);
  if ($val !~ m/^[0-9]+$/ || $val < 0 || $val > 64) {
    print "Invalid icon number.\n";
    return;
  }

  # This code fills @{$groups} or @{$entries} with the items that the
  # user wants to change the icons on.
  my ($groups,$entries) = ([],[]);
  if ($glob_or_rel eq 'h') { # "Here" is easy -- we have a function for that.
    ($groups,$entries) = get_current_groups_and_entries();
    if ($groups_or_entries eq 'e') {
      $groups = [];
    } else {
      $entries = [];
    }
  } else {
    if ($glob_or_rel eq 'g') { # Globally is easy, it's all groups
      my $k=$state->{kdb};
      @{$groups} = $k->find_groups({});
    } elsif ($glob_or_rel eq 'b') {
      my $id=$state->{path}->{id};
      @{$groups} = all_child_groups_flattened($id); # *only child groups*
    } else {
      warn "WHAT? Should never get to this piece of code!\n";
    }
    # If the user wanted to operate on entries, collect all the entries
    # in the @{$groups} and then empty @{$groups}.
    if ($groups_or_entries eq 'e') {
      foreach my $group (@{$groups}) {
        if (defined($group->{entries})) {
          push @{$entries}, @{$group->{entries}};
        }
      }
      $groups = [];
    }
  }

  # Change the items, recording the number of changes.
  my $items_changed=0;
  foreach my $item (@{$groups}, @{$entries}) {
    $item->{icon} = $val;
    $items_changed++;
  }

  # Tell the user what we did.
  print "The icon value was set to $val on $items_changed records.\n";

  # If we changed anything, ask the user if they want to save
  if ($items_changed > 0) {
    $state->{kdb_has_changed}=1;
    RequestSaveOnDBChange();
  }
  return 0;
}

sub cli_new($) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint() || deny_if_readonly() || warn_if_file_changed()) {
    return;
  }

  my $new_path=get_pwd();
  my $new_title='';
  # If the user gave us a path (that may include the new title) in args[0],
  # then we have to first rationalize that path.
  if (defined($params->{args}->[0])) {
    $new_path = $params->{args}->[0];
    # Insure that $new_path is absolute
    if ($new_path !~ m/^\/+$/) {
      $new_path = get_pwd() . '/' . $new_path;
    }
    my $norm_path = normalize_path_string($new_path);
    my ($grp_path,$name)=normalize_and_split_raw_path($new_path);
    if (defined($state->{all_grp_paths_fwd}->{$norm_path})) {
      $new_path = '/' . humanize_path($norm_path);
      $new_title = '';
    } elsif (defined($state->{all_grp_paths_fwd}->{$grp_path})) {
      $new_path = '/' . humanize_path($grp_path);
      $new_title = $name;
    } else {
      if ($norm_path eq '') {
        print "Entries cannot be made in the root path.\n";
      } else {
        print "Bad path for new entry\n";
      }
      return;
    }
  }

  # $id needs to be set to the ID of the group we want to add to
  my $id = undef;
  my $norm_path=normalize_path_string($new_path);
  if (defined($state->{all_grp_paths_fwd}->{$norm_path})) {
    $id=$state->{all_grp_paths_fwd}->{$norm_path};
  }

  # Make sure that we have a valid path for creating a new entry
  if ($new_path =~ m/^\/+$/ || (! defined($id))) {
    print "Entries cannot be made in this path ($new_path).\n";
    return -1;
  }

  print "Adding new entry to \"$new_path\"\n";

  # Grab the entries at this $id (pwd) so we can check for conflicts
  my $k=$state->{kdb};
  my ($this_grp,@trash) = $k->find_groups({id=>$id});
  my @entries = $k->find_entries({group_id => $id});

  my $new_entry = {
    'group' => $id,
  };

  my @fields = get_entry_fields();
  NEW_DATA_COLLECTION: foreach my $input (@fields) {
    my $val = '';
    if ($input->{multiline}) {
      $val = new_edit_multiline_input($input, '');
    } else {
      if ($new_title ne '' && $input->{key} eq 'title') {
        print $input->{txt} . ": $new_title\n";
        $val = $new_title;
      } else {
        $val = new_edit_single_line_input($input, '');
      }
    }
    # If the user hit ^C, abort the new entry
    if (recent_sigint()) { return undef; }
    # If the user gave us an empty title, abort the new entry
    if ($input->{key} eq 'title' && length($val) == 0) { return undef; }
    # Check the new title for same-name conflicts in its group
    if ($input->{key} eq 'title') {
      if ($val =~ m/\//) {
        print "kpcli cannot support titles with slashes (/) in them.\n";
        return undef;
      }
      my $new_entry = normalize_path_string($new_path . '/' . $val);
      if (defined($state->{all_ent_paths_fwd}->{$new_entry})) {
        print "An entry titled \"$val\" is already in $new_path.\n";
        return undef;
      }
    }

    $new_entry->{$input->{key}} = $val;
  }
  $new_entry->{icon} = $DEFAULT_ENTRY_ICON;

  $k->unlock;
  my $new_entry_ref = $k->add_entry($new_entry);
  $k->lock;
  if ($new_entry_ref->{id}) {
    refresh_state_all_paths();
    $state->{kdb_has_changed}=1;
    RequestSaveOnDBChange();
  } else {
    print "Failed to add new entry.\n";
  }
  return 0;
}

sub cli_import {
  my $file=shift @_;
  my $new_group_path=shift @_;
  my $key_file=shift @_;
  our $state;

  if (recent_sigint() || deny_if_readonly()) { return; }

  # If the user gave us a bogus file there's nothing to do
  if (! -f ($file)) {
    print "File does not exist: $file\n";
    return -1;
  }
  if (magic_file_type($file) ne 'keepass') {
    print "Does not appear to be a KeePass file: $file\n";
    return -1;
  }
  # If the $new_group_path is a relative path, make it absolute
  if ($new_group_path !~ m/^\//) {
    $new_group_path = get_pwd() . "/$new_group_path";
  }
  # We won't import into an existing group
  my $full_path=normalize_path_string($new_group_path);
  if (defined($state->{all_grp_paths_fwd}->{$full_path})) {
    print "You must specify a _new_ group to import into.\n";
    return -1;
  }
  # Make sure the new group's parent exists
  my ($grp_path,$grp_name)=normalize_and_split_raw_path($new_group_path);
  if ($grp_path != '' && ! defined($state->{all_grp_paths_fwd}->{$grp_path})) {
    print "Path does not exist: /" . humanize_path($grp_path) . "\n";
    return -1;
  }
  # Set the $parent_group value appropriately
  my $parent_group = undef; # Root by default
  if (length($grp_path)) {
    $parent_group = $state->{all_grp_paths_fwd}->{$grp_path};
  }
  # Ask the user for the master password and then open the kdb
  my $master_pass=GetMasterPasswd();
  if (recent_sigint()) { return undef; } # Bail on SIGINT
  my $iKDB = File::KeePass->new;
  if (! eval { $iKDB->load_db($file,
			composite_master_pass($master_pass, $key_file)) }) {
    print "Couldn't load the file $file: $@\n";
    return -1;
  }
  # Add the new group, to its parent or to root if $parent_group==undef
  my $k=$state->{kdb};
  my $new_group=$k->add_group({
	title => $grp_name,
	group => $parent_group,
	});
  # Copy the $iKDB into our $k at $new_group
  $iKDB->unlock();
  $k->unlock();
  my @root_groups = $iKDB->find_groups({level=>0});
  foreach my $i_root_grp (@root_groups) {
    copy_kdb_group_tree($k,$i_root_grp,$new_group);
  }
  $k->lock();
  $iKDB->lock();
  $iKDB=undef;
  # Refresh all paths and mark state as changed
  refresh_state_all_paths();
  $state->{kdb_has_changed}=1;
  RequestSaveOnDBChange();
}

sub cli_export($$) {
  my $file=shift @_;
  my $key_file=shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  # Warn is we are being asked to overwrite a file
  if (-e $file) {
    print "WARNING: $file already exists.\n" .
		"Overwrite it? [y/N] ";
    my $key=get_single_key();
    print "\n";
    if (lc($key) ne 'y') {
      return -1;
    }
  }

  # Get the master password for the exported file
  my $master_pass=GetMasterPasswdDoubleEntryVerify();
  if (recent_sigint()) { return undef; } # Bail on SIGINT
  if (! defined($master_pass)) { return undef; }
  if (length($master_pass) == 0) {
    print "For your safety, empty passwords are not allowed...\n";
    return;
  }

  # Build the new kdb in RAM
  my $k=$state->{kdb};
  my $new_kdb=new File::KeePass;
  $k->unlock; # Required so that we can copy the passwords
  if (get_pwd() ne '/') {
    # Grab the root group's $id at our pwd
    my $pwd_group_id=$state->{path}->{id};
    my ($root_grp,@trash) = $k->find_groups({id=>$pwd_group_id});
    copy_kdb_group_tree($new_kdb,$root_grp,undef);
  } else {
    # Put all of the root groups into the new file (entire file copy)
    my @root_groups = $k->find_groups({level=>0});
    foreach my $root_grp (@root_groups) {
      copy_kdb_group_tree($new_kdb,$root_grp,undef);
    }
  }
  $k->lock;
  $new_kdb->unlock;
  my $new_db_bin =
		$new_kdb->gen_db(composite_master_pass($master_pass,$key_file));
  $new_kdb->lock;

  # Test parsing the kdb from RAM (we'll most likely die if this fails)
  my $new_db=new File::KeePass;
  $new_db->parse_db($new_db_bin,composite_master_pass($master_pass,$key_file));

  # Now write the new kdb to disk
  my $fh=new FileHandle;
  if (open($fh,'>',$file)) {
    print $fh $new_db_bin;
    close $fh;
    print "Exported to $file\n";
  } else {
    print "Could not open \"$file\" for writing.\n";
  }

  return 0;
}

# A helper function for cli_export() and cli_import(). It takes a kdb object,
# a group as a starting point to copy from, and optionally a parent_group to
# copy to. It copies everything from the source group's root downward. In our
# use cases, the _target_ $kdb object passed in here is typically a different
# one than the _source_ $group is from.
sub copy_kdb_group_tree {
  my $kdb=shift @_;
  my $group=shift @_;
  my $parent_group=shift @_ || undef; # When undef, it writes to the root

  # Add the new group, to it's parent or root if $parent_group==undef
  my $new_group=$kdb->add_group({
	title => $group->{title},
	icon => $group->{icon},
	id => $group->{id},
	group => $parent_group,
	});

  # Add the new_group's entries
  if (ref($group->{entries}) eq 'ARRAY') {
    foreach my $entry (@{$group->{entries}}) {
      $entry->{group} = $new_group;
      $kdb->add_entry($entry);
    }
  }

  # Add the new_group's child groups
  if (ref($group->{groups}) eq 'ARRAY') {
    foreach my $child_grp (@{$group->{groups}}) {
      copy_kdb_group_tree($kdb,$child_grp,$new_group);
    }
  }
}

sub cli_saveas($) {
  my $file=shift @_;
  my $key_file=shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  # If the user has asked for a *.kdbx file, check the File::KeePass version
  if (version->parse($File::KeePass::VERSION) < version->parse('2.03')) {
    if ($file =~ m/\.kdbx$/i) {
      print "KeePass v2 (*.kdbx files) require File::KeePass >= v2.03\n";
      return;
    }
  }

  # Warn is we are being asked to overwrite a file
  if (-e $file) {
    print "WARNING: $file already exists.\n" .
                "Overwrite it? [y/N] ";
    my $key=get_single_key();
    print "\n";
    if (lc($key) ne 'y') {
      return -1;
    }
    if (recent_sigint()) { return undef; } # Bail on SIGINT
  }

  # Get the master password for the file
  my $master_pass=GetMasterPasswdDoubleEntryVerify();
  if (recent_sigint()) { return undef; } # Bail on SIGINT
  if (! defined($master_pass)) { return undef; }
  if (length($master_pass) == 0) {
    print "For your safety, empty passwords are not allowed...\n";
    return;
  }

  destroy_found();
  scrub_unknown_values_from_all_groups(); # TODO - remove later
  $state->{kdb}->unlock;
  $state->{kdb}->save_db($file,composite_master_pass($master_pass,$key_file));
  $state->{kdb}->lock;

  $state->{kdb}= File::KeePass->new;
  if (! eval { $state->{kdb}->load_db($file,
			composite_master_pass($master_pass,$key_file)) }) {
    die "Couldn't load the file $file: $@";
  }
  $state->{kdb_has_changed}=0;
  $state->{kdb_file} = $file;
  $state->{key_file} = $key_file;
  $state->{put_master_passwd}($master_pass);
  $master_pass="\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
  return 0;
}

# This routine takes a raw (directly from user input) path string
# and "normalizes" it (converts it to NULL-separated w/out escapes)
# and splits it into its dirname and basename components.
sub normalize_and_split_raw_path($) {
  my $raw_pathstr=shift @_;

  my $path=normalize_path_string($raw_pathstr);

  my $basename='';
  if ($path =~ m/\0/) {			# case of at least one path delimeter
    $path =~ s/\0([^\0]+)$//;
    $basename=$1;
  } elsif ($raw_pathstr =~ m/^\//) {	# case of simple "/foo" (no subdir)
    $basename=$path;
    $path='';
  } else {				# case of simple "foo" (no path delims)
    $path = normalize_path_string(get_pwd());
    $basename=$raw_pathstr;
  }
return($path,$basename);
}

sub cli_rmdir($) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint() || deny_if_readonly() || warn_if_file_changed()) {
    return;
  }

  my $raw_pathstr=$params->{'args'}->[0];
  my ($path,$grp_name) = normalize_and_split_raw_path($raw_pathstr);

  # Make sure the group exists.
  my $grp_path="$path\0$grp_name";
  $grp_path=~s/^\0+//;
  if (! defined($state->{all_grp_paths_fwd}->{$grp_path})) {
    print "Path does not exist: /" . humanize_path($grp_path) . "\n";
    return -1;
  }

  my $group_id = $state->{all_grp_paths_fwd}->{$grp_path};
  my $group = $state->{kdb}->find_group({ id => $group_id });
  my $entry_cnt=0;
  if (defined($group->{entries})) {
    $entry_cnt=
	scalar(grep(m/^\Q$grp_path\E\0/,keys %{$state->{all_ent_paths_fwd}}));
  }
  my $group_cnt=0;
  if (defined($group->{entries})) {
    $group_cnt=
	scalar(grep(m/^\Q$grp_path\E\0/,keys %{$state->{all_grp_paths_fwd}}));
  }
  my $child_cnt=$entry_cnt + $group_cnt;
  if ( $child_cnt > 0) {
    print "WARNING: This group has $child_cnt child groups and/or entries.\n" .
	"Really remove it!? [y/N] ";
    my $key=get_single_key();
    print "\n";
    if (lc($key) ne 'y') {
      return -1;
    }
  }
  my $deleted_group = $state->{kdb}->delete_group({ id => $group_id });

  # Because we removed a group we need to refresh our state paths
  refresh_state_all_paths();
  $state->{kdb_has_changed}=1;
  RequestSaveOnDBChange();
  return 0;
}

sub cli_mkdir($) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint() || deny_if_readonly() || warn_if_file_changed()) {
    return;
  }

  my $raw_pathstr = $params->{args}->[0];
  my ($path,$newdir) = normalize_and_split_raw_path($raw_pathstr);

  # Make sure the group doesn't already exist.
  my $newdir_path="$path\0$newdir";
  $newdir_path=~s/^\0+//;
  if (defined($state->{all_grp_paths_fwd}->{$newdir_path})) {
    print "Path already exists: /" . humanize_path($newdir_path) . "\n";
    return -1;
  }

  # Create the group
  my $group='';
  if ($path eq '') {
    $group = $state->{kdb}->add_group({
        title => $newdir,
	icon => $DEfAULT_GROUP_ICON,
    }); # root level group
  } elsif (defined($state->{all_grp_paths_fwd}->{$path})) {
    my $group_id=$state->{all_grp_paths_fwd}->{$path};
    $group = $state->{kdb}->add_group({
		title => $newdir,
		group => $group_id,
		icon => $DEfAULT_GROUP_ICON,
	});
  } else {
    print "Cannot make directory at path " . humanize_path($path) . "\n";
    return -1;
  }

  # Because we created a new group we need to refresh ours state paths
  refresh_state_all_paths();
  $state->{kdb_has_changed}=1;
  RequestSaveOnDBChange();
  return 0;
}

sub humanize_path($) {
  my $path=shift @_;
  $path =~ s/\//\\\//g;
  $path =~ s/\0/\//g;
  return $path;
}

sub cli_open($) {
  my $path=shift @_;
  my $key=shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  # If cli_close() does not return 0 the user decided not to close the file
  if (cli_close() != 0) {
    return -1;
  }

  if ( -f $path ) {
    my $err = open_kdb($path, $key);
    if (length($err)) {
      print "Error opening file: $err\n";
    }
  } else {
    print "Cannot open: $path\n";
  }
}

# Get a single keypress from the user
sub get_single_key {
  our $state;
  my $key='';
  $|=1; # Needed to flush STDOUT on Windows cmd prior to calling ReadMode
  ReadMode('raw'); # Turn off controls keys
  while (not defined ($key = ReadKey(-1))) {
    # If the user hit ^C (SIGINT) then we need to stop
    if (recent_sigint()) { return undef; }
    # No key yet, but let's not eat 100% CPU while waiting, so sleep.
    Time::HiRes::sleep(0.1);
  }
  ReadMode('restore');
return $key;
}

sub cli_close {
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  if ($state->{kdb_has_changed}) {
    print "WARNING: The database has changed and was not saved.\n" .
	"Really close it? [y/N] ";
    my $key=get_single_key();
    print "\n";
    if (lc($key) ne 'y') {
      return -1;
    }
  }

  $state->{'kdb'}->clear();
  new_kdb($state);
  return 0;
}

# This sets $state to a brand new, KeePassX-style, empty, unsaved database
sub new_kdb {
  my $state=shift @_;
  $state->{kdb_has_changed}=0;
  $state->{'kdb'} = File::KeePass->new;
  # To be compatible with KeePassX
  $state->{'kdb'}->add_group({ title => 'eMail' });
  $state->{'kdb'}->add_group({ title => 'Internet' });
  refresh_state_all_paths();
  if (-f $state->{placed_lock_file}) { unlink($state->{placed_lock_file}); }
  delete($state->{placed_lock_file});
  delete($state->{kdb_file});
  delete($state->{key_file});
  delete($state->{master_pass});
  cli_cd($term, {'args' => ["/"]});
}

sub cli_ls($$) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  my @paths = ();
  if (defined($params) && defined($params->{'args'}) &&
				ref($params->{'args'}) eq 'ARRAY') {
    @paths = @{$params->{'args'}};
  }
  if (scalar(@paths) == 0) { push @paths, ''; }
  my $paths_count = scalar(@paths);
  my $loops=0;
  foreach my $path (@paths) {
    # If multiple dirs are being listed, title each
    if ($paths_count > 1) {
      $path =~ s/\/+$//; print "$path/:\n";
    }

    # If we were given a path, use cli_cd() to go there temporarily...
    my $old_path='';
    if (length($path)) {
      $old_path=get_pwd();
      if (cli_cd($term, {'args' => [$path]})) {
        return -1; # If cli_cd() returned non-zero it failed
      }
    }

    # List the pwd
    $state->{last_ls_path} = get_pwd();
    my ($rGrps,$rEnts) = get_current_groups_and_entries();
    if (scalar(@{$rGrps}) > 0) {
      print "=== Groups ===\n";
      print join("\n", @{get_human_group_list($rGrps)}) . "\n";
    }
    if (scalar(@{$rEnts}) > 0) {
      print "=== Entries ===\n";
      print join("\n", @{get_human_entry_list($rEnts)}) . "\n";
    }

    # If we temporarily cd'ed, cd back.
    if (length($old_path)) {
      cli_cd($term, {'args' => [$old_path]});
    }

    # If printing multiple dirs, we need to append a \n to all but the last
    if ($paths_count > 1 && ++$loops < $paths_count) {
      print "\n";
    }
  }
  return 0;
}

# Helper function for cli_ls()
sub get_human_group_list($) {
  my $rGroup=shift @_;
  my @list=();
  foreach my $grp (@{$rGroup}) {
    #push (@list, sprintf("%15d %s/", $grp->{id}, $grp->{title}));
    push (@list, "$grp->{title}/");
    push (@list, &Dumper($grp)) if ($DEBUG > 2);
  }
  return \@list;
}

# Helper function for cli_ls()
sub get_human_entry_list($) {
  my $rEntries=shift @_;
  my @list=();
  my $i=0;
  my $d_len=int((scalar(@{$rEntries}) - 1) / 10) + 1;
  foreach my $ent (@{$rEntries}) {
    my $url=$ent->{url};
    $url=~s/^https?:\/\///i;
    $url=~s/\/+$//;
    push (@list, sprintf("%".$d_len."d. %-40.40s %30.30s",
						$i, $ent->{title}, $url));
    $i++;
  }
  return \@list;
}

# Routine to hook into Term::ShellUI's exit on Ctrl-D functionality
sub eof_exit_hook {
  our $state;
  # We need a newline if cli_quit() will talk tothe user about saving
  if ($state->{kdb_has_changed}) { print "\n"; }
  # cli_quit() will handle user interaction and return a value for
  # the exit_hook of Term::ShellUI.
  return cli_quit($state->{term},undef);
}

sub cli_quit($$) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  if ($state->{kdb_has_changed}) {
    print "WARNING: The database has changed and was not saved.\n" .
	"Really quit? [y/N] ";
    my $key=get_single_key();
    if (lc($key) ne 'y') {
      print "\n";
      return -1; # It is not OK to quit
    }
  }

  if (-f $state->{placed_lock_file}) { unlink($state->{placed_lock_file}); }
  delete($state->{placed_lock_file});
  $self->exit_requested(1);
  return 0; # It's OK to quit
}

sub cli_version($$) {
  my $self = shift @_;
  my $params = shift @_;
  our $state;

  if (recent_sigint()) { return undef; } # Bail on SIGINT

  # Users can provide a -f option to show the password. We use GetOptions
  # to parse this command line, and $target holds that target.
  my $target='';
  my %opts=();
  {
    local @ARGV = @{$params->{args}};
    my $result = &GetOptions(\%opts, 'v');
  }

  if ($opts{'v'}) {
    print "VERSIONS\n";
    print " * kpcli: $VERSION\n";
    my $pv = $PERL_VERSION;
    if (! length($pv)) {
      $pv = $]; # For perl versions prior to 5.6.0
    }
    print " * Perl: $pv\n";
    my @modules = qw(File::KeePass Term::ShellUI Term::ReadKey Term::ReadLine);
    foreach my $module (sort keys %OPTIONAL_PM) {
      if ($OPTIONAL_PM{$module}->{loaded}) {
        push @modules, $module;
      }
    }
    foreach my $module (@modules) {
      no strict 'refs';
      my $vstr=$module . "::VERSION";
      print " * $module: " . ${$vstr} . "\n";
    }
    print "\n";
    print "ReadLine being used: " . $term->{term}->ReadLine . "\n";
    print "Operating system: $OSNAME\n";
  } else {
    print "$VERSION\n";
  }
}

# Function to nag the user about saving each time the DB is modified
sub RequestSaveOnDBChange {
  our $state;

  # If the db hasn't changed don't bother the user
  if (! $state->{kdb_has_changed}) {
    return -1;
  }

  # If this is a newly created file we don't bother the user with
  # asking to save after every change.
  if (! length($state->{kdb_file})) {
    return -1;
  }

  print "Database was modified. Do you want to save it now? [y/N]: ";
  my $key=get_single_key();
  print "\n";
  if (lc($key) ne 'y') {
    return;
  }

  # Calling cli_save() should be silent and safe at this point.
  return cli_save(undef);
}

sub GetMasterPasswd {
  my $prompt = "Please provide the master password: ";
  return GetPassword($prompt,'*');
}

sub GetMasterPasswdDoubleEntryVerify {
  my $master_pass=GetMasterPasswd();
  if (recent_sigint()) { return undef; } # Bail on SIGINT

  if (length($master_pass) == 0) { return ''; }

  my $prompt = "Retype to verify: ";
  my $checkval = GetPassword($prompt,'*');
  chomp $checkval;
  if (recent_sigint()) { return undef; } # Bail on SIGINT
  if ($master_pass ne $checkval) {
    print "Passwords did not match...\n";
    return undef;
  }

  return $master_pass;
}


sub GetPassword {
  my $prompt = shift @_;
  my $echo_char = shift @_ || '';

  if (length($echo_char) > 1) {
    warn "GetPassword() cannot accept an \$echo_char of more than one char.\n";
    $echo_char='';
  }

  $|=1; # Needed to flush STDOUT on Windows cmd prior to calling ReadMode
  ReadMode('noecho');
  ReadMode('raw');
  my $master_pass = '';
  print $prompt;
  CHAR: while (1) {
    my $c;
    do {
      Time::HiRes::sleep(0.05);
    } until defined($c = ReadKey(-1));
    last if $c =~ m/[\n\r]/;
    if (ord($c) == 3) { # ^C
      print "\n";
      ReadMode('normal');
      return '';
    } elsif (ord($c) == 127 || ord($c) == 8) { # backspace (Linux/Windows)
      if (length($master_pass)) {
        print chr(8)." ".chr(8);
        chop($master_pass);
      }
      next CHAR;
    } elsif (ord($c) == 21) { # ^U
      my $passlen=length($master_pass);
      print chr(8)x$passlen." "x$passlen.chr(8)x$passlen;
      $master_pass = '';
      next CHAR;
    }
    if (length($echo_char)) { print $echo_char; }
    #print "*".ord($c);
    $master_pass .= $c;
  }
  ReadMode('normal');
  chomp $master_pass;
  print "\n";
  if (recent_sigint()) { return undef; } # Bail on SIGINT
  return $master_pass;
}

sub MyGetOpts {
  my %opts=();
  my $result = &GetOptions(\%opts, "kdb=s", "key=s", "histfile=s",
						"help", "h", "readonly");

  # If the user asked for help or GetOptions complained, give help and exit
  if ($opts{help} || $opts{h} || (! int($result))) {
    print GetUsageMessage();
    exit;
  }

  # Allow the user to override the history file
  if (defined($opts{histfile}) && length($opts{histfile})) {
    our $HISTORY_FILE = $opts{histfile};
  } else {
    if (lc($OSNAME) =~ m/^mswin/) {
      our $HISTORY_FILE = $ENV{USERPROFILE} . "/.$APP_NAME-history";
    } else {
      our $HISTORY_FILE = "~/.$APP_NAME-history";
    }
  }

  my @errs=();
  if ((length($opts{kdb}) && (! -e $opts{kdb}))) {
    push @errs, "for option --kdb=<file.kbd>, the file must exist.";
  }

  if ((length($opts{key}) && (! -e $opts{key}))) {
    push @errs, "for option --key=<file.key>, the file must exist.";
  }

  if (scalar(@errs)) {
    warn "There were errors:\n" .
	"  " . join("\n  ", @errs) . "\n\n";
    die &GetUsageMessage();
  }

  return \%opts;
}

sub GetUsageMessage {
  my $t="Usage: $APP_NAME [--kdb=<file.kdb>] [--key=<file.key>]\n" .
  "\n" .
  "    --help\tThis message.\n" .
  "    --kdb\tOptional KeePass database file to open (must exist).\n" .
  "    --key\tOptional KeePass key file (must exist).\n" .
  "    --histfile\tSpecify your history file (or perhaps /dev/null).\n" .
  "    --readonly\tRun in read-only mode; no changes will be allowed.\n" .
  "\n" .
  "Run kpcli with no options and type 'help' at its command prompt to learn\n" .
  "about kpcli's commands.\n" .
  "";
  return $t;
}

# Because Term::ShellUI has a fixed width (%20s) for the command length
# and we don't need nearly that much, we had to implement our own help
# function instead of using the built-in help_call() method.
sub my_help_call($) {
  my $term = shift @_;
  # @_ now holds: [Term::ShellUI->{commands}, <optional: specific command>]
  # If the user is asking for detailed help on a specific command, do that
  if (scalar(@_) > 1) {
    $term->help_call(undef, @_);
    return;
  }
  # If no specific command was requested, show the command summaries
  my $help = $term->get_all_cmd_summaries($term->commands());
  $help =~ s/^ {12}//gm; # Trim some leading spaces off of each line of output
  print $help;
  print "\n" .
	"Type \"help <command>\" for more detailed help on a command.\n";
  return 0;
}

########################################################################
# Command Completion Routines ##########################################
########################################################################

sub complete_groups {
  my $self = shift;
  my $cmpl = shift;
  our $state;

  # Place the string (token) that the user is trying to complete into $path.
  my $path = $cmpl->{tokens}->[$cmpl->{tokno}];
  # If the cursor isn't at the end of the sting, chop $path to that length.
  if (length($path) > $cmpl->{tokoff}) {
    $path = substr($path, 0, $cmpl->{tokoff});
  }

  my $srch_path=normalize_path_string($path);
  my @possibles = ();
  # If the path ends in a "/" (a directory) then we are looking for subirs,
  # else we are just looking to tab-complete a partial dir-name at this level.
  # Used only for /<tab> (the root dir is a special case)
  if ($srch_path =~ m/^$|^[.]$/) {
    @possibles = grep(/^[^\0]+$/,
				sort keys %{$state->{all_grp_paths_fwd}});
  # Used only for /..any/thing../<tab> (non-root directories)
  } elsif (defined($state->{all_grp_paths_fwd}->{$srch_path})) {
    # If the user is sitting on a dir without the trailing /, return that
    # now as the only option (/dir1/dir2<tab>). We do this because the
    # code later does not handle this case well at all. We do, however,
    # have to not do this for things like "ls <tab>" which is why we test
    # for length($path).
    if (length($path) && $path !~ m/\/$/) {
      __my_suppress_completion_append_character($self);
      return [ $cmpl->{str} . "/" ];
    }
    @possibles = grep(/^\Q$srch_path\E\0[^\0]+$/,
				sort keys %{$state->{all_grp_paths_fwd}});
  # Used for /../any/thing../foo<tab>
  } else {
    @possibles = grep(/^\Q$srch_path\E[^\0]*$/,
				sort keys %{$state->{all_grp_paths_fwd}});
  }

  # Loop over the possibilites doing required magic...
  my @results=();
  foreach my $opt (@possibles) {
    $opt=humanize_path($opt);
    if ($path =~ m/^(\/+)/) {	# Absolute path (easy case!)
      $opt=$1.$opt;
    } else {			# Path relative to pwd
      my $user_new_path=get_pwd() . "/" . $path;
      my $new_dir=normalize_path_string($user_new_path);
      # If the user's input does not resolve to a fully qualified
      # path then we need to pop off the last bit to get to that.
      if (! defined($state->{all_grp_paths_fwd}->{$new_dir})) {
        my @path=split(/\0/, $new_dir); pop @path;
        $new_dir = join("\0", @path);
      }
      $new_dir = humanize_path($new_dir);
      # Dirname requires "../." (Trailing dot) to give ".." in those cases!
      my $dirname_path=$path;
      if ($path =~ m/\/$/) { $dirname_path .= "."; }
      my $path_to_put_back=dirname($dirname_path) . "/";
      if ($new_dir eq '') {	# All the way at the root level
        $opt = $path_to_put_back . $opt;
      } else {			# Some non-root level (deeper)
        $opt=~s/^$new_dir\//$path_to_put_back/;
      }
      # Lop the leading "./" off the head if it was not user supplied
      if ($path !~ m/^[.]\// && $opt =~ m/^[.]\//) { $opt =~ s/^[.]\///; }
      # If the user did supply a leading "./" and we missed it, add it
      if ($path =~ m/^[.]\// && $opt !~ m/^[.]\//) { $opt = "./$opt"; }
    }
    push @results, "$opt/";
  }

  # Foreach possibility, we have to strip off the parts that are already
  # completed and then prepend the part that is looking to be completed,
  # from $cmpl->{str}.
  my @completions = ();
  foreach my $possibility (@results) {
    $possibility = normalize_path_string($possibility);
    $possibility =~ s/^\Q$srch_path\E\0?//;
    if (length($possibility)) {
      $possibility = $cmpl->{str} . humanize_path($possibility);
      if ($possibility !~ m/\/$/) { $possibility .= '/'; }
      push @completions, $possibility;
    }
  }

  # If we are about to return only one completion result, we need to first
  # test to see if any other subdirs are below it and, if so, suppress the
  # completion append character so that the user can keep tab completing
  # into lower level directories.
  if (scalar(@completions) == 1) {
    my @all_subdirs = grep(/^\Q$srch_path\E[^\0]*(\0[^\0]+)?/,
				sort keys %{$state->{all_grp_paths_fwd}});
    if (scalar(@all_subdirs) > 0) {
      __my_suppress_completion_append_character($self);
    }
  }

  return \@completions;
}

sub complete_entries {
  my $self = shift;
  my $cmpl = shift;
  our $state;

  # Place the string (token) that the user is trying to complete into $path.
  my $path = $cmpl->{tokens}->[$cmpl->{tokno}];
  # If the cursor isn't at the end of the sting, chop $path to that length.
  if (length($path) > $cmpl->{tokoff}) {
    $path = substr($path, 0, $cmpl->{tokoff});
  }

  my $srch_path=normalize_path_string($path);
  my @entries = grep(/^\Q$srch_path\E\0?[^\0]*$/,
				sort keys %{$state->{all_ent_paths_fwd}});
  # User can tab exactly at a directory level and with or without the
  # trailing slash, and so we need to normalize that, always ensuring that
  # the slash is inserted. We do that by setting the dir_level_sep here
  # and always removing any trailing slash sent in below (\0 on srch_path).
  # We do, however, have to not do this for things like "show <tab>" which
  # is why we test for length($path).
  my $dir_level_sep = '';
  if (defined($state->{all_grp_paths_fwd}->{$srch_path}) &&
				length($path) && $path !~ m/\/$/) {
    $dir_level_sep = '/';
  }
  # Foreach possibility, we have to strip off the parts that are already
  # completed and then prepend the part that is looking to be completed
  # by Term::ShellUI, from $cmpl->{str}.
  my @completions = ();
  foreach my $possibility (@entries) {
    $possibility =~ s/^\Q$srch_path\E\0?//;
    if (length($possibility)) {
      $possibility = $cmpl->{str} .$dir_level_sep. humanize_path($possibility);
      push @completions, $possibility;
    }
  }

  return \@completions;
}

sub complete_groups_and_entries {
  my $self = shift;
  my $cmpl = shift;

  my $groups = complete_groups($self,$cmpl);
  my $entries = complete_entries($self,$cmpl);

  # Merge and sort the groups and entries
  my @completions = sort (@{$groups}, @{$entries});
  return \@completions;
}

# In Term::ReadLine::Gnu, suppress_completion_append_character() works,
# but in Term::ReadLine::Perl and Term::ReadLine::Perl5 it does not, and
# so we get to the outcome via $readline::rl_completer_terminator_character.
sub __my_suppress_completion_append_character($self) {
  my $self = shift;
  if ($self->{term}->ReadLine eq 'Term::ReadLine::Gnu') {
    $self->suppress_completion_append_character();
  } else {
    # For Term::ReadLine::Perl
    # From Term/ReadLine/readline.pm
    #  - package readline;
    if (defined($readline::rl_completer_terminator_character)) {
      $readline::rl_completer_terminator_character='';
    }
    # For Term::ReadLine::Perl5
    # From Term/ReadLine/Perl5/readline.pm
    #  - package Term::ReadLine::Perl5::readline;"
    if (defined(
	$Term::ReadLine::Perl5::readline::rl_completer_terminator_character)) {
      $Term::ReadLine::Perl5::readline::rl_completer_terminator_character='';
    }
  }
}

########################################################################
# Rijndael encrypt/decrypt routines - borrowed from File::KeePass ######
########################################################################
sub decrypt_rijndael_cbc {
    my ($buffer, $key, $enc_iv) = @_;
    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC());
    $cipher->set_iv($enc_iv);
    $buffer = $cipher->decrypt($buffer);
    my $extra = ord(substr $buffer, -1, 1);
    substr($buffer, length($buffer) - $extra, $extra, '');
    return $buffer;
}
sub encrypt_rijndael_cbc {
    my ($buffer, $key, $enc_iv) = @_;
    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC());
    $cipher->set_iv($enc_iv);
    my $extra = (16 - length($buffer) % 16) || 16; # pad so we can trim
    $buffer .= chr($extra) for 1 .. $extra;
    return $cipher->encrypt($buffer);
}
sub composite_master_pass($$) {
  my ($pass, $key_file) = @_;

  # composite password in case of key file
  if (defined $key_file and length($key_file) and -f $key_file) {
    # KeePass v2.03 and higher has native key file support, and so we
    # use that if we have it.
    if (version->parse($File::KeePass::VERSION) >= version->parse('2.03')) {
      return [$pass, $key_file];
    }
    # TODO - at some point, when File::KeePass v2.03 is very mainstream,
    # the code to the end of this if block should be removed. It allowed
    # support for key files for *.kdb files before File::KeePass supported
    # that natively. File::KeePass now also supports that for *.kdbx.
    open(my $fh,'<',$key_file) || die "Couldn't open key file $key_file: $!\n";
    my $size = -s $key_file;
    read($fh, my $buffer, $size);
    close $fh;
    if (length($buffer) != $size) {
      die "Couldn't read entire key file contents of $key_file.\n";
    }

    $pass = substr(sha256($pass),0,32);
    if ($size == 32) {
      $pass .= $buffer;
    } elsif ($size == 64) {
      for (my $i = 0; $i < 64; $i += 2) {
        $pass .= chr(hex(substr($buffer,$i,2)));
      }
    } else {
      $pass .= substr(sha256($buffer),0,32);
    }
    # TODO - this marks the "end of the block" noted above.
  }

  return $pass;
}
sub put_master_passwd($) {
  my $master_pass = shift @_;
  our $state;
  $state->{'master_pass_key'}='';
  $state->{'master_pass_key'} .= chr(int(255 * rand())) for 1..16;
  $state->{'master_pass_enc_iv'}='';
  $state->{'master_pass_enc_iv'} .= chr(int(255 * rand())) for 1..16;
  $master_pass='CLEAR:' . $master_pass;
  $state->{'master_pass'}=encrypt_rijndael_cbc($master_pass,
		$state->{'master_pass_key'}, $state->{'master_pass_enc_iv'});
  return 0;
}
sub get_master_passwd() {
  our $state;
  my $master_pass=decrypt_rijndael_cbc($state->{master_pass},
		$state->{'master_pass_key'}, $state->{'master_pass_enc_iv'});
  if ($master_pass=~s/^CLEAR://) {
    return $master_pass;
  } else {
    die "Failed to properly decrypt my copy of the master password.\n";
  }
}

# This routine checks to see if the file has changed on disk and warns if so
sub warn_if_file_changed {
  our $state;

  my $file = $state->{kdb_file};
  if (! length($file)) { return 0; } # If no file was opened, don't warn
  my $file_md5 = Digest::file::digest_file_hex($file, "MD5");
  if ($state->{kdb_file_md5} ne $file_md5) {
    print color('bold yellow') . "WARNING:" . color('clear') .
        color('red') .
               " The file has changed on disk since kpcli opened it!\n" .
        "         It may be opened elsewhere. Continue anyway? [y/N] " .
        color('clear');
    my $key=get_single_key();
    print "\n";
    if (lc($key) ne 'y') {
      return -1;
    }
  }

  return 0;
}

sub generatePassword {
  my $be_silent = shift @_ || 0;
  my $password = generatePasswordFromDict($be_silent);
  if (! length($password)) {
    if (! $be_silent) {
      print color('yellow') .
	"Generated random characters instead of a words-based password.\n" .
	color('clear');
    }
    $password = generatePasswordGobbledygook(20);
  }
  return $password;
}

sub generatePasswordGobbledygook {
   my $length = shift;
   my @normal_chars=('a'..'z','A'..'Z',0..9);
   my @special_chars=qw(_);
   my $charset = join('', (@normal_chars,@special_chars));
   # Generate the password
   my $password = '';
   while (length($password) < $length) {
     $password .= substr($charset, (int(rand(length($charset)))), 1);
   }
   # Make sure that at least one special character appears
   my $sccc=join('', @special_chars);
   if ($password !~ m/[\Q$sccc\E]/) {
     my $sc=$special_chars[int(rand(length($sccc)))];
     substr($password,int(rand(length($password))), 1, $sc);
   }
   return $password
}

# Inspired by http://xkcd.com/936/
sub generatePasswordFromDict($) {
  my $be_silent = shift @_ || 0;
  my @words=();
  my $fh = new FileHandle;
  my @dict_files = qw(/usr/share/dict/words /usr/dict/words);
  DICTS: foreach my $dictfile (@dict_files) {
    if (-f $dictfile && -r $dictfile && open($fh,'<', $dictfile)) {
      @words = <$fh>;
      close($fh);
      last DICTS;
    }
  }
  if (scalar(@words) < 10000) {
    if (! $be_silent) {
      print color('yellow') .
	"No adequate dictionary found to generate a words-based password.\n".
	"These locations were checked:\n - ".join("\n - ", @dict_files)."\n" .
	color('clear');
    }
    return undef;
  }
  my $length_tries = 12;
  my $password='';
  do {
    my @passwords = ();
    my $word_tries=20;
    while (scalar(@passwords) < 4 && $word_tries-- > 0) {
      my $word = $words[int(rand(scalar(@words)))];
      chomp $word;
      $word =~ s/[^a-zA-Z0-9]//g;
      if (length($word) > 7) { next; } # Don't care for big words
      push @passwords, $word;
    }
    if (scalar(@passwords) == 4) {
      $password=join('.', @passwords);
    }
    #warn "LHHD: $password\n";
    if (length($password) < 27) { $password=''; } # Need a decent overall size
  } until (length($password) || $length_tries-- < 0);

  return $password;
}


#########################################################################
# Setup signal handling #################################################
#########################################################################
sub setup_signal_handling {
  our $state;

  # We only worry with signal handling for Term::ReadLine::Gnu
  if ($state->{'term'}->{term}->ReadLine ne 'Term::ReadLine::Gnu') {
    return 0;
  }

  # We don't want Term::Readline::Gnu catching signals, except for WINCH.
  # I really don't understand why, but I know via experimentation.
  my $term = $state->{'term'}->{term};
  $term->Attribs->{catch_signals}  = 0;
  $term->Attribs->{catch_sigwinch} = 1; # Window resizes
  $term->clear_signals();

  # Install a signal handler to catch SIGINT (^C). Unsafe signal handling
  # (through POSIX::SigAction) is required to deal with Term::ReadLine::Gnu.
  # We don't even try for other readlines due to their limited functionality.
  sigaction SIGINT, new POSIX::SigAction
    sub {
      our $state;
      # We could be using one of a couple of ReadLine terminals; the one
      # from Term::ShellUI ($state->{'term'}->{term}) or one from one of
      # our cli_NNN commands ($state->{active_readline}). We will assume
      # the Term::ShellUI one here, and override that below if needed.
      my $term = $state->{'term'}->{term};

      # Record in our state when a SIGINT was last received
      $state->{signals}->{INT} = [gettimeofday];

      # We need to pull the Carp longmess to see if we're sitting in a
      # a cli_XXXX function instead of at a readline prompt.
      my $mess = longmess();
      #print Dumper( $mess );
      if ($mess =~ m/main::(cli_\w+)\(/) {
        #warn "It appears that SIGINT was called from $1\n";
        #warn "LHHD: $mess\n";
        # If the cli_NNN has an active_readline we need to work with it
        if (defined($state->{active_readline})) {
          #warn "LHHD: in INT with active_readline\n";
          my $term = $state->{active_readline};
          $term->free_line_state();
          $term->cleanup_after_signal();
          $term->reset_after_signal();
          $term->Attribs->{line_buffer}=''; # Clear the buffer
          $term->Attribs->{done}=1;  # Ask readline to return immediately
        }
      } else { # If not in a cli_XXX(), assume a Term::ShellUI prompt
        my $yellow=color('yellow');
        my $clear=color('clear');
        #$term->echo_signal_char(SIGINT); # Puts ^C on the next line. :(
        # Trial and error on these readline_state values...  :(
        #warn "LHHD: " . sprintf($term->Attribs->{readline_state}) . "\n";
        if ($term->Attribs->{readline_state} == 262374) {
          print "^C$yellow   - use Ctrl-g to stop history search.$clear\n";
        } else {
          print "^C$yellow   - use the \"quit\" command to exit.$clear\n";
        }
        $term->free_line_state();
        $term->cleanup_after_signal();
        $term->reset_after_signal();
        $term->Attribs->{line_buffer}=""; # Clear the input buffer
        $term->forced_update_display();   # Force update the display
      }
      return 0;
    };

  # Handle signal TSTP - terminal stop (user pressing Ctrl-Z)
  sigaction SIGTSTP, new POSIX::SigAction
	  sub {
		our $state;
		my $term = $state->{'term'}->{term};
		my $mess = longmess();
		if ($mess =~ m/main::(cli_\w+)\(/ &&
				defined($state->{active_readline})) {
		  $term = $state->{active_readline};
		}
		$term->cleanup_after_signal();
		$term->reset_after_signal();
	  };
  # Handle signal CONT - continue signal (assuming after Ctrl-Z).
  sigaction SIGCONT, new POSIX::SigAction
	  sub {
		our $state;
		my $term = $state->{'term'}->{term};
		my $mess = longmess();
		if ($mess =~ m/main::(cli_\w+)\(/ &&
				defined($state->{active_readline})) {
		  $term = $state->{active_readline};
		}
		$term->cleanup_after_signal();
		$term->reset_after_signal();
		$term->forced_update_display(); # Force update the display
	  };
}

# Code consolidation function to runtime-load optional perl modules
sub runtime_load_module($$$) {
  my $rOPTIONAL_PM = shift @_;
  my $module = shift @_;
  my $rImportList = shift @_ || undef;
  my $iltxt = '';
  if (defined($rImportList) && ref($rImportList) ne 'ARRAY') {
    die "The rImportList param to runtime_load_module() must be an ARRAY ref\n";
  }
  if (defined($rImportList) && ref($rImportList) eq 'ARRAY' &&
						scalar(@$rImportList) > 0) {
    $iltxt = "('" . join("','", @{$rImportList}) . "')";
  }
  if (eval "require $module;$module->import($iltxt);1;" eq 1) {
    $rOPTIONAL_PM->{$module}->{loaded} = 1;
    return 1;
  } else {
    $rOPTIONAL_PM->{$module}->{loaded} = 0;
    return 0;
  }
}

# This routine runs down the list of our preferred Term::ReadLine::*
# modules and returns a new object from the first one that we find.
sub get_readline_term($$) {
  my $rOPTIONAL_PM = shift @_;
  my $app_name = shift @_;
  my @rl_modules = ();
  push @rl_modules, 'Term::ReadLine::Gnu';
  push @rl_modules, 'Term::ReadLine::Perl';
  push @rl_modules, 'Term::ReadLine::Perl5';
  my $rl_term = undef;
  my $hold_TERM=undef;
  MODULE: foreach my $module (@rl_modules) {
    # On MS Windows, Term::ReadLine::Perl and Term::ReadLine::Perl5 are
    # pretty good terminals but they behave badly if the environment
    # variable TERM=dumb, and so we override that here if needed.
    if (lc($OSNAME) =~ m/^mswin/ && $module =~ m/^Term::ReadLine::Perl5?/ &&
						$ENV{'TERM'} eq 'dumb') {
      $hold_TERM=$ENV{'TERM'};
      $ENV{'TERM'} = 'vt102';
    }
    if (runtime_load_module($rOPTIONAL_PM,$module,undef) eq 1) {
      $rl_term = eval "$module->new('$app_name');";
      last MODULE;
    } else {
      #warn "Loading $module failed\n";
      if (defined($hold_TERM)) { $ENV{'TERM'} = $hold_TERM; $hold_TERM=undef; }
    }
  }

  #if (! defined($rl_term)) { return undef; }
  if (! defined($rl_term)) {
    die "No usable Term::ReadLine::* modules found.\n" .
	"This list tried: " . join(', ', @rl_modules) . "\n";
  }

  # I don't like readline ornaments in kpcli
  $rl_term->ornaments(0);

  # I'm not sure that these are only needed on Windows, but I know they
  # are not needed on Linux so I'm trying to keep the scope narrow.
  if (lc($OSNAME) =~ m/^mswin/ &&
			$rl_term->ReadLine =~ m/Term::ReadLine::Perl5?/) {
    # For Term::ReadLine::Perl and Term::ReadLine::Perl we set
    # $readline::rl_scroll_nextline=0 on MS Windows.
    if (defined($readline::rl_scroll_nextline)) {
      $readline::rl_scroll_nextline=0;
    }
    if (defined($Term::ReadLine::Perl5::readline::rl_scroll_nextline)) {
      $Term::ReadLine::Perl5::readline::rl_scroll_nextline=0;
    }
  }

  # History
  # The Term::ReadLine::Perl* modules shove values into the history
  # file automtically. That causes two problems for kpcli:
  # 1) Term::ShellUI calls $term->addhistory() itself for each CLI
  #    command that it wants to store ih history (duplicates).
  # 2) We use readline() in places like cli_new, cli_edit, etc. and
  #    we do not want all those inputs in the history file (cruft).
  if ($rl_term->ReadLine eq 'Term::ReadLine::Perl') {
    no strict 'refs';
    *readline::add_line_to_history = sub { return undef; };
  }
  if ($rl_term->ReadLine eq 'Term::ReadLine::Perl5') {
    no strict 'refs';
    *Term::ReadLine::Perl5::readline::add_line_to_history = sub {return undef;}
  }

  if (defined($hold_TERM)) { $ENV{'TERM'} = $hold_TERM; }

  return $rl_term;
}

# Use simple magic recipes to identify relevant file types
sub magic_file_type($) {
  my $filename = shift @_;
  my $fh=new FileHandle;
  my $header='';
  if (open($fh, '<', $filename)) {
    my $n = read $fh, $header, 4;
    close $fh;
  }
  # KeePass
  # Recipe from https://github.com/glensc/file/blob/master/magic/Magdir/keepass
  # 0       lelong            0x9AA2D903      Keepass password database
  # >4       lelong            0xB54BFB65      1.x KDB
  # >>48       lelong            >0              \b, %d groups
  # >>52       lelong            >0              \b, %d entries
  # >>8       lelong&0x0f    1              \b, SHA-256
  # >>8       lelong&0x0f    2              \b, AES
  # >>8       lelong&0x0f    4              \b, RC4
  # >>8       lelong&0x0f    8              \b, Twofish
  # >>120       lelong            >0          \b, %d key transformation rounds
  # >4       lelong            0xB54BFB67      2.x KDBX
  if ($header =~ m/^\x03\xd9\xa2\x9a/) {
    return 'keepass';
  }
  # Password Safe v3
  # Recipe from https://github.com/glensc/file/blob/master/magic/Magdir/pwsafe
  if ($header =~ m/^PWS3/) {
    return 'pws3';
  }
  return undef;
}

########################################################################
# Unix-style, "touch" a file
########################################################################
sub touch_file {
  my $filename = shift @_;
  if (! -f $filename) {
    my $fh=new FileHandle;
    open($fh, "> $filename");
    close($fh);
  }
  my $sig_pipe_store=$SIG{'PIPE'};
  $SIG{'PIPE'} = 'IGNORE';
  my $now=time;
  my $retval=utime $now, $now, $filename;
  $SIG{'PIPE'} = $sig_pipe_store;
return($retval);
}

########################################################################
# POD ##################################################################
########################################################################

=head1 NAME

kpcli - A command line interface to KeePass database files.

=head1 DESCRIPTION

A command line interface (interactive shell) to work with KeePass
database files (http://http://en.wikipedia.org/wiki/KeePass).  This
program was inspired by my use of "kedpm -c" combined with my need
to migrate to KeePass. The curious can read about the Ked Password
Manager at http://kedpm.sourceforge.net/.

=head1 USAGE

Please run the program and type "help" to learn how to use it.

=head1 PREREQUISITES

This program requires these non-core modules:

C<Crypt::Rijndael> - libcrypt-rijndael-perl on Ubuntu 10.04

C<Term::ReadKey>   - libterm-readkey-perl on Ubuntu 10.04

C<Sort::Naturally> - libsort-naturally-perl on Ubuntu 10.04

C<File::KeePass>   - libfile-keepass-perl on Ubuntu 12.04

C<Term::ShellUI>   - libterm-shellui-perl on Ubuntu 12.10

It is recommended that you install C<Term::ReadLine::Gnu> which will
provide more fluid signal handling on Unix-like systems, making kpcli
robust to suspend, resume, and interupt - SIGSTP, SIGCONT and SIGINT.
That module is in the libterm-readline-gnu-perl package on Ubuntu.

You can optionally install C<Clipboard> and C<Tiny::Capture> to use the
clipboard features; http://search.cpan.org/~king/Clipboard/ and
libcapture-tiny-perl on Ubuntu 10.04.

You can optionally install C<Data::Password> to use the pwck feature
(Password Quality Check); libdata-password-perl on Ubuntu 10.04.

On MS Windows, you can optionally install C<Win32::Console::ANSI> to get
ANSI colors in Windows cmd terminals. Strawberry Perl 5.16.2 was used
for the kpcli port to Windows and, using cpanminus, one can install all
of kpcli's dependencies, sans Term::ReadLine::Gnu which is optional for
kpcli and not supported on MS Windows.

=head1 CAVEATS AND WORDS OF CAUTION

Only interoperability tested with KeePassX (http://www.keepassx.org/).

Prior to version 2.3, File::KeePass had a bug related to some "unknown"
data that KeePassX stores in group records. For File::KeePass < v2.3,
kpcli deletes those unknown data when saving. Research in the libkpass
(http://libkpass.sourceforge.net/) source code revealed that what early
versions of File::KeePass classifies as "unknown" are the times for
created/modified/accessed/expires as well as "flags" (id=9), but only
for groups; File::KeePass handled those fields just fine for entries.
I found no ill-effect from dropping those fields when saving and so
that is what kpcli does to work around the File::KeePass bug, if kpcli
is using File::KeePass < v2.3.

=head1 BUGS

=head2 Using Ctrl-D to Exit

Versions of Term::ShellUI prior to v0.9. do not have the ability to trap
Ctrl-D exits by the client program. I submitted a patch to remedy that
and it made it into Term::ShellUI v0.9. Please upgrade if kpcli asks you to.

=head2 Multiple Entries or Groups With the Same Name in the Same Group

This program does not support multiple entries in the same group having
the exact same name, nor does it support multiple groups at the same
level having the same name, and it likely never will. KeepassX does
support those.  This program detects and alert when an opened database
file has those issues, but it does not refuse to save (overwrite) a file
that is opened like that. Saves are actually safe (no data loss) as long
as the user has not touched one of the duplicately-named items.

=head1 AUTHOR

Lester Hightower <hightowe at cpan dot org>

=head1 LICENSE

This program may be distributed under the same terms as Perl itself.

=head1 CREDITS

Special thanks to Paul Seamons, author of C<File::KeePass>, and to
Scott Bronson, author of C<Term::ShellUI>. Without those two modules
this program would not have been practical for me to author.

=head1 CHANGELOG

 2010-Nov-28 v0.1 - Initial release.
 2010-Nov-28 v0.2 - Encrypt the master password in RAM.
 2010-Nov-29 v0.3 - Fixed master password encryption for saveas.
 2010-Nov-29 v0.4 - Fixed code to work w/out Term::ReadLine::Gnu.
                    Documented File::KeePass v0.1 hierarchy bug.
 2010-Nov-29 v0.5 - Made find command case insensitive.
                    Bugfix in new command (path regex problem).
 2010-Nov-29 v0.6 - Added lock file support; warn if a lock exists.
 2010-Dec-01 v0.7 - Further documented the group fields that are
                     dropped, in the CAVEATS section of the POD.
                    Sort group and entry titles naturally.
 2010-Dec-23 v0.8 - Worked with File::KeePass author to fix a couple
                     of bugs and then required >=v0.03 of that module.
                    Sorted "/_found" to last in the root group list.
                    Fixed a "database changed" state bug in cli_save().
                    Made the find command ignore entries in /Backup/.
                    Find now offers show when only one entry is found.
                    Provided a patch to Term::ShellUI author to add
                     eof_exit_hook and added support for it to kpcli.
 2011-Feb-19 v0.9 - Fixed bugs related to spaces in group names as
                     reported in SourceForge bug number 3132258.
                    The edit command now prompts to save on changes.
                    Put scrub_unknown_values_from_all_groups() calls
                     back into place after realizing that v0.03 of
                    File::KeePass did not resolve all of the problems.
 2011-Apr-23 v1.0 - Changed a perl 5.10+ regex to a backward-compatable
                     one to resolve SourceForge bug number 3192413.
                    Modified the way that the /Backup group is ignored
                     by the find command to stop kpcli from croaking on
                     multiple entries with the same name in that group.
                     - Note: There is a more general bug here that
                             needs addressing (see BUGS section).
                    An empty title on new entry aborts the new entry.
                    Changed kdb files are now detected/warned about.
                    Tested against Term::ShellUI v0.9, which has my EOF
                     hook patch, and updated kpcli comments about it.
                    Term::ShellUI's complete_history() method was
                     removed between v0.86 and v0.9 and so I removed
                     kpli's call to it (Ctrl-r works for history).
                    Added the "icons" command.
 2011-Sep-07 v1.1 - Empty DBs are now initialized to KeePassX style.
                    Fixed a couple of bugs in the find command.
                    Fixed a password noecho bug in the saveas command.
                    Fixed a kdb_has_changed bug in the saveas command.
                    Fixed a cli_open bug where it wasn't cli_close'ing.
                    Fixed variable init bugs in put_master_passwd().
                    Fixed a false warning in warn_if_file_changed().
 2011-Sep-30 v1.2 - Added the "export" command.
                    Added the "import" command.
                    Command "rmdir" asks then deletes non-empty groups.
                    Command "new" can auto-generate random passwords.
 2012-Mar-03 v1.3 - Fixed bug in cl command as reported in SourceForge
                     bug number 3496544.
 2012-Apr-17 v1.4 - Added key file support based on a user contributed
                     patch with SourceForge ID# 3518388.
                    Added my_help_call() to allow for longer and more
                     descriptive command summaries (for help command).
                    Stopped allowing empty passwords for export.
 2012-Oct-13 v1.5 - Fixed "help <foo>" commands, that I broke in v1.4.
                    Command "edit" can auto-generate random passwords.
                    Added the "cls" and "clear" commands from a patch
                     with SourceForge ID# 3573930.
                    Tested compatibility with File::KeePass v2.03 and
                     made minor changes that are possible with >=2.01.
                    With File::KeePass v2.03, kpcli should now support
                     KeePass v2 files (*.kdbx).
 2012-Nov-25 v1.6 - Hide passwords (red on red) in the show command
                     unless the -f option is given.
                    Added the --readonly command line option.
                    Added support for multi-line notes/comments;
                     input ends on a line holding a single ".".
 2013-Apr-25 v1.7 - Patched to use native File::KeePass support for key
                     files, if the File::KeePass version is new enough.
                    Added the "version" and "ver" commands.
                    Updated documentation as Ubuntu 12.10 now packages
                     all of kpcli's dependencies.
                    Added --histfile command line option.
                    Record modified times on edited records, from a
                     patch with SourceForge ID# 3611713.
                    Added the -a option to the show command.
 2013-Jun-09 v2.0 - Removed the unused Clone module after a report that
                     Clone is no longer in core Perl as of v5.18.0.
                    Added the stats and pwck commands.
                    Added clipboard commands (xw/xu/xp/xx).
                    Fixed some long-standing tab completion bugs.
                    Warn if multiple groups or entries are titled the
                     same within a group, except for /Backup entries.
 2013-Jun-10 v2.1 - Fixed several more tab completion bugs, and they
                     were serious enough to warrant a quick release.
 2013-Jun-16 v2.2 - Trap and handle SIGINT (^C presses).
                    Trap and handle SIGTSTP (^Z presses).
                    Trap and handle SIGCONT (continues after ^Z).
                    Stopped printing found dictionary words in pwck.
 2013-Jul-01 v2.3 - More readline() and signal handling improvements.
                    Title conflict checks in cli_new()/edit()/mv().
                    Group title conflict checks in rename().
                    cli_new() now accepts optional path&|title param.
                    cli_ls() can now list multiple paths.
                    cli_edit() now shows the "old" values for users
                     to edit, if Term::ReadLine::Gnu is available.
                    cli_edit() now aborts all changes on ^C.
                    cli_saveas() now asks before overwriting a file.
 2013-Nov-26 v2.4 - Fixed several "perl -cw" warnings reported on
                     2013-07-09 as SourceForge bug #9.
                    Bug fix for the cl command, but in sub cli_ls().
                    First pass at Strawberry perl/MS Windows support.
                     - Enhanced support for Term::ReadLine::Perl
                     - Added support for Term::ReadLine::Perl5
                    Added display of expire time for show -a.
                    Added -a option to the find command.
                    Used the new magic_file_type() in a few places.
                    Added generatePasswordFromDict() and "w" generation.
                    Added the -v option to the version command.
                     - Added the versions command.

=head1 TODO ITEMS

  Consider http://search.cpan.org/~sherwin/Data-Password-passwdqc/
  for password quality checking.

  Consider adding searches for expired entries and possibly also for
  created, modified, and access times older than a user supplied time.

  Consider adding import support for Password Safe v3 files using
  http://search.cpan.org/~tlinden/Crypt-PWSafe3/. May have already
  done this if the unpackaged dependencies list was not so long.

=head1 OPERATING SYSTEMS AND SCRIPT CATEGORIZATION

=pod OSNAMES

Unix-like
 - Written and tested on Ubuntu Linux 10.04.1 LTS.
 - Known to work on many other Linux and *BSD distributions.

Microsoft Windows
 - As of v2.4, MS Windows is also supported.
 - Tested and compiled on Strawberry Perl 5.16.2 on Windows 7.

=pod SCRIPT CATEGORIES

C<UNIX/System_administration>, C<Win32/Utilities>

