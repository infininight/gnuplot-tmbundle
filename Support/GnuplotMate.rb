require 'open3'
require 'tempfile'
require 'pathname'
require ENV['TM_SUPPORT_PATH'] + '/lib/textmate'  

Terminal = Struct.new(:name,:option,:line)
OutputFile = Struct.new(:base,:ext,:path,:line)
  
class GnuplotMateError < StandardError
  # Properties 
  attr_accessor :lineNumber, :lineColumn, :type
  
  def initialize(message,lineNumber,lineColumn,file,type)
    super(message)
    @lineNumber = lineNumber
    @lineColumn = lineColumn
    @type = type
    @file = file
  end  
    
  def self.gnuplotScriptError(gnuplotError)

    lineNumber = gnuplotError[/line (\d*)/,1].to_i
    lineColumn = gnuplotError.lines.to_a[2].index('^')
    file = gnuplotError[/\"(.*.gp)\"/,1]
    message = gnuplotError[/line .\d*:\s*(.*)/,1]    
    GnuplotMateError.new(message,lineNumber,lineColumn,file,"Gnuplot")
    
  end
  
  
  def self.internalError(message,lineNumber)
    GnuplotMateError.new(message,lineNumber,0,ENV['TM_FILEPATH'],"Gnuplot Bundle") 
  end
  
  def self.epstopdfError(epstopdfError,lineNumber)
    message = epstopdfError[/!!! Error:\s*(.*)/,1]
    GnuplotMateError.new(message,lineNumber,11,ENV['TM_FILEPATH'],"epstopdf") 
  end
  
  def showInTextmate
    TextMate.go_to(:line => self.lineNumber,:column => self.lineColumn+1)
    puts '^'
    puts self.type + ' Error:'
    puts self.message
  end
  
end


class GnuplotMate
  # Properties 
  attr_accessor :script, :outputFiles, :texHeader, :gpname, :userHeader, :gpFile
   
  # Comandos
  def gnuplot
    possible_paths = [ENV["TM_GNUPLOT"], `which gnuplot`, "/usr/local/bin/gnuplot"]
    possible_paths.select { |x| x && File.exist?(x) }.first
  end
  
  def pdflatex
    possible_paths = [ENV["TM_PDFLATEX"], `which pdflatex`, "/usr/texbin/pdflatex"]
    possible_paths.select { |x| x && File.exist?(x) }.first
  end
  
  def epstopdf
    possible_paths = [ENV["TM_EPSTOPDF"], `which epstopdf`, "/usr/texbin/epstopdf"]
    possible_paths.select { |x| x && File.exist?(x) }.first
  end
    
  # Konstruktor
  def initialize(script)
    @script = script
    @texHeader = ENV["TM_BUNDLE_SUPPORT"]+"/texHeader.tex"
    @gpFile = ENV["TM_FILEPATH"]
    @gpname = File.basename(ENV["TM_FILEPATH"],File.extname(ENV["TM_FILEPATH"]))
    
  end
   
  # Class Methods 
  def self.run
    # Execute the script with Gnuplot
    g = GnuplotMate.new(STDIN.read)
    begin
      g.execute
    rescue GnuplotMateError => e
      puts e.message 
    end
  end
  
  def self.run_and_display
    # Execute the script with Gnuplot and display the output according to the current terminal
    g = GnuplotMate.new(STDIN.read)
    begin
      g.execute
      g.displayOutput
    rescue GnuplotMateError => e
      puts e.showInTextmate
    end
  end
  
  def self.display
    # Display the output according to the current terminal if the output is allready produced
    g = GnuplotMate.new(STDIN.read)
    begin
      g.displayOutput
    rescue GnuplotMateError => e
      puts e.message
    end
  end
  
  
  def self.open_data_files
    script=STDIN.read
    script.scan(/^.*['"](.+)['"].*using/) do |y|
    file = y[0]
    puts %x{open -a TextMate.app #{file}}
    end
  end

  
  
  
  
  
# Methods

def execute
    
  IO.popen([gnuplot,self.gpFile, :err=>[:child, :out]]) { |gnuplot_io|
    output =  gnuplot_io.read
    if !output.empty?
      raise GnuplotMateError.gnuplotScriptError(output)      
    end
  }
        
end
   
def displayOutput
        
  # Scan the script for termial and outputs
       
  terminals = Hash.new
  self.outputFiles = Array.new
  
  self.script.each_line.with_index {|line,no|
    # Find Terminal
    line.scan(/\A\s*set term\w+\W+(\w+)\s+(\w+)/) { |x,y|
      terminals[x] = Terminal.new(x,y,no+1);
    }
    # Find Output
    line.scan(/\A\s*set output\W+['"](.*)['"]/) { |x|
      ext = File.extname(x[0])
      base = File.basename(x[0],ext)
      path = File.expand_path(x[0]) 
      self.outputFiles << OutputFile.new(base,ext,path,no)
    }   
  }

  
  # Also look in the output.list for outputs
  if File.file?("output.list")
    File.readlines("output.list").each {|line|
      ext = File.extname(line)
      base = File.basename(line,ext)
      path = File.expand_path(line) 
      self.outputFiles << OutputFile.new(base,ext,path,1)
    }
  end
  
   # Detect User Headers 
   self.userHeader = self.script.scan(/TEXHEADER:(.*)/).to_s
  
  # Check for Errors
  if terminals.empty?
    raise GnuplotMateError.internalError('No terminal defined',1)
  end
  if terminals.size > 1
    raise GnuplotMateError.internalError('Different terminals Defined',terminals[terminals.keys.last][:line])
  end
  
  terminal = terminals[terminals.keys.first]

      
  # Display the Output according the terminal 
  case terminal[:name]
  when "epslatex"
    self.displayEpslatex(true)
  when "lua"
    if terminal[:option] == "tikz"
      self.displayLua
    else
      raise GnuplotMateError.internalError('Lua terminal needs tikz option',terminal[:line])
    end
  when "aqua","x11"
    # Do nothing because aqua will allready be displayed
  when "pdf","pdfcairo"
    self.openOutputFileInPreview
  when "png","pngcairo"
    self.openOutputFileInPreview
  when "cairolatex"
    case terminal[:option]
    when "eps"
      self.displayEpslatex(true)
    when "pdf"
      self.displayEpslatex(false)
    else
      raise GnuplotMateError.internalError('cariolatex terminal needs eps or pdf option',terminal[:line])
    end
  else
    raise GnuplotMateError.internalError(terminal[:name] + ' not supported by this bundle',terminal[:line])  
  end
    
    
end 

def displayLua
    
  #Define Terminal Dependent Package String and Envirorment  
  packages = '\usepackage[]{gnuplot-lua-tikz}'
  previewEnv = 'tikzpicture'
    
  #Run PDFLatex
  self.runLatexOnTempFile(packages,previewEnv)
        
  #Show in Skim
  self.findCurrentPageAndShowDocumentInSkim
   
end

def displayEpslatex(isEps)
    
  if isEps
    # Convert eps to pdf
    self.outputFiles.each { |outputFile|
      IO.popen([epstopdf,outputFile[:base] + '.eps', :err=>[:child, :out]]) { |io|
        output =  io.read
        if !output.empty?
          raise GnuplotMateError.epstopdfError(output,outputFile[:line]+1)      
        end
      }
    }
  end
  
   
  #Define Terminal Dependent Package String and Envirorment  
  packages = '\usepackage[]{graphicx} \usepackage[]{xcolor}' 
  previewEnv = 'picture'
     
  #Run PDFLatex
  self.runLatexOnTempFile(packages,previewEnv)
     
  #Show in Skim
  self.findCurrentPageAndShowDocumentInSkim
                  
  #Set Pfad in Gnuplot File Relative to Current ProjectPath
    
  if ENV["TM_PROJECT_DIRECTORY"]
    self.outputFiles.each { |outputFile|
      path = Pathname.pwd
      path = path.relative_path_from(Pathname.new(ENV["TM_PROJECT_DIRECTORY"]))
      path = File.join(path,outputFile[:base])
        
      gnuplottex = File.read(outputFile[:path])
      gnuplottex = gnuplottex.gsub(/\\includegraphics\{(.*)\b/,'\includegraphics{' +  path )
      File.open(outputFile[:path], 'w') {|fileToWrite| fileToWrite.write(gnuplottex) }  
    }
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
  
  def runLatexOnTempFile(packages,previewEnv)
     
    latex = Tempfile.new("Plot_#{self.gpname}.tex")
    latex.puts '\documentclass[fontsize=11pt]{scrartcl}'
    latex.puts packages
    latex.puts '\usepackage[active,tightpage]{preview}'
    latex.puts "\\PreviewEnvironment{#{previewEnv}}"
    latex.puts '\setlength\PreviewBorder{2mm}'
    latex.puts File.read(self.texHeader)
    latex.puts self.userHeader
    latex.puts '\begin{document}'
    latex.puts '\pagestyle{empty}'
    self.outputFiles.each {|f|
      f = f[:base]
      latex.puts "\\include{#{f}} \\newpage" 
    }
    latex.puts '\end{document}'
     
    #Run PDFLatex
    latex.flush
    puts %x{/usr/texbin/pdflatex -interaction=batchmode #{latex.path}}
    latex.close
  end
  
  def findCurrentPageAndShowDocumentInSkim
    
    #Determine Page to Display
    currentLine =  Integer(ENV["TM_LINE_NUMBER"])
    page = 0
    self.outputFiles.each { |outputFile|
      if currentLine >= outputFile[:line]
        page = page+1
      end
    }
    if page == 0
      page = 1
    end
         
    # Open the PDFFile in Skim
    pdfFileName = File.expand_path("Plot_#{self.gpname}.pdf")
    `osascript &>/dev/null \
    -e 'set theFile to POSIX file "#{pdfFileName}" ' \
    -e 'tell application "Skim"' \
    -e 'activate' \
    -e 'set theDocument to open theFile' \
    -e 'revert theDocument' \
    -e 'set view settings of theDocument to {auto scales:true}' \
    -e 'tell theDocument to go to page #{page}' \
    -e 'end tell' &`

  end

  def openOutputFileInPreview
    fileList = Array.new()
    self.outputFiles.each { |f|
      fileList << f[:path]
    }
    fileString = '"' + fileList.join('","') + '"'
    `osascript &>/dev/null \
    -e 'set theFileList to {#{fileString}} ' \
    -e 'set thePosixFileList to {}' \
    -e 'repeat with currentFile in theFileList' \
    -e 'set currentPosixFile to POSIX file currentFile' \
    -e 'copy currentPosixFile to the end of thePosixFileList' \
    -e 'end repeat' \
    -e 'tell application "Preview"' \
    -e 'activate' \
    -e 'open thePosixFileList' \
    -e 'end tell' &`
  end

end
