dotfiles
========

Here lies my own little collection of `dotfiles`. In contrast to many other `dotfiles` repositories, I've setup mine with slightly different objectives which reflect my occupation as a DevOps engineer versus a pure developer.


Objectives
----------

My primary occupation is that of a sysadmin and so I often find myself working on many different systems. This introduces some key objectives I've tried to ensure my `dotfiles` meet:

* **Ease of access**  
  GitHub makes this easy by providing access to ZIP files of each branch in a repository. While a Git clone is strongly preferable, if this is too much effort or otherwise problematic, simply downloading and unpacking the ZIP archive is a helpful fallback.
* **Ease of setup**  
  A long or manual installation or removal process is painful and time-consuming. An automated approach is essential so that after downloading or cloning the repository installation is quick and easy, with removal if necessary similarly straightforward.
* **Portability**  
  It's all too easy for platform assumptions to seek into configurations. I've tried my best to avoid such assumptions so that all configurations work on platforms where the underlying application or library is supported, or at least degrade gracefully.


Management
----------

I've settled on using [Stow](https://www.gnu.org/software/stow/) to manage my `dotfiles` for the following attributes:

* **Compatible**  
  Most Unix-like systems have [Perl](https://www.perl.org/) installed by default and Stow itself has no peculiar dependencies.
* **Portable**  
  Stow can be included in the repository and subsequently stow itself into a location in the user's `PATH` for a quick bootstrap!
* **Organised**  
  Stow makes keeping the repository organised simple, with each directory containing the configuration files for a specific program or library.
* **Granular**  
  Stow operates on chosen directories allowing for only a desired subset of application or library configurations to be installed.
* **Revertible**  
  Stow can undo the changes it makes, ensuring that leaving the system in the same state as it was originally is trivial to do.
* **Stateless**  
  Stow doesn't need to maintain any state between executions which helps to keep the system simple, and consequently less likely to break.
* **Lightweight**  
  Stow is fast, unintrusive, and at the time of writing the script comes in at a mere ~28KB!


Tested Environments
-------------------

The following environments are known to work:

 * [Cygwin](https://www.cygwin.com/) *(1.7 or newer)*
 * [FreeBSD](https://www.freebsd.org/) *(8.3 or newer)*
 * [Linux](https://www.kernel.org/) *([Ubuntu](http://www.ubuntu.com/) 12.04 or newer)*
 * [OS X](https://www.apple.com/osx/) *(10.9 or newer)*
 * [Windows](https://www.microsoft.com/windows) *(Windows 7/Server 2008 R2 or newer)*


Thanks To
---------

The numerous people whose `dotfiles` served as inspiration or templates for my own!

Special mentions to:

* [Yuki Izumi](https://github.com/kivikakk)
* [Mathias Bynens](https://github.com/mathiasbynens)
* [Sorin Ionescu](https://github.com/sorin-ionescu)
