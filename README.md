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
 * Aggregates error messages and warnings from all tools into a nicely formatted 
   log (Markdown or PDF) with references to the original logs.
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
 * [pandoc](https://github.com/jgm/pandoc) for PDF logs and target formats other than PDF.
 * LaTeX engines and secondary tools as needed.

### Basic Use ###

Once `ltx2any` is in your PATH, run `ltx2any <file>`. Find out about available parameters by running `ltx2any --help`.

A typical run may look like this:

```
$> ltx2any bibtex_test.tex 
[ltx2any] Initialising ...
[ltx2any] pdflatex(1) running ... Done
[ltx2any] bibtex running ... Error
[ltx2any] pdflatex(2) running ... Done
[ltx2any] There were 1 error and 3 warnings.
[ltx2any] Output generated at bibtex_test.pdf
[ltx2any] Assembling log files ... done
[ltx2any] Log file generated at bibtex_test.log.md
```

This is what the PDF log looks like (add option `-lf pdf`):

![Example PDF log](https://f.cloud.github.com/assets/1488534/937836/3e58c1e4-00ec-11e3-961c-9166c9c8d3c2.png)

Note that ltx2any figured out the necessary number of runs and external programs: 
because of some references, three runs of `pdflatex` are needed (and we 
need a fourth to realise that the PDF has converged) and `bibtex` was
used to resolve literature references.
Rerun the command and see how this automatism speeds up subsequent runs!

Using another engine is as easy as typing e.g. `ltx2any -e lualatex <file>`. The
current default is `pdflatex` though that is easily changed.

### TikZ externalization ###

Here is what you need to do in order get externalization running.

 * Read section IV.32 in [the pgfmanual](http://mirrors.ctan.org/graphics/pgf/base/doc/generic/pgf/pgfmanual.pdf).
 * Make sure you use the `list and make` mode, that is your file specifies:
 
        \tikzset{external/mode=list and make}
        
 * There are two ways to make ltx2any rebuild images:

     1. Specify the `-ir` option to rebuild *all* externalised images.
     
     2. Delete the corresponding PDF from the temp directory to have specific
      images rebuilt
      
   There is currently no support from TikZ for detecting when images have to be
   rebuilt due to changes. We may add a way to invalidate specific images between
   runs in daemon mode.
     
 * *Hint:* You may want to turn off externalization while you work on an image 
    like this:
    
         \tikzset{external/export next=false}
         \begin{tikzpicture}
           ...
         
 * *Hint:* Externalization adds quite some overhead and is probably not useful
    for small images. In particular, packages that use TikZ for small stuff
    such as [todonotes](http://ctan.org/pkg/todonotes) can slow down compilation
    considerably.
    
    Therefore, you may want to enable externalization only for specific images
    (recommended, see above) or redefine troublesome commands, e.g. like this:
    
        \usepackage{letltxmacro}
        \LetLtxMacro{\oldtodo}{\todo}
        \renewcommand{\todo}[2][]{%
          \tikzset{external/export next=false}\oldtodo[#1]{#2}%
        }

### To Do ###
 
 * Make target options accessible for targets
 * De-spaghettify code (mainly `ltx2any.rb`)
 * Refactor and/or document functions, constants, ...
 * Check out tex daemon(s) to speed up compilation
 * Add support for preamble precompilation.
 * How-To for writing extensions (and targets).
 * Start scripts for other OS
