# stocksoup
A mishmashed collection of various SourceMod stock functions that I've written for use in my projects.
Might be useful to you at some point as well.

## Usage (simplified)
For your sanity's sake, just copy the stocks that you need into your own project.
This repository is a moving target that gets changed fairly often; if you just sync this repository to your main scripting includes, you ~~may~~ will have a bad time if any stock functions change.

## Usage (traditional)
Install stocksoup as a git submodule.  The directory structure is set up this way with includes at the root so the repository has its own nice little folder to sit in.

Using this as a submodule means effectively pinning the dependencies; you and possible contributors won't be tripped up by function and include renames whenever I feel like doing them.
Of course, you'll have to be on a git-compatible system for your repository in the first place.

1.  Add the repository as a submodule (as an include relative to your `scripting` directory).

        $ git submodule add https://github.com/nosoop/stocksoup scripting/include/stocksoup
        
    If you're using Github for Windows (like I am), you'll probably have to perform the commit via Git Bash, too.  Commits on top of the submodule addition can proceed as normal.

2.  If not already, make sure your SourcePawn compiler looks into the custom include directory.

        spcomp "scripting/in_progress_file.sp" -i"scripting/include"

3.  Include a specific file and use a stock.

        #include <stocksoup/client>
        
        public void Example_OnPlayerSpawn(int client) {
                SetClientScreenOverlay(client, "combine_binocoverlay");
        }

4.  For collaboration, you should know how to recursively initialize a repository:

        $ git clone --recurse-submodules $YOUR_GIT_REPOSITORY

## Updates (as a submodule)
1.  Pull in updates for all the submodules.

        $ git submodule update --remote --merge

2.  Make sure your project actually builds; fix things as necessary.  No stability guaranteed.

3.  Commit as usual.

## Directory structure
Pretty simple:

*   Base directory has stocks applicable to all games.
    *   The `sdkports/` directory contains ports of select Source SDK functions.
*   Other subdirectories have stocks applicable to a specific mod.  Mainly TF2, since that's the only game I write for.  Any stock functions for a specific game should be prefixed with a game abbreviation, similar to SourceMod functions.

## Questions and Answers

**Is the name of the library a reference to Weird Al's [*Talk Soup*][yt-talksoup]?**
Yes.  Yes it is.

[yt-talksoup]: https://youtu.be/555ndsDM2qo
