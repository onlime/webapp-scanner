#!/bin/bash
# 
# Webapp Scanner by Onlime Webhosting, http://www.onlime.ch
# Locates common web programs on a server and checks the version to see if it is up to date
#
# based on / credits to:
# Software Version finder by James Dooley
# http://g33kinfo.com/info/archives/5981
#

# Signature scanning configuration (This should not need to be updated)
# Format is function;Display_Name;Minimum_Version;Current_Version;Vendor_Url
# Do note that there can not be spaces in the ID strings.
scans=""
scans="$scans typo3_45;Typo3;4.5;4.5.40"
scans="$scans typo3_47;Typo3;4.7;4.7.20"
scans="$scans typo3_60;Typo3;6.0;6.2.12"
scans="$scans typo3_61;Typo3;6.1;6.2.12"
scans="$scans typo3_62;Typo3;6.2;6.2.12"
scans="$scans drupal7;Drupal;7;7.37"
scans="$scans drupal6;Drupal;6;6.33"
# e107 2.0.0 is alpha not adding until released
scans="$scans e107;e107;1;1.0.4"
scans="$scans joomla15;Joomla;1.5;1.5.999"     # EOL; No longer offered on site
scans="$scans joomla17;Joomla;1.7.999;1.7.999" # EOL; No longer offered on site
scans="$scans joomla25;Joomla;2.5;2.5.27"
scans="$scans joomla32;Joomla;3.2;3.4.1"
scans="$scans joomla33;Joomla;3.3;3.4.1"
scans="$scans joomla34;Joomla;3.4;3.4.1"
scans="$scans mambo;MamboCMS;4.6;4.6.5"
scans="$scans mediawiki;MediaWiki;1.24;1.25.1"
scans="$scans openx;OpenX/Revive;3.0;3.0.2"
scans="$scans oscommerce2;osCommerce;2.3;2.3.4"
scans="$scans phpbb3;phpBB;3.1;3.1.4"
scans="$scans piwigo;Piwigo;2.7;2.7.1"
scans="$scans redmine;Redmine;2.5;2.5.3"
# vBull has 3.8 and 5.0 lines, due to closed source I am not able to create signatures
scans="$scans vbulletin4;vBulletin;4.2;4.2.2"
scans="$scans wordpress;WordPress;4.0;4.2.2"
scans="$scans xcart;X-Cart;5.0;5.0.11"
scans="$scans xoops;XOOPS;2.5;2.5.6"
scans="$scans zencart;ZenCart;1.5;1.5.3"


function getcpanelusers {
    cpanelusers=$(/bin/ls -A1 /var/cpanel/users/)
    echo "$cpanelusers"
}

function getcpaneldir {
    #$1 user name
    echo $(getent passwd $1 | cut -d : -f6)
}

function getcoredir {
    #$1 user name
    echo $(getent passwd $1 | cut -d : -f6)
}

function getpleskdomains {
    pleskdomains=$(/bin/ls -A1 /var/www/vhosts)
    echo "$pleskdomains"
}

function getcoredomains {
    apache_config=$(`which httpd` -V 2>/dev/null)
    if [[ $apache_config ]]; then
        apache_config_file=$(echo "$apache_config" | grep HTTPD_ROOT | cut -d '"' -f2)"/"$(echo "$apache_config" | grep SERVER_CONFIG_FILE | cut -d '"' -f2)
        return
    fi
    nginx_config=$(`which nginx` -V 2>/dev/null)
    if [[ $nginx_config ]]; then
        nginx_config_file=$(for i in $(echo "$nginx_config"); do grep "confpath" | cut -d '=' -f2; done)
        return
    fi
}

# Compares two version strings
#
# vercomp VERSION1 VERSION2
#
# Returns 0 if VERSION1 is equals VERSION2.
# Returns 1 if VERSION1 is greater than VERSION2.
# Returns 2 if VERSION1 is lower than VERSION2.
function vercomp {
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i< ${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    return 0
}

# Compares two version strings.
#
# Returns 0 if program version is equal or greater than check version.
# Returns 1 if program version is lower than check version.
#
# TODO: currently, this is no replacement for the above vercomp function as
# some systems (e.g. OSX 10.9) still use a very outdated version of GNU sort 
# without -V, --version-sort support.
#version_compare() {
#    local version=$1 check=$2
#    local winner=$(echo -e "$version\n$check" | sed '/^$/d' | sort -Vr | head -1)
#    [[ "$winner" = "$version" ]] && return 0
#    return 1
#}

# Checks the version status in comparison to the minimal
# required version and the current version.
#
# verstatus VERSION MINVER CURVER
#
# returns
# 0: OK (version equals or is greater than current version)
# 1: WARNING (version is greater than minimal version but not >= current version)
# 2: CRITICAL (version is lower than minimal version)
function verstatus {
    local version=$1 minver=$2 curver=$3
    vercomp $version $curver;
    if [[ $? -eq 2 ]]; then
        vercomp $version $minver
        if [[ $? -eq 2 ]]; then
            # CRITICAL
            return 2
        else
            # WARNING
            return 1
        fi
    else
        # OK
        return 0
    fi
}

function init {
    if [[ $specificdirectory ]]; then
        output=""
        accounts=$(echo "$specificdirectory" | wc -w)
        curacct=0
        for directory in $specificdirectory; do
            curacct=$(( $curacct + 1 ))
            echo -e "\r\e[0;32m===[$curacct / $accounts] scanning $directory===\e[0m\c" >&2
            if [[ -d "$directory" ]]; then
                for scan in ${scans}; do
                    scanfunc=$(echo "$scan" | cut -d ";" -f1)
                    toutput="$($scanfunc $directory $scan)"
                    if [[ $toutput ]]; then
                        if [[ $output ]]; then
                            output="$output\n$toutput"
                        else
                            output=$toutput
                        fi
                    fi
                done
            fi
            echo -e "\r`printf "%$(tput cols)s"`\c" >&2
        done
        echo -e "\r\e[0;32m===Completed===\e[0m" >&2
        if [[ $output ]]; then
            echo -e "$output"
        fi
        exit
    fi
    if [[ -d "/var/cpanel" ]]; then
    #cPanel found, will scan per user -> domain -> sub directory
        if [[ ! $specificuser ]]; then
            cpanelusers=$(getcpanelusers)
        else
            cpanelusers=$specificuser
        fi
        output=""
        accounts=$(echo "$cpanelusers" | wc -w)
        curacct=0
        for user in $cpanelusers; do
            curacct=$(( $curacct + 1 ))
            echo -e "\r\e[0;32m===[$curacct / $accounts] Scanning $user===\e[0m\c" >&2
            homedir=$(getcpaneldir $user)
            if [[ -d "$homedir" ]]; then
                for scan in ${scans}; do
                    scanfunc=$(echo "$scan" | cut -d ";" -f1)
                    toutput="$($scanfunc $homedir $scan)"
                    if [[ $toutput ]]; then
                        if [[ $output ]]; then
                            output="$output\n$toutput"
                        else
                            output=$toutput
                        fi
                    fi
                done
            fi
            echo -e "\r`printf "%$(tput cols)s"`\c" >&2
        done
        echo -e "\r\e[0;32m===Completed===\e[0m" >&2
        if [[ $output ]]; then
            echo -e "$output"
        fi
    elif [[ -d "/usr/local/psa" ]]; then
        if [[ ! $specificuser ]]; then
            pleskdomains=$(getpleskdomains)
        else
            pleskdomains=$specificuser
        fi
        output=""
        accounts=$(echo "$pleskdomains" | wc -l)
        curacct=0
        for domain in $pleskdomains; do
            curacct=$(( $curacct + 1 ))
            echo -e "\r\e[0;32m===[$curacct / $accounts] Scanning $domain===\e[0m\c" >&2
            homedir="/var/www/vhosts/$domain"
            if [[ -d "$homedir" ]]; then
                for scan in ${scans}; do
                    scanfunc=$(echo "$scan" | cut -d ";" -f1)
                    toutput="$($scanfunc $homedir $scan)"
                    if [[ $toutput ]]; then
                        if [[ $output ]]; then
                            output="$output\n$toutput"
                        else
                            output=$toutput
                        fi
                    fi
                done
            fi
            echo -e "\r$(printf "%$(tput cols)s")\c" >&2
        done
        echo -e "\r\e[0;32m===Completed===\e[0m" >&2
        if [[ $output ]]; then
            echo -e "$output"
        fi
    else
        if [[ ! $specificuser ]]; then
            users=$(getcoredomains) #Does not work yet
        else
            users=$specificuser
        fi
        output=""
        accounts=$(echo "$users" | wc -l)
        curacct=0
        for user in $users; do
            curacct=$(( $curacct + 1 ))
            echo -e "\r\e[0;32m===[$curacct / $accounts] Scanning $user===\e[0m\c" >&2
            homedir=$(getcoredir $user)
            if [[ -d "$homedir" ]]; then
                for scan in ${scans}; do
                    scanfunc=$(echo "$scan" | cut -d ";" -f1)
                    toutput="$($scanfunc $homedir $scan)"
                    if [[ $toutput ]]; then
                        if [[ $output ]]; then
                            output="$output\n$toutput"
                        else
                            output=$toutput
                        fi
                    fi
                done
            fi
            echo -e "\r$(printf "%$(tput cols)s")\c" >&2
        done
        echo -e "\r\e[0;32m===Completed===\e[0m" >&2
        if [[ $output ]]; then
            echo -e "$output"
        fi
    fi
}

function printresult {
    #$1 scan string
    #$2 version found
    #$3 location
    program=$(echo "$1" | cut -d ';' -f2)
    minver=$(echo "$1" | cut -d ';' -f3)
    curver=$(echo "$1" | cut -d ';' -f4)
    insver="$2"
    
    # Compare version with current version
    vercomp $2 $curver
    vercompCur=$?
    
    # Compare version with minimal version
    vercomp $2 $minver
    vercompMin=$?

    # Get version status (0=OK, 1=WARNING, 2=CRITICAL)
    verstatus $2 $minver $curver
    status=$?

    if [[ ! $csvformat ]]; then
        #Add tabs based on program name size
        if [[ $(echo "$program" | wc -c) -lt 9 ]]; then
            program="$program\t\t"
        else
            program="$program\t"
        fi

        #Add tabs based on version name size
        if [[ $(echo "$insver" | wc -c) -lt 9 ]]; then
            insver="$insver\t\t"
        else
            insver="$insver\t"
        fi
        
        #Add tabs based on version name size
        if [[ $(echo "$curver" | wc -c) -lt 9 ]]; then
            curver="$curver\t\t"
        else
            curver="$curver\t"
        fi
    fi

    if [[ ! $csvformat ]]; then
        # break here if no version found
        if [[ ! $2 ]]; then
            echo -e "$program ===Signature match but no version returned === $3"
            return
        fi

        if [[ ! $reportonly ]]; then
            if [[ $vercompCur -eq 2 ]]; then
                if [ $vercompMin -eq 2 ]; then
                    echo -e "$program\e[0;31m$insver\e[0m$curver$3"
                else
                    echo -e "$program\e[0;33m$insver\e[0m$curver$3"
                fi
            else
                if [[ ! $showonlyold ]]; then
                    echo -e "$program\e[0;32m$insver\e[0m$curver$3"
                fi
            fi
        else
            if [[ $vercompCur -eq 2 ]]; then
                echo -e "$program$insver$curver$3"
            else
                if [[ ! $showonlyold ]]; then
                    echo -e "$program$insver$curver$3"
                fi
            fi
        fi
    else
        if [[ $vercompCur -eq 2 ]]; then
            echo "$program,$insver,$curver,$status,$3"
        else
            if [[ ! $showonlyold ]]; then
                echo "$program,$insver,$curver,$status,$3"
            fi
        fi
    fi
}

function printsigs {
    echo -e "Program Name\tWarn Ver\tCur Ver"
    for sig in ${scans}; do
        program=$(echo $sig | cut -d ";" -f2)
        minver=$(echo $sig | cut -d ";" -f3)
        curver=$(echo $sig | cut -d ";" -f4)
        if [[ $(echo "$program"| wc -c) -lt 9 ]]; then
            echo -e "$program\t\t$minver\t\t$curver"
        else
            echo -e "$program\t$minver\t\t$curver"
        fi
    done
    echo "";
    echo "Note: Version signatures ending in 999 are outdated and no longer offered on the web."
    echo "These are generally considered EOL packages since there will not be any security updates."
}

######################### Signatures

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

# Scan for Typo3 installs
# TODO: This should only be called once and used for all typo3_* functions
# Problem: All signature functions are called in a subshell
function typo3_scan {
    find $1 -type f -name 'config_default.php' -wholename '**/t3lib/config_default.php' -print0 | while read -d '' -r F; do
        D=`dirname "$F"`
        D=`dirname "$D"`
        VERSION=`grep -e '^\s*\$TYPO_VERSION' "$F" | sed -r "s/^.*=\s*'(.*)'.*$/\1/g"`
        echo "$D;$VERSION"
    done
}

function typo3_45 {
    t3Scans="$(typo3_scan $1)"
    for scan in ${t3Scans}; do
        loc=$(echo "$scan" | cut -d ";" -f1)
        insver=$(echo "$scan" | cut -d ";" -f2)
        if [[ $insver == 4.5.* ]]; then
            printresult $2 "$insver" "$loc"
        fi
    done
}

function typo3_47 {
    t3Scans="$(typo3_scan $1)"
    for scan in ${t3Scans}; do
        loc=$(echo "$scan" | cut -d ";" -f1)
        insver=$(echo "$scan" | cut -d ";" -f2)
        if [[ $insver == 4.7.* ]]; then
            printresult $2 "$insver" "$loc"
        fi
    done
}

function typo3_60 {
    t3Scans="$(typo3_scan $1)"
    for scan in ${t3Scans}; do
        loc=$(echo "$scan" | cut -d ";" -f1)
        insver=$(echo "$scan" | cut -d ";" -f2)
        if [[ $insver == 6.0.* ]]; then
            printresult $2 "$insver" "$loc"
        fi
    done
}

function typo3_61 {
    t3Scans="$(typo3_scan $1)"
    for scan in ${t3Scans}; do
        loc=$(echo "$scan" | cut -d ";" -f1)
        insver=$(echo "$scan" | cut -d ";" -f2)
        if [[ $insver == 6.1.* ]]; then
            printresult $2 "$insver" "$loc"
        fi
    done
}

function typo3_62 {
    t3Scans="$(typo3_scan $1)"
    for scan in ${t3Scans}; do
        loc=$(echo "$scan" | cut -d ";" -f1)
        insver=$(echo "$scan" | cut -d ";" -f2)
        if [[ $insver == 6.2.* ]]; then
            printresult $2 "$insver" "$loc"
        fi
    done
}

function joomla15 {
    idfiles=$(find  $1 -name joomla.php | xargs grep -l "Joomla.Legacy" | sed "s/includes\/joomla\.php//")
    for loc in ${idfiles}; do
        if [[ -e "$loc/CHANGELOG.php" ]]; then
            insver=$(grep "Stable Release" $loc/CHANGELOG.php | head -1 | awk '{print $2}')
            printresult $2 "$insver" "$loc"
        fi
    done
}

function joomla17 {
    idfiles=$(find  $1 -name web.config.txt | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ -e $loc/includes/version.php ]]; then
            insver=$(grep "RELEASE =" $loc/includes/version.php | cut -d "'" -f2)"."$(grep "DEV_LEVEL =" $loc/includes/version.php | cut -d "'" -f2)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function joomla25 {
    idfiles=$(find  $1 -name web.config.txt | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ ! -e $loc/includes/version.php ]]; then
            if [[ -e $loc/libraries/cms/version/version.php ]]; then
                if [[ $(grep "RELEASE =" $loc/libraries/cms/version/version.php | cut -d "'" -f2 | grep "^2") ]]; then
                    insver=$(grep "RELEASE =" $loc/libraries/cms/version/version.php | cut -d "'" -f2)"."$(grep "DEV_LEVEL =" $loc/libraries/cms/version/version.php | cut -d "'" -f2)
                    printresult $2 "$insver" "$loc"
                fi
            fi
        fi
    done
}

function joomla32 {
    idfiles=$(find  $1 -name web.config.txt | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ ! -e $loc/includes/version.php ]]; then
            if [[ -e $loc/libraries/cms/version/version.php ]]; then
                if [[ $(grep "RELEASE =" $loc/libraries/cms/version/version.php | cut -d "'" -f2 | grep "^3.2") ]]; then
                    insver=$(grep "RELEASE =" $loc/libraries/cms/version/version.php | cut -d "'" -f2)"."$(grep "DEV_LEVEL =" $loc/libraries/cms/version/version.php | cut -d "'" -f2)
                    printresult $2 "$insver" "$loc"
                fi
            fi
        fi
    done
}

function joomla33 {
    idfiles=$(find  $1 -name web.config.txt | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ ! -e $loc/includes/version.php ]]; then
            if [[ -e $loc/libraries/cms/version/version.php ]]; then
                if [[ $(grep "RELEASE =" $loc/libraries/cms/version/version.php | cut -d "'" -f2 | grep "^3.3") ]]; then
                    insver=$(grep "RELEASE =" $loc/libraries/cms/version/version.php | cut -d "'" -f2)"."$(grep "DEV_LEVEL =" $loc/libraries/cms/version/version.php | cut -d "'" -f2)
                    printresult $2 "$insver" "$loc"
                fi
            fi
        fi
    done
}

function joomla34 {
    idfiles=$(find  $1 -name web.config.txt | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ ! -e $loc/includes/version.php ]]; then
            if [[ -e $loc/libraries/cms/version/version.php ]]; then
                if [[ $(grep "RELEASE =" $loc/libraries/cms/version/version.php | cut -d "'" -f2 | grep "^3.4") ]]; then
                    insver=$(grep "RELEASE =" $loc/libraries/cms/version/version.php | cut -d "'" -f2)"."$(grep "DEV_LEVEL =" $loc/libraries/cms/version/version.php | cut -d "'" -f2)
                    printresult $2 "$insver" "$loc"
                fi
            fi
        fi
    done
}

function oscommerce2 {
    idfiles=$(find  $1 -name "filenames.php" | xargs grep -l "osCommerce, Open Source E-Commerce Solutions"  | sed 's/includes\/filenames\.php//')
    for loc in ${idfiles}; do
        if [[ -e $loc/includes/version.php ]]; then
            insver=$(cat $loc/includes/version.php | head -1)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function xoops {
    idfiles=$(find  $1 -name xoops.css | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ -e $loc/includes/version.php ]]; then
            insver=$(grep "XOOPS_VERSION" $loc/includes/version.php | head -1 | cut -d "'" -f4 | awk '{print $2}')
            printresult $2 "$insver" "$loc"
        fi
    done
}

function e107 {
    idfiles=$(find  $1 -name e107_config.php | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ -e $loc/admin/ver.php ]]; then
            insver=$(grep "e107_version" $loc/admin/ver.php | head -1 | cut -d '"' -f2)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function mambo {
    idfiles=$(find  $1 -name mambofunc.php | sed 's/includes\/mambofunc\.php//')
    for loc in ${idfiles}; do
        if [[ -e $loc/includes/version.php ]]; then
            insver=$(grep "RELEASE =" $loc/includes/version.php | cut -d "'" -f2)"."$(grep "DEV_LEVEL =" $loc/includes/version.php | cut -d "'" -f2)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function mediawiki {
    idfiles=$(find  $1 -name DefaultSettings.php | xargs grep -il "mediawiki" | sed "s/includes\/DefaultSettings\.php//")
    for loc in ${idfiles}; do
        if [[ -e $loc/includes/DefaultSettings.php ]]; then
            insver=$(grep "wgVersion" $loc/includes/DefaultSettings.php | cut -d "'" -f2)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function piwigo {
    idfiles=$(find  $1 -name identification.php | xargs grep -l "Piwigo" | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ -e $loc/include/constants.php ]]; then
            insver=$(grep "PHPWG_VERSION" $loc/include/constants.php | cut -d "'" -f4)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function phpbb3 {
    idfiles=$(find  $1 -name bbcode.php | xargs grep -l "phpBB3" | sed "s/includes\/bbcode\.php//")
    for loc in ${idfiles}; do
        if [[ -e $loc/includes/constants.php ]]; then
            insver=$(grep "PHPBB_VERSION" $loc/includes/constants.php | cut -d "'" -f4)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function openx {
    idfiles=$(find  $1 -name OX.php | xargs grep -l "OpenX" | sed "s/lib\/OX\.php//")
    for loc in ${idfiles}; do
        if [[ -e $loc/constants.php ]]; then
            insver=$(grep "OA_VERSION" $loc/constants.php | cut -d "'" -f4)
            if [[ ! $insver ]]; then
                insver=$(grep "VERSION" $loc/constants.php | cut -d "'" -f4)
            fi
            printresult $2 "$insver" "$loc"
        fi
    done
}

function redmine {
    idfiles=$(find $1 -name redmine.rb | xargs grep -l "redmine" | sed "s|lib/redmine.rb||")
    for loc in ${idfiles}; do
        if [[ -e $loc/doc/CHANGELOG ]]; then
            insver=$(grep "==" $loc/doc/CHANGELOG | head -2 | tail -1 | cut -d "v" -f2)
            majver=$(echo "$insver" | cut -d . -f1,2)
            scanmaj=$(echo "$2" | cut -d ';' -f3)
            if [ ! $majver \< $scanmaj ]; then
                printresult $2 "$insver" "$loc"
            fi
        fi
    done
}

function drupal7 {
    idfiles=$(find  $1 -name authorize.php | xargs grep -l "Drupal" | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ -e $loc/includes/bootstrap.inc ]]; then
            insver=$(grep "VERSION" $loc/includes/bootstrap.inc | cut -d "'" -f4|head -1)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function drupal6 {
    idfiles=$(find  $1 -name database.mysql.inc | xargs grep -l "Drupal" | sed "s/includes\/database\.mysql\.inc//")
    for loc in ${idfiles}; do
        if [[ -e $loc/CHANGELOG.txt ]]; then
            insver=$(grep "Drupal" $loc/CHANGELOG.txt | head -1 | awk '{print $2}' | cut -d "," -f1)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function magento {
    idfiles=$(find $1 -name Mage.php | xargs grep -l "* Magento" | sed "s/app\/Mage\.php//")
    for loc in ${idfiles}; do
        if [[ -e $loc/RELEASE_NOTES.txt ]]; then
            insver=$(grep "====" $loc/RELEASE_NOTES.txt | head -1 | awk '{print $2}')
            printresult $2 "$insver" "$loc"
        fi
    done
}

function zencart {
    idfiles=$(find  $1 -name "filenames.php" | xargs grep -l "Zen Cart Development Team"  | sed 's/includes\/filenames\.php//')
    for loc in ${idfiles}; do
        if [[ -e $loc/includes/version.php ]]; then
            insver=$(grep "PROJECT_VERSION_MAJOR" $loc/includes/version.php | cut -d "'" -f4)"."$(grep "PROJECT_VERSION_MINOR" $loc/includes/version.php | cut -d "'" -f4)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function xcart {
    idfiles=$(find  $1 -name "cart.php" | xargs grep -l "\| X-Cart"  | sed 's:[^/]*$::')
    for loc in ${idfiles}; do
        if [[ -e $loc/VERSION ]]; then
            insver=$(cat $loc/VERSION | awk '{print $2}' | head -1)
            printresult $2 "$insver" "$loc"
        elif [[ -e $loc/Includes/install/install_settings.php ]]; then
            insver=$(grep "LC_VERSION" $loc/Includes/install/install_settings.php | cut -d "'" -f4)
            printresult $2 "$insver" "$loc"
        elif [[ -e $loc/sql/xlite_data.yaml ]]; then
            insver=$(grep "name: version" $loc/sql/xlite_data.yaml | cut -d "'" -f2)
            printresult $2 "$insver" "$loc"
        fi
    done
}

function vbulletin4 {
    idfiles=$(find  $1 -name "diagnostic.php" | xargs grep -l "vbulletin"  | sed 's|/admincp/diagnostic.php||')
    for loc in ${idfiles}; do
        if [[ -e $loc/admincp/diagnostic.php ]]; then
            insver=$(grep "md5_sum_versions" $loc/admincp/diagnostic.php | head -n1 | cut -d "'" -f4)
            printresult $2 "$insver" "$loc"
        fi
    done
}
######### Pre Init

until [[ -z $1 ]]; do
    case "$1" in
        --outdated)
            showonlyold='1'
            shift
            ;;
        --user)
            specificuser=$2
            shift 2
            ;;
        --directory)
            specificdirectory=$2
            shift 2
            ;;
        --report)
            reportonly='1'
            shift
            ;;
        --csv)
            csvformat='1'
            shift
            ;;
        --sigs)
            printsigs
            exit 1
            ;;
        --help)
            echo "Usage: $0 [OPTION] [--user username]"
            echo "Scan server for known CMS versions and report what is found"
            echo ""
            echo "OPTIONS:"
            echo " --outdated"
            echo "    Returns only outdated packages, does not print headings"
            echo " --report"
            echo "    Removes coloring format for easy export to file using > filename"
            echo " --csv"
            echo "    Prints output in CSV format."
            echo " --user <username>"
            echo "    Scans only user's account, use quotes for a providing a list of users"
            echo " --directory <directory>"
            echo "    Scans only a specific directory, used quotes for providing a list of directories"
            echo " --sigs"
            echo "    Print current list of program versions"
            exit 1
            ;;
        *)
            echo "Unknown option $1" >&2
            shift
            ;;
    esac
done
init
#</directory></username>
