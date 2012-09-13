# Introduction

This Gnuplot bundle is a set of commands and snippets designed to help you use [Gnuplot](http://www.gnuplot.info/), an incredibly powerful plotting utility. It is based on [mattfosters](https://github.com/mattfoster/gnuplot-tmbundle) Bundle and adds some powerful extensions.


# Installation

Too install bundle type and execute following in the console:

	$ cd ~/Library/Application Support/Avian/Bundles
	$ git clone git@github.com:hesstobi/gnuplot.tmbundle.git
	
	
# Usage

## Commands
	
The generate and view the output of your gnuplot file you can use following commands:

* Script execution -- pressing '⇧⌘R' pipes the script through gnuplot.
* Output viewing -- pressing '⇧⌘O' displays the output depending on the terminal in preview or skim.   
Following terminals are supported:
	* aquaterm
	* epslatex, lua tikz, cairolatex  
	Every output gets complied by latex and is displayed in a single pdf document in Skim.app
	* pdf, png, pdfcario, pngcairo  
	All outputs will be displayed in Preview.app
* Script execution and Output viewing -- pressing ''⌘R' pipes the script through gnuplot and display the output depending on the terminal in Preview or Skim.

Some more usefull commands are:

* Toggling (un)set -- pressing `⇧⌘S` changes toggles between `set` and `unset` keywords on the current line.
* Online help -- pressing `⌃H` with the caret over a keyword pops up an HTML window containing gnuplot's built-in help for that keyword. -- currently not working

## Snippets

The bundle defines also some useful snippets frequently used commands and various papers sizes


## Completion

Currently only the TextMate build in completion is working...here is some work to do.

## Testing

To quickly test if the gnuplot is correctly installed, you can use the 'test' snippet. Just type `test⇥`, to get some test code. Then run it with `⌘R`. 


# Notes

For best/any results, you'll need TextMate to be able to see a `gnuplot` binary. 

To find out if it can, type: `which gnuplot` into an empty file, and press ⌃R. You should see something like the following:

	which gnuplot
	/usr/local/bin/gnuplot

If you don't, then make sure you have gnuplot installed. Typical installation commands are:
	
* brew install gnuplot
* port install gnuplot
 
The bundle will automatically use as path the result of the command `which gnuplot` but you can also specify the gnuplot path by setting the `TM_GNUPLOT` variable in your `.tm_properties` file.

To view the output of  latex or pdf terminals you also need a [Latex](htto://www.tug.org/mactex) installation and the pdf view [Skim](http://skim-app.sourceforge.net)


## More information to the epslatex, cairolatex and lua tikz handling

In default the epslatex and lua tikz outputs are compiled by latex only with the necessary packages for the terminals. For epslatex and cairolatex it is:

* graphicx
* xcolor

and for lua tikz it is:

* gnuplot-lua-tikz

If you like to add more packages you have tow options

1. Add the packages with latex code to the file `TM_BUNDLEPATH/Support/texHeader.tex`
2. Define it directly in the gnuplot script with `#!TEXHEADER: usepackage{example}` 

The gnuplot outputs are than add to one latex-document and compiled. The name of the resulting pdf-document is 'Plot_[filename].pdf'. Where [filename] is the filename of the executed gnuplot script.

In the case of the epslatex terminal and if the gnuplot script is located in a TextMate project the path of the included pdf-document in the output tex-file is changed to the realtive path to the project tree, which is really help full if you using gnuplot in an large latex project with several subfolders. So you can avoid the use of \graphicspath or similar workarounds.

# Contribution

Any help and improvements on this bundle is welcome. Simple contact me or send me a pull request. Here is my TODO list:

* Fixing completion
* Fixing Gnuplot help
* Better error handling in commands
* Add fast tool-tip help
* Add better syntax highlighting
* Add syntax highlighting for included latex text


# Acknowledgment

* [Matt Foster](https://github.com/mattfoster)









