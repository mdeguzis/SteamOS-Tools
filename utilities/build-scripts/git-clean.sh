#!/bin/bash

#www.libregeek.org
#Author: Michael DeGuzis
#Desciption: clean the git repo of uneeded huge commits in .git

#additional Credit goes to:
#http://stevelorek.com/how-to-shrink-a-git-repository.html
#Author: Steve Lorek
#Desciption: Ruby and Rails Developer from Southampton, UK—Senior Developer at LoveThis.

#Cleaning the file will take a while, depending on
#how busy your repository has been. You just need
# one command to begin the process:

##################################
#Start Orig. Script
##################################

#find sizes
#set -x 

#change directory
cd $HOME/github_repos/SteamOS-Tools

# Shows you the largest objects in your repo's pack file.
# Written for osx.
#
# @see http://stubbisms.wordpress.com/2009/07/10/git-script-to-show-largest-pack-objects-and-trim-your-waist-line/
# @author Antony Stubbs

# set the internal field spereator to line break, so that we can iterate easily over the verify-pack output
IFS=$'\n';

# list all objects including their size, sort by size, take top 10
objects=`git verify-pack -v .git/objects/pack/pack-*.idx | grep -v chain | sort -k3nr | head`

echo "All sizes are in kB's. The pack column is the size of the object, compressed, inside the pack file."

output="size,pack,SHA,location"
for y in $objects
do
        # extract the size in bytes
        size=$((`echo $y | cut -f 5 -d ' '`/1024))
        # extract the compressed size in bytes
        compressedSize=$((`echo $y | cut -f 6 -d ' '`/1024))
        # extract the SHA
        sha=`echo $y | cut -f 1 -d ' '`
        # find the objects location in the repository tree
        other=`git rev-list --all --objects | grep $sha`
        #lineBreak=`echo -e "\n"`
        output="${output}\n${size},${compressedSize},${other}"
done

echo -e $output | column -t -s ', '
echo ""
##################################
#EOF Orig. Script
##################################

#################################
#Start prune/removal code
#################################

#Much of this credit goes to:
#
#Manuel van Rijn, http://manuel.manuelles.nl/
#Steve Lorek, http://stevelorek.com/

#RUN OR CANCEL
echo -e "Run removal? y/n \c"
read run
   if [ $run = "n" ]; then
	echo "exiting!"
	exit
   fi

#read folder to prune/remove
echo -e "Folder(s) to remove? Seperate multiples by a space: \c"
read folder

git filter-branch --tag-name-filter cat --index-filter "git rm -r --cached --ignore-unmatch $folder" --prune-empty -f -- --all


#This command is adapted from other sources—the
#principle addition is --tag-name-filter cat which ensures tags are rewritten as well.

#After this command has finished executing,
#your repository should now be cleaned, with all branches and tags in tact.

#Reclaim space

#While we may have rewritten the history of the repository,
#those files still exist in there, stealing disk space and generally making a nuisance of themselves. Let's nuke the bastards:

rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --aggressive --prune=now

#Now we have a fresh, clean repository. In my case,
#it went from 180MB to 7MB.

#Push the cleaned repository

#Now we need to push the changes back to the remote
#repository, so that nobody else will suffer the pain of a 180MB download.

git push origin --force --all
git push origin --force --tags

#################################
#End prune/removal code
#################################
