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
 * Ruby gem [listen](https://github.com/guard/listen)

### Basic Use ###

Once `ltx2any` is in your PATH, run `ltx2any <file>.tex`. Find out about available parameters by running `ltx2any --help`.

A typical run may look like this:

```
$> ltx2any plain_bibtex
[ltx2any] Initialising ...
[ltx2any] pdflatex(1) running ... Done
[ltx2any] bibtex running ... Done
[ltx2any] pdflatex(2) running ... Done
[ltx2any] pdflatex(3) running ... Done
[ltx2any] pdflatex(4) running ... Done
[ltx2any] Output generated at plain_bibtex.pdf
[ltx2any] Log file generated at plain_bibtex.log
[ltx2any] Took 0 min  5 sec
```

Note that ltx2any figured out the necessary number of runs and external programs 
out: because of some references, three runs of `pdflatex` are needed (and we 
need a fourth to realise that the PDF has converged). Rerun the command and see 
how this automatism speeds up subsequent runs!

### To Do ###
 
 * Make target options accessible for targets
 * De-spaghettify code (mainly `ltx2any.rb`)
 * Refactor and/or document functions, constants, ...
 * Files reachable via symlink that are newly created during run with `-d` 
   should also be listened to.
 * `bibtex` extension should not run if unnecessary
 * Is number of target runs a target-specific feature?
 * Add extension for spell-/grammar-/stylechecker (see e.g. [here](http://dsl.org/cookbook/cookbook_15.html)) 
   default: no spellcheck. Options: log findings to file; interactive
 * Integrate lacheck or similar
 * Check out tex daemon(s) to speed up compilation
 * Add preamble precompilation
 * Check and forward warnings and errors from extensions
 * Check log(s) for errors and warnings and report summary/counts
 * How-To for writing extensions (and targets)
 * Make TikZ externalization extension cleaner (e.g. remove unnecessary files, 
   report errors, ignore todonotes if possible (?))
 * Start scripts for other OS
