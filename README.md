# webapp-scanner

A webapplication scanner that detects all outdated webapps on a server.

## Purpose

This script scans the user directories and reports the installed CMS packages and what version it is running. It can be set to report just outdated packages and scan specific users. It has the ability to search for common versions of the following packages:

- WordPress
- Typo3
- Joomla
- Drupal
- e107
- Mambo
- Mediawiki
- OpenX
- osCommerce2
- phpBB3
- Piwigo
- Redmine
- X-Cart
- XOOPS
- ZenCart

Additional packages can be added by adding a function with the signature to identify the package.

## Installation

sample installation:

```bash
$ cd /usr/src/
$ git clone https://github.com/onlime/webapp-scanner.git webapp-scanner
$ cd webapp-scanner
$ chmod +x webapp-scanner.sh
$ ./webapp-scanner.sh
```

That's it. If you wish to scan all your customers homes, make sure you run this as root. It won't alter any files on your system, simply scan it.

## Usage

```bash
webapp-scanner.sh
```
Default with no flags will scan all users and report all matches.
Versions will be colorized based on how old they are, but on a large server this list can be huge.

```bash
webapp-scanner.sh --outdated
```
Limits the list to outdated installs, generally more useful.

```bash
webapp-scanner.sh --user user1
```
Limits the scan to a specific user or list of users, should be space separated list surrounded by quotes. ie "user1 user2 user3".
Quotes are not required if you only want to scan a single user.
You can now use this with core managed setups, any user added here will check against the passwd file and scan their entire homedir.

```bash
webapp-scanner.sh --directory /var/www/some/dir
```
Limits the scan to a specific directory or list of directories, should be space separated list surrounded by quotes. ie "/home/user1 /home/user2 /home/user3".
Quotes are not required if you only want to scan a single directory.
Not sure about spaces in directory names.
Although /home/* will work, due to bash expansion the counter will be broken during the scan (will show 2/1 or whatnot).

```bash
webapp-scanner.sh --report > report.txt
```
Drops the bash coloring so you can export to a text file, otherwise you need to cat the file so that bash will strip the color codes.

```bash
webapp-scanner.sh --csv
```
Exports to a CSV file, should work most of the time.

```bash
webapp-scanner.sh --sigs
```
This will return the current signatures and the version information.
Good way of checking what version it is expecting to find.

```bash
webapp-scanner.sh --help
```
If all else fails, this prints out the help message so you can get the basic usage.

Also you can combine most flags together, e.g.:

```bash
webapp-scanner.sh --outdated --user user1 --report > outdated.txt
```

## Questions

### CMS Not Found

It is not uncommon for CMS packages to not be identified by the script (read Joomla). This happens because the script tries to identify a package based on a file signature. These CMS packages (read Joomla) change their structure drastically with every release. This does make it easier to identify a specific version set, but makes it really hard to identify every version.

### Signature match but no version returned

This means that the program matched a signature but the version was not parse-able. This can indicate either major change in the structure of the version file or the file has been corrupted (ie hacked).

### Why are you not scanning for XYZ?

Right now the script scans for programs that I have encountered on a regular basis. I tried to get some of the other major packages too. One sure fire way for me to not have a signature is if the package is closed source (ie you can not download it online). Most likely we will not be making signatures for this type of package unless we notice that multiple customers are having problems with hacks using this package and we can look at the source on the server itself.

### I am bored and want to make a signature

I imagine that most people will not get this bored, but if you really want to the signature function is fairly easy to create if you can identify the CMS and the version is readily available from a text file.

Here is the signature for wordpress as an example:

```bash
function wordpress {
    #$1 directory to scan
    #$2 scan string
    idfiles=$(find  $1 -name wp-config.php | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ -e "$loc/wp-includes/version.php" ]]; then
            insver=$(grep "wp_version =" $loc/wp-includes/version.php | cut -d "'" -f2)
            printresult $2 "$insver" "$loc"
        fi
    done
}
```

Basically the id should search ```$1``` for a specific file name or a signature inside the file and return the base path for that install. There are other examples if the identifying file is not in the base directory.

Then it should search for the version file, if it exists it should parse the version and pass it to printresult.

At that point you just need to include it in the scan by adding an entry at the top of the file:

```bash
scans="$scans wordpress;WordPress;3.8;3.8.1"
```

The format for this is "function name;Package Name;Minimum Version;Current Version". Package name is what is displayed, minimum version will highlight yellow if greater then but less then current version. If the version is less then the Minimum Version it will highlight red. If the version is greater then the Current Version it will still highlight green.

Enjoy!
