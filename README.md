ltx2any
=======

Yet another LaTeX build wrapper, with one or two nifty features:

 * Automatically compiles as often as necessary.
 * Executes additional programs as necessary and aggregates their output into
   a single log file.
 * Does not require user intervention or annotations to do either of the above.
 * Work-intensive extensions (e.g. TikZ externalization) can work in parallel to
   speed up compilation on multi-core machines.
 * Can run as daemon, recompiling when files change.
 * Aggregates error messages and warnings from all tools into a nicely formatted 
   log (Markdown or [PDF](https://cloud.githubusercontent.com/assets/1488534/11242606/06ed381a-8e03-11e5-99be-7b1312d59420.png)) 
   with references to source files and original logs.
 * Adding additional phases is easy due to modular design.
 * Keeps your main directory clean by default.
 
It is easy to extend ltx2any with additional LaTeX engines and secondary tools.
Currently, we provide the following functionality:

 * Engines `pdflatex` (default), `xelatex` and `lualatex` for creating PDFs.
 * Extensions for `bibtex`, `biber`, `makeindex`, SyncTex support, TikZ externalization, `gnuplot` and Metapost.
 
Pull requests with new engines or extensions are appreciated. Please make sure
to adhere to the specs (upcoming) and include test cases.

**Note:** This is still *prerelease* code. It is by no means considered nicely written, 
bug-free or reliable. Take care!

### Requirements ###

For using ltx2any without any bells and whistles, you should have

 * Ruby 2.0.0 or higher and
 * LaTeX and friends.

Any of the major (La)TeX distributions should provide the binaries you need.

You can print a complete list of useful but optional gems and binaries by calling 
ltx2any with the `--dependencies` option; some provide improved speed or usability, 
others are necessary for only some engines or extensions.

#### Hints for Windows ####

 * Install Ruby by using the [RubyInstaller](http://rubyinstaller.org/).
   Ruby 2.2.4 (x64) and Ruby 2.3.0 (x64) work.
 * Install [gnuplot](http://www.gnuplot.info/).
   [gp503-win32-mingw.exe](https://sourceforge.net/projects/gnuplot/files/gnuplot/5.0.3/gp503-win32-mingw.exe/download) works.
   During installation, at "Select Additional Tasks", put a checkmark at "Add application directory to your PATH environment variable" (scroll down at the window).
 * [pandoc] works if its available in your PATH environment.
 * Having ruby and gnuplot installed, you can run ltx2any by invoking `ruby <path-to-clone-of-ltx2any>\ltx2any.rb <file>`.

### Basic Use ###

Once `ltx2any` is in your PATH, run `ltx2any <file>` to compile the specified file.
Find out about available parameters by running `ltx2any --help`.

A typical run may look like this:

```
$> ltx2any bibtex_test.tex 
[ltx2any] Initialising ... Done
[ltx2any] Copying files to tmp ... Done
[ltx2any] PdfLaTeX(1) running ... Done
[ltx2any] BibTeX running ... Error
[ltx2any] PdfLaTeX(2) running ... Done
[ltx2any] PdfLaTeX(3) running ... Done
[ltx2any] PdfLaTeX(4) running ... Done
[ltx2any] There were 1 error and 3 warnings.
[ltx2any] Output generated at bibtex_test.pdf
[ltx2any] Assembling log files ... Done
[ltx2any] Log file generated at bibtex_test.log.md
```

Note that ltx2any figured out the necessary number of runs and external programs: 
because of some references, three runs of `pdflatex` are needed (and we 
need a fourth to realise that the PDF has converged) and `bibtex` was
used to resolve literature references.
Rerun the command and see how this automatism speeds up subsequent runs!

Using another engine is as easy as typing e.g. `ltx2any -e lualatex <file>`. The
current default is `pdflatex` though that is easily changed. See a full list of
supported engines by passing the `--engines` option.

By the way, this is what a PDF log looks like (add option `-lf pdf`; requires
[pandoc]):

![Example PDF log](https://cloud.githubusercontent.com/assets/1488534/11242606/06ed381a-8e03-11e5-99be-7b1312d59420.png)


Note how you get clickable links to the referenced files. 
You can also navigate from error to error using the error count at the top
and the small arrows.


## Extensions ##

Extensions are what make ltx2any special: when written properly, they detect what has to be
done after the first run of, say, `pdflatex` and execute the necessary steps without any
need for user intervention.
Most do their work just by being there, with some exceptions. Run ltx2any with the
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
        
 * There are two ways to make ltx2any rebuild images:
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

### Parallel Compilation ###

Alas, LaTeX engines themselves can not run in parallel. But some extensions can, namely
such that create many small, independent jobs (e.g. TikZ externalization).
You only have to install Ruby gem [parallel](https://github.com/grosser/parallel/) for
making the best out of your multicore CPU.

### Daemon Mode ###

Install Ruby gem [listen](https://github.com/guard/listen) to make daemon mode available.
Option `-d` then causes `ltx2any` to wait for files in the working directory to change;
if that happens, the compilation process starts over.

By default, `ltx2any` will ignore changes to files it creates itself (even across instances).
Everything else in the current tree *is* listened to, though -- with some restrictions
around symlinks -- so take care if there is lots of stuff.  
As a general rule, `ltx2any` works best if the document you want to compile resides in
its own directory; use symlinks for shared resources.

While `ltx2any` waits for files to change, you can hit ENTER to get an interactive prompt;
hit ENTER again (with empty command) to close the prompt and recompile.  
Command `help` will tell you what you can do in the prompt; right now the most relevant use is
probably to force recompilation.
This feature is still subject to development and far from finished.

## For Developers

TODO: describe Extension and Engine interfaces -- once they have stabilized and 
are less likely to hurt people.

  [pandoc]: http://pandoc.org
