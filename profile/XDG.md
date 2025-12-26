# XDG

XDG stands for "X Desktop Group," which was the original name of the organization now known as freedesktop.org. Freedesktop.org is a project that aims to provide interoperability and shared standards for desktop environments on Linux and other Unix-like operating systems. The XDG Base Directory Specification is one of these standards, focusing on defining common locations for user files, such as configuration files, data files, and cache files, to improve desktop environment consistency and application interoperability.

[Dotfiles](https://wiki.archlinux.org/title/Dotfiles)

[XDG_Base_Directory](https://wiki.archlinux.org/title/XDG_Base_Directory)


The XDG Base Directory Specification, developed by the Free Desktop Project, aims to standardize the file system hierarchy for Linux and Unix-like operating systems, particularly for user-specific files such as configuration files, data files, and cache files. The primary purposes and benefits of the XDG specification include:

**Organization**: It helps organize user files and directories in a more structured and predictable manner, making it easier for users and applications to locate and manage files.

**Clutter Reduction**: By centralizing the locations of various types of files, the XDG specification helps reduce clutter in the user's home directory, avoiding the proliferation of hidden files and directories directly under the home directory.

**Portability**: Standardizing the locations of user-specific files improves the portability of applications and user settings between different systems and installations, as it's clearer where to find and store user-specific data.

**Flexibility and Control**: Users and system administrators gain more control over where files are stored. For example, they can easily redirect cache files to a temporary filesystem or a separate disk without affecting the rest of the system's configuration.

**Simplifies Backup and Migration**: By segregating user data, configuration, and cache into specific directories, it simplifies the process of backing up and migrating user-specific settings and data. Users can back up or migrate their configuration and data files without having to sift through unrelated files.

**Enhanced Security and Cleanup**: The specification allows for more straightforward cleanup of cached and temporary files and can enhance security by clearly distinguishing between executable code, configuration files, and user data.

The XDG Base Directory Specification primarily defines the following environment variables to indicate directory paths:


**XDG_CONFIG_HOME**: User-specific configuration files.  
**XDG_CACHE_HOME**: User-specific non-essential (cache) data.  
**XDG_DATA_HOME**: User-specific data files.  
**XDG_RUNTIME_DIR**: User-specific runtime files and other file objects.  
**XDG_CONFIG_DIRS**: Preference-ordered set of base directories to search for configuration files in addition to the XDG_CONFIG_HOME base directory.  
**XDG_DATA_DIRS**: Preference-ordered set of base directories to search for data files in addition to the XDG_DATA_HOME base directory.  

```
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_RUNTIME_DIR="$HOME/.runtime"
# Set these if you need to, but they often can be left as system defaults
# export XDG_CONFIG_DIRS="/etc/xdg"
# export XDG_DATA_DIRS="/usr/local/share:/usr/share"
```

By adhering to the XDG Base Directory Specification, application developers contribute to a more consistent, manageable, and secure desktop environment for users.