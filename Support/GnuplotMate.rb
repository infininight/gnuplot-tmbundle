class GnuplotMate
  
  # Properties 
  
  attr_accessor :script, :outputFiles, :outputFilesLines
  
  def path
    possible_paths = [ENV["TM_GNUPLOT"], `which gnuplot`, "/opt/local/bin/gnuplot", "/sw/bin/gnuplot", "/usr/local/bin/gnuplot"]
    possible_paths.select { |x| x && File.exist?(x) }.first
  end
    
  # Konstruktor
  
  def initialize(script)
    @script = script
  end
  
  
  # Class Methods
  
  def self.run
    # Execute the script with Gnuplot
    g = GnuplotMate.new(STDIN.read)
    g.execute
  end
  
  def self.run_and_display
    # Execute the script with Gnuplot and display the output according to the current terminal
    script=STDIN.read
    g = GnuplotMate.new(script)
    g.execute
    g.displayOutput
  end
  
  
  def self.display
    # Display the output according to the current terminal if the output is allready produced
    script=STDIN.read
    g = GnuplotMate.new(script)
    g.displayOutput
  end
  
  
  def self.open_data_files
    files = Array.new
    script=STDIN.read
    script.scan(/^.*['"](.+)['"].*using/) do |y|
     file = y[0]
        puts %x{open -a TextMate.app #{file}}
      end
  end
  
  
  
  
  
  # Methods

  def execute
    # Execute the script with Gnuplot
    IO.popen(path, 'w') do |plot|
      plot.puts self.script
    end
  end
  
  
  def displayOutput
    
    # Determine the Terminal
    terminal = self.script.scan(/^\W*set terminal (\w*)/)
    if terminal.empty?
      puts "Error: No terminal in script found"
      return
    end
    if terminal.length > 1
      puts "Error: More than one terminal setting in script found"
      return
    end
    terminal = terminal[0][0]
    
    # Find Outputfiles and Line numbers
    self.outputFiles = Array.new
    self.outputFilesLines = Array.new

    script.each_with_index{|line,no| 
      output = line.scan((/^\s*set output\W+['"](.*)['"]/))
      if output.length == 1
        string = output[0].join
        self.outputFiles << File.basename(string,File.extname(string))
        self.outputFilesLines << no+1
      end
      }
      
    # Display the Output according the terminal
    
    case terminal
    when "epslatex"
      self.displayEpslatex
    when "lua"
      self.displayLua
    when "aqua"
      # Do nothing because aqua will allready be displayed
    else
      puts "Error: No Supported Terminal"  
    end
    
    
  end 


  def displayLua
    
    #Create LaTexfile
     gpname = File.basename(ENV["TM_FILEPATH"],File.extname(ENV["TM_FILEPATH"]))
     latex = Tempfile.new("Plot_#{gpname}.tex")
     latex.puts '\documentclass[fontsize=11pt]{scrartcl}'
     latex.puts '\usepackage[utf8]{inputenc}'
     latex.puts '\usepackage[T1]{fontenc}'
     latex.puts '\usepackage[]{gnuplot-lua-tikz}'
     latex.puts '\usepackage[active,tightpage]{preview}'
     latex.puts '\PreviewEnvironment{tikzpicture}'
     latex.puts '\setlength\PreviewBorder{2mm}'
     latex.puts '\usepackage{lmodern}'
     latex.puts '\usepackage[]{siunitx}'
     latex.puts '\newcommand{\bez}[1]{\mathrm{#1}}'
     latex.puts '\begin{document}'
     latex.puts '\pagestyle{empty}'
     self.outputFiles.each do |f|
       latex.puts "\\include{#{f}} \\newpage" 
     end
     latex.puts '\end{document}'

     #Run PDFLatex
     latex.flush
     puts %x{/usr/texbin/pdflatex -interaction=batchmode #{latex.path}}

     #Determine Page to Display
     currentLine =  Integer(ENV["TM_LINE_NUMBER"])
     page = 0
     self.outputFilesLines.each do |no|
          if currentLine >= no
            page = page+1
          end
     end
     if page == 0
       page = 1
     end


     # Open the PDFFile in Skim
     pdfFileName = File.expand_path("Plot_#{gpname}.pdf")
     `osascript &>/dev/null \
        -e 'set theFile to POSIX file "#{pdfFileName}" ' \
        -e 'tell application "Skim"' \
        -e 'activate' \
        -e 'open theFile' \
        -e 'revert front document' \
        -e 'set view settings of front document to {auto scales:true}' \
        -e 'tell front document to go to page #{page}' \
        -e 'end tell' &`
    
    
    
    
  end

  def displayEpslatex
    
     #Dertermine Size of Terminal
     size = script.scan(/^\W*set terminal.*size (\d+\.*\d*),(\d+\.*\d*)/)
     if size.empty?
       puts "Error: No size in Terminal defined"
       return
     end
     if size.length > 1
       puts "Error: More than on Size defined"
       return
     end
     size = size[0]
     
     # Convert eps to pdf
     files.each do |f|
       puts %x{bash /usr/texbin/epstopdf #{f}.eps}
     end
     
     #Create LaTexfile
     gpname = File.basename(ENV["TM_FILEPATH"],File.extname(ENV["TM_FILEPATH"]))
     latex = Tempfile.new("Plot_#{gpname}.tex")
     latex.puts '\documentclass[fontsize=11pt]{scrartcl}'
     latex.puts '\usepackage[utf8]{inputenc}'
     latex.puts '\usepackage[T1]{fontenc}'
     latex.puts '\usepackage[]{graphicx}'
     latex.puts '\usepackage[]{xcolor}'
     latex.puts "\\usepackage[papersize={#{size[0]}in,#{size[1]}in},scale=1,layoutoffset={-15pt,-2pt}]{geometry}"
     latex.puts '\usepackage{lmodern}'
     latex.puts '\usepackage[]{siunitx}'
     latex.puts '\newcommand{\bez}[1]{\mathrm{#1}}'
     latex.puts '\begin{document}'
     latex.puts '\pagestyle{empty}'
     files.each do |f|
       latex.puts "\\include{#{f}} \\newpage" 
     end
     latex.puts '\end{document}'
     
     #Run PDFLatex
     latex.flush
     puts %x{/usr/texbin/pdflatex -interaction=batchmode #{latex.path}}
     
     #Determine Page to Display
     currentLine =  Integer(ENV["TM_LINE_NUMBER"])
     page = 0
     filesLines.each do |no|
          if currentLine >= no
            page = page+1
          end
     end
     if page == 0
       page = 1
     end
     
     
     # Open the PDFFile in Skim
                              pdfFileName = File.expand_path("Plot_#{gpname}.pdf")
                              `osascript &>/dev/null \
                                 -e 'set theFile to POSIX file "#{pdfFileName}" ' \
                                 -e 'tell application "Skim"' \
                                 -e 'activate' \
                                 -e 'open theFile' \
                                 -e 'revert front document' \
                                 -e 'set view settings of front document to {auto scales:true}' \
                                 -e 'tell front document to go to page #{page}' \
                                 -e 'end tell' &`
                  
                  
    #Set Pfad in Gnuplot File Relative to Current ProjectPath
    
    if ENV["TM_PROJECT_DIRECTORY"]
      files.each do |f|
        path = Pathname.pwd
        path = path.relative_path_from(Pathname.new(ENV["TM_PROJECT_DIRECTORY"]))
        path = File.join(path,"#{f}")
        
        gnuplottex = File.read(File.expand_path("#{f}.tex"))
        gnuplottex = gnuplottex.gsub(/\\includegraphics\{(.*)\b/,'\includegraphics{' +  path )
          File.open(File.expand_path("#{f}.tex"), 'w') {|f| f.write(gnuplottex) }  
        end
      end
    
    
    
  end


  def run_plot_in_aquaterm(data)
    # Delete term lines, change output lines to "term aqua" in order to show plots in Aquaterm
    data.gsub!(/^\s+set term.*$/, "")
    plotnum = 0;
    data.gsub!(/^set output.*$/) { "set term aqua #{plotnum += 1}" }
    puts data
    execute data
  end


end
