# webapp-scanner

A webapplication scanner that detects all outdated webapps on a server.

## Credits

This project was forked from [VersionFinder by James Dooley](http://g33kinfo.com/info/archives/5981). All credits go to James.

## Purpose

This script scans the user directories and reports the installed CMS packages and what version it is running. It can be set to report just outdated packages and scan specific users. It has the ability to search for common versions of the following packages:

- [WordPress](http://wordpress.org/)
- [Typo3](http://typo3.org/)
- [Joomla](http://www.joomla.org/)
- [Drupal](https://drupal.org)
- [e107](http://e107.org/)
- [Mambo](http://www.mamboserver.com/)
- [MediaWiki](http://www.mediawiki.org)
- [OpenX](http://openx.com/)
- [osCommerce2](http://www.oscommerce.com/)
- [phpBB3](https://www.phpbb.com/)
- [Piwigo](http://piwigo.org/)
- [Redmine](http://www.redmine.org/)
- [X-Cart](http://www.x-cart.com/)
- [XOOPS](http://www.xoops.org/)
- [ZenCart](https://www.zen-cart.com/)

Additional packages can be added by adding a function with the signature to identify the package.

## Installation

sample installation:

```bash
$ cd /opt/
$ git clone https://github.com/onlime/webapp-scanner.git webapp-scanner
$ cd webapp-scanner
$ chmod +x webapp-scanner.sh
$ ./webapp-scanner.sh
```

That's it. If you wish to scan all your customers homes, make sure you run this as root. It won't alter any files on your system, simply scan it.

For more convenience, add the following alias to your ```~/.bashrc``` or globally to ```/etc/profile```:

```bash
alias webappscanner='/opt/webapp-scanner/webapp-scanner.sh'
```

## Usage

```bash
webappscanner
```
Default with no flags will scan all users and report all matches.
Versions will be colorized based on how old they are, but on a large server this list can be huge.

```bash
webappscanner --outdated
```
Limits the list to outdated installs, generally more useful.

```bash
webappscanner --user user1
```
Limits the scan to a specific user or list of users, should be space separated list surrounded by quotes. ie "user1 user2 user3".
Quotes are not required if you only want to scan a single user.
You can now use this with core managed setups, any user added here will check against the passwd file and scan their entire homedir.

```bash
webappscanner --directory /var/www/some/dir
```
Limits the scan to a specific directory or list of directories, should be space separated list surrounded by quotes. ie "/home/user1 /home/user2 /home/user3".
Quotes are not required if you only want to scan a single directory.
Not sure about spaces in directory names.
Although /home/* will work, due to bash expansion the counter will be broken during the scan (will show 2/1 or whatnot).

```bash
webappscanner --report > report.txt
```
Drops the bash coloring so you can export to a text file, otherwise you need to cat the file so that bash will strip the color codes.

```bash
webappscanner --csv
```
Exports to a CSV file, should work most of the time.

```bash
webappscanner --sigs
```
This will return the current signatures and the version information.
Good way of checking what version it is expecting to find.

```bash
webappscanner --help
```
If all else fails, this prints out the help message so you can get the basic usage.

Also you can combine most flags together, e.g.:

```bash
webappscanner --outdated --user user1 --report > outdated.txt
```

## Output

####default output (colorized)

sample output:

```
# webappscanner --directory /var/www/
Typo3_4.5	4.5.25		4.5.32		/var/www/web123/public_html/www/
Typo3_4.5	4.5.30		4.5.32		/var/www/web345/public_html/www/
Typo3_4.7	4.7.17		4.7.17		/var/www/web678/public_html/www/
Joomla_1.5	1.5.15		1.5.999		/var/www/web111/public_html/old/
Joomla_1.5	1.5.26		1.5.999		/var/www/web222/public_html/www/
Joomla_3.2	3.1.5		3.2.2		/var/www/web101/public_html/www/
Joomla_3.2	3.0.3		3.2.2		/var/www/web202/public_html/www/
Joomla_3.2	3.2.2		3.2.2		/var/www/web303/public_html/relaunch/
WordPress	3.8		3.8.1		/var/www/web110/public_html/www/
WordPress	3.8.1		3.8.1		/var/www/web120/public_html/www/
```

####csv output

In addition to the default output, we will get an additional version status code:

- 0: OK (version equals or is greater than current version)
- 1: WARNING (version is greater than minimal version but not >= current version)
- 2: CRITICAL (version is lower than minimal version)

sample output:

```
# webappscanner --directory /var/www/ --csv
Typo3_4.5,4.5.25,4.5.32,1,/var/www/web123/public_html/www/
Typo3_4.5,4.5.30,4.5.32,1,/var/www/web345/public_html/www/
Typo3_4.7,4.7.17,4.7.17,0,/var/www/web678/public_html/www/
Joomla_1.5,1.5.15,1.5.999,1,/var/www/web111/public_html/old/
Joomla_1.5,1.5.26,1.5.999,1,/var/www/web222/public_html/www/
Joomla_3.2,3.1.5,3.2.2,2,/var/www/web101/public_html/www/
Joomla_3.2,3.0.3,3.2.2,2,/var/www/web202/public_html/www/
Joomla_3.2,3.2.2,3.2.2,0,/var/www/web303/public_html/relaunch/
WordPress,3.8,3.8.1,1,/var/www/web110/public_html/www/
WordPress,3.8.1,3.8.1,0,/var/www/web120/public_html/www/
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
