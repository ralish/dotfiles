dotfiles
========

Here lies my own little collection of dotfiles. In contrast to many other dotfiles repositories I've setup mine with slightly different objectives which reflect my occupation as a DevOps engineer versus a pure developer.


Objectives
==========

One of my primary occupations is that of a systems administrator which means I often find myself working on many different systems. This introduces some key objectives I've tried to ensure my dotfiles repository meets:

1.  Ease of access

    My dotfiles should be easy to access. GitHub makes this easy by providing access to a ZIP file of a given branch from the repository in the event a system lacks Git. Obviously, Git is strongly preferable, but it's helpful to still have a method of access in the event a system lacks Git and installing it isn't desirable (e.g. a production server where changes shouldn't be made lightly).

2.  Ease of setup

    My dotfiles should be easy to setup. I don't want to have to waste time symlinking files/directories manually into the correct places. The inverse is equally true as I don't wish to have to manually undo any changes either. This means we need some sort of minimalist setup script or framework to manage this. I've settled on GNU Stow for now as while not perfect it meets most requirements.

3.  Portability

    I frequently work on Linux, BSD, Mac and occasionally more esoteric systems. My dotfiles should ideally work on all of them. Where settings may cause problems on other systems functionality should ideally degrade gracefully (ie. the setting is ignored versus error prompts that require intervention).


Requirements
============

I've settled on using [GNU Stow](http://www.gnu.org/software/stow/) to manage my dotfiles for now as while not perfect it broadly meets most of my requirements. On the downside, many/most systems don't have it by default. However, this is a worth trade-off for the following attributes:

1.  Compatible

    Nearly all Unix-like systems have Perl installed by default and Stow itself has no peculiar dependencies. This means installing it whenever required is generally straight-forward and typically has no additional dependencies. All modern Linux distributions can be expected to have packages as does FreeBSD via [Ports](http://www.freshports.org/) and OS X via [Homebrew](http://brew.sh/).

2.  Lightweight

    Stow is not "expensive" to run nor does it require installing a large ecosystem of software in the case of Ruby environments or similar. It's both fast and unintrusive to the extent it's a single script file with basic Perl dependencies.

3.  Organised

    Stow easily facilitates keeping the repository organised with each folder containing the configuration files for a specific application. This makes choosing to symlink only specific configurations trivial; a common case when moving between systems where some programs may not be present or existing configuration shouldn't be modified. Obviously, there are other methods one could use to organise the repository but this one seems to be a good fit across multiple systems.

4.  Reversion

    Stow can easily undo changes by passing in an extra parameter to the program. This makes leaving the system in a pristine state as it was before we started working on it trivially easy to do.

5.  Stateless

    Stow doesn't need to maintain any state between runs which helps to keep the system simple and consequently less likely to break in "interesting" ways.


Thanks To
=========

The numerous people whose dotfiles I copied. Special mentions to:

* [Yuki Izumi](https://github.com/kivikakk)
* [Mathias Bynens](https://github.com/mathiasbynens)
