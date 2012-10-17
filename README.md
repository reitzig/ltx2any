ltx2any
=======

Yet another LaTeX build wrapper, with one or two nifty features:

 * Automatically compiles as often as necessary.
 * Executes additional programs as necessary and aggregates their output.
 * Does not require user intervention or annotations to do either of the above.
 * Can run as daemon, listening for file changes.
 * Adding additional phases is easy due to modular design.
 * Keeps your main directory clean by default.
 * Support for `bibtex`, `makeindex`, TikZ externalization and `gnuplot`.
 * Compiles into PDF.

This is still *prerelease* code. It is by no means considered nicely written, 
bug-free or reliable. Unexpected errors may even crash the whole script. Take care!

### Requirements ###

 * Ruby 1.8.7 or higher
 * Ruby gem [listen](https://github.com/guard/listen).

### Basic Use ###

Once `ltx2any` is in your PATH, run `ltx2any <file>.tex`. Find out about available parameters by running `ltx2any --help`.

### To Do ###
 
 * Make target options accessible for targets
 * De-spaghettify code (mainly `ltx2any.rb`)
 * Refactor and/or document functions, constants, ...
 * Is number of target runs a target-specific feature?
 * Offer cleanall which also removes log and result
 * Add extension for spell-/grammar-/stylechecker (see e.g. [here](http://dsl.org/cookbook/cookbook_15.html)  
   default: no spellcheck. Options: log findings to file; interactive
 * Integrate lacheck or similar
 * Check out tex daemon(s) to speed up compilation
 * Add preamble precompilation
 * When waiting for changes, allow [options] + ENTER to trigger rebuilding
   with those options (forget afterwards)
 * Check and forward warnings and errors from extensions
 * How-To for writing extensions (and targets)
 * Start scripts for other OS
