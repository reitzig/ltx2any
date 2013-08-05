ltx2any
=======

Yet another LaTeX build wrapper, with one or two nifty features:

 * Automatically compiles as often as necessary.
 * Executes additional programs as necessary and aggregates their output into
   a single log file.
 * Does not require user intervention or annotations to do either of the above.
 * Work-intensive extensions (e.g. TikZ externalization) work in parallel to
   speedup compilation on multi-core machines.
 * Can run as daemon, listening for file changes which prompt recompilation.
 * Adding additional phases is easy due to modular design.
 * Keeps your main directory clean by default.
 
It is easy to extend ltx2any with additional LaTeX engines and secondary tools.
We currently have support for the following implemented:

 * Engines `pdflatex`, `xelatex` and `lualatex` for PDF targets.
 * Engine `pandoc` which supports many target formats, including EPUB and ODT.
 * Extensions for `bibtex`, `makeindex`, TikZ externalization and `gnuplot`.
 
Pull requests with new engines or extensions are appreciated. Please make sure
to adhere to the specs (upcoming) and include test cases.

**Note:** This is still *prerelease* code. It is by no means considered nicely written, 
bug-free or reliable. Take care!

### Requirements ###

 * Ruby 1.9.x or higher
 * Ruby gem [listen](https://github.com/guard/listen) for daemon mode.
 * LaTeX engines and secondary tools as needed.

### Basic Use ###

Once `ltx2any` is in your PATH, run `ltx2any <file>`. Find out about available parameters by running `ltx2any --help`.

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
[ltx2any] Took 0 min  0 sec
[ltx2any] Log file generated at plain_bibtex.log
```

Note that ltx2any figured out the necessary number of runs and external programs: 
because of some references, three runs of `pdflatex` are needed (and we 
need a fourth to realise that the PDF has converged) and `bibtex` was
used to resolve literature references.
Rerun the command and see how this automatism speeds up subsequent runs!

Using another engine is as easy as typing e.g. `ltx2any -e lualatex <file>`. The
current default is `pdflatex` though that is easily changed.

### To Do ###
 
 * Make target options accessible for targets
 * De-spaghettify code (mainly `ltx2any.rb`)
 * Refactor and/or document functions, constants, ...
 * Check out tex daemon(s) to speed up compilation
 * Add support for preamble precompilation.
 * How-To for writing extensions (and targets).
 * Start scripts for other OS
