# What is this fork?

This is a fork of mattfosters Gnuplot TextMate Bundle (and I am Tobias Heß). I really love Gnuplot for my Latex files, but with the old bundle it was sometimes hard to get the right layout down because the output is shown in aqua-term and not in the choosen terminal. When i'm working on a gnuplot script i like to see the output as the terminal declares. So in this fork the gnuplot script will be executed and the outputs will be shown depending on the terminal in preview or skim.

Too install it and execute following in the console:

	$ cd ~/Library/Application Support/TextMate/Bundles
	$ git clone git@github.com:hesstobi/gnuplot.tmbundle.git


## Features form the mattfosters Gnuplot TextMate Bundle

Aims to provide a useful set of commands, snippets and language support for
writing and running gnuplot scripts within [TextMate](http://macromates.com/).

So far, various features have been implemented, including:

  * Syntax highlighting.
  * Toggling (un)set -- pressing '⇧⌘S' changes toggles between `set` and `unset` keywords on the current line.
  * Online help -- pressing '⌃H' with the caret over a keyword pops up an HTML window containing gnuplot's built-in help for that keyword.


## What is new

The way like the outputs are display changed completely. The bundle decided how the output is displayed according to the used terminal in the gunplot script. So for running script and displaying the output only following commands are necessary:

* Script execution -- pressing '⇧⌘R' pipes the script through gnuplot.
* Output viewing -- pressing '⇧⌘O' displays the output depending on the terminal in preview or skim.   
Following terminals are supported:
	* aquaterm
	* epslatex and lua tikz  
	Every output gets complied by latex and display in a single pdf document in skim.
	* pdf and png  
	All outputs will be displayed in preview
* Script execution and Output viewing -- pressing ''⌘R' pipes the script through gnuplot and display the output depending on the terminal in preview or skim.   


### More information to the epslatex and lua tikz handling

In default the epslatex and lua tikz outputs are compiled by latex only with the necessary packages for the terminals. For epslatex it is:

* graphicx
* xcolor

and for lua tikz it is:

* gnuplot-lua-tikz

If you like to add more packages you have tow options

1. Add the packages with latex code to the file 'BUNDLEPATH/Support/texHeader.tex'
2. Define it directly in the gnuplot script with #!TEXHEADER=\usepackage{example}











