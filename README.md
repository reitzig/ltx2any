# chew

[![Gem Version](https://badge.fury.io/rb/chew.svg)](https://badge.fury.io/rb/chew) 
[![Circle CI](https://circleci.com/gh/reitzig/chew.svg?style=svg)](https://circleci.com/gh/reitzig/workflows/chew/tree/master) **˙**
[![Test Coverage](https://api.codeclimate.com/v1/badges/???/test_coverage)](https://codeclimate.com/github/reitzig/chew/test_coverage)
[![Maintainability](https://api.codeclimate.com/v1/badges/???/maintainability)](https://codeclimate.com/github/reitzig/chew/maintainability) 

Yet another LaTeX build tool, with a couple of nifty features:

 * Automatically compiles as often as necessary.
 * Executes additional programs as necessary and aggregates their output into
   a single log file.
 * Does not require user intervention or annotations to do either of the above.
 * Keeps your work directory clean by default.
 * Work-intensive tasks (e.g. TikZ externalization) run in parallel.
 * Recompiles automatically when files change.
 * Aggregates error messages and warnings from all tools into a nicely formatted 
   log (Markdown or [PDF](https://cloud.githubusercontent.com/assets/1488534/11242606/06ed381a-8e03-11e5-99be-7b1312d59420.png)) 
   with references to source files and original logs.
 
chew is designed to be easily extensible with support additional LaTeX engines 
and secondary tools.
Currently, the following is included:

 * Engines `pdflatex` (default), `xelatex` and `lualatex` for creating PDFs.
 * Extensions for `bibtex`, `biber`, `gnuplot`, `makeindex`, Metapost, SageTeX,
   SyncTex, and TikZ externalization.
 
Pull requests with new engines or extensions are appreciated. 
Find out
    [here](https://github.com/reitzig/chew/wiki/Contributing)
how to contribute.


## Requirements ###

For using chew without any bells and whistles, you should have

 * Ruby 2.3.0 or higher and
 * LaTeX and friends.

Any of the major (La)TeX distributions should provide the binaries you need;
we recommend [TeX Live](http://tug.org/texlive/).

Obviously, some extensions require additional binaries.
<!-- TODO: refer to CLI option and/or error message -->


## Installation

Install chew by executing:

    gem install chew 

See [here](https://github.com/reitzig/chew/wiki#installation) for some tips.


## Basic Use ###

Once `chew` is in your PATH, run `chew <file>` to compile the specified file.
Find out about available parameters by running `chew --help`.

A typical run may look like this:

```
$> chew bibtex_test.tex 
[chew] Initialising ... Done
[chew] Copying files to tmp ... Done
[chew] PdfLaTeX(1) running ... Done
[chew] BibTeX running ... Error
[chew] PdfLaTeX(2) running ... Done
[chew] PdfLaTeX(3) running ... Done
[chew] PdfLaTeX(4) running ... Done
[chew] There were 1 error and 3 warnings.
[chew] Output generated at bibtex_test.pdf
[chew] Assembling log files ... Done
[chew] Log file generated at bibtex_test.log.md
```

Note that chew figured out the necessary number of runs and external programs: 
because of some references, three runs of `pdflatex` are needed (and we 
need a fourth to realise that the PDF has converged) and `bibtex` was
used to resolve literature references.
Rerun the command and see how this automatism speeds up subsequent runs!

Using another engine is as easy as typing e.g. `chew -e lualatex <file>`. The
current default is `pdflatex` though that is easily changed. See a full list of
supported engines by passing the `--engines` option.

By the way, this is what a PDF log looks like (add option `-lf pdf`; requires
[pandoc](https://github.com/jgm/pandoc)):

![Example PDF log](https://cloud.githubusercontent.com/assets/1488534/11242606/06ed381a-8e03-11e5-99be-7b1312d59420.png)


Note how you get clickable links to the referenced files. 
You can also navigate from error to error using the error count at the top
and the small arrows.


## Extensions ##

Extensions are what make chew special: when written properly, they detect what has to be
done after the first run of, say, `pdflatex` and execute the necessary steps without any
need for user intervention.
Most do their work just by being there, with some exceptions. Run chew with the
`--extensions` option for a full list.

### TikZ Externalization ###

TikZ can externalize images so that they do not have to be rebuilt every run; 
this can save quite some compilation time. We support TikZ externalisation as 
long as LaTeX engines are used. Here is what you need to do in order get it running.

 * Read section V.50 in [the pgfmanual](http://mirrors.ctan.org/graphics/pgf/base/doc/generic/pgf/pgfmanual.pdf).
 * Make sure you use the `list and make` mode, that is your file specifies:
   
   ```latex
   \tikzset{external/mode=list and make}
   ```
        
 * There are two ways to make chew rebuild images:
    1. Specify `-ir all` option to rebuild *all* externalised images.
    2. Specify `-ir img1:img2:...:imgN` to rebuild only images `img1` through `imgN`.
    3. Delete the corresponding PDFs from the temp directory to have specific
      images rebuilt.
      
   There is currently no support for the new support in TikZ for detecting when 
   images have to be rebuilt due to changes (cf #47). 
   You can, however, change the set of rebuild images in daemon mode (see below).
     
 * *Hint:* You may want to turn off externalization while you work on an image 
    like this:
    
    ```latex
    \tikzset{external/export next=false}
    \begin{tikzpicture}
      ...
    ```
         
 * *Hint:* Externalization adds quite some overhead and is probably not useful
    for small images. In particular, packages that use TikZ for small stuff
    such as [todonotes](http://ctan.org/pkg/todonotes) can slow down compilation
    considerably.
    
    Therefore, you may want to enable externalization only for specific, 
    complex images (recommended) or redefine troublesome commands, 
    e.g. like this:

    ```latex
    \usepackage{letltxmacro}
    \LetLtxMacro{\oldtodo}{\todo}
    \renewcommand{\todo}[2][]{%
      \tikzset{external/export next=false}\oldtodo[#1]{#2}%
    }
    ```
    
### SyncTeX

Add the `-synctex` parameter; 
after successful compilation, a gzipped `.synctex` file should appear in your main directory, 
ready for other tools to use. 

No additional `-ep` parameter is necessary.


## Advanced Use ##

### Daemon Mode ###

If option `-d` is given, `chew` waits for files in the working directory to change;
if that happens, the compilation process starts over.

<!-- TODO change with issue #115 -->
By default, `chew` will ignore changes to files it creates itself (even across instances).
Everything else in the current tree *is* listened to, though -- with some restrictions
around symlinks -- so take care if there is lots of stuff.  
As a general rule, `chew` works best if the document you want to compile resides in
its own directory; use symlinks for shared resources.

<!-- TODO change with issue #97 -->
While `chew` waits for files to change, you can hit ENTER to get an interactive prompt;
hit ENTER again (with empty command) to close the prompt and recompile.  
Command `help` will tell you what you can do in the prompt; right now the most relevant use is
probably to force recompilation.
This feature is still subject to development and far from finished.
