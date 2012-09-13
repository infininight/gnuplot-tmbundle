require 'open3'
require 'tempfile'
require 'pathname'
require ENV['TM_SUPPORT_PATH'] + '/lib/textmate'  
  
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
  
  def showInTextmate
    TextMate.go_to(:line => self.lineNumber,:column => self.lineColumn+1)
    puts '^'
    puts self.type + ' Error:'
    puts self.message
  end
  
end


class GnuplotMate
  # Properties 
  attr_accessor :script, :outputFiles, :outputFilesLines, :texHeader, :gpname, :userHeader, :gpFile
   
  # Comandos
  def gnuplot
    possible_paths = [ENV["TM_GNUPLOT"], `which gnuplot`, "/usr/local/bin/gnuplot"]
    possible_paths.select { |x| x && File.exist?(x) }.first
  end
  
  def pdflatex
    possible_paths = [ENV["TM_PDFLATEX"], `which pdflatex`, "/usr/texbin/pdflatex"]
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
        
  # Determine the Terminal
  terminalLine = self.script.scan(/^\s*set term\w* (\w*)\W?(\w*)/)
  if terminalLine.empty?
    puts "Error: No terminal in script found"
    return
  end
    
    
  terminal = terminalLine[0][0]
  terminalOption = terminalLine[0][1]
    
  if terminalLine.length > 1
    
    terminalLine.each do |line|
           
      if !terminal.eql?(line[0])
        puts "Error: Different terminal settings in script found"
        return 
      end
    end
  end


  # Find Outputfiles and Line numbers
  self.outputFiles = Array.new
  self.outputFilesLines = Array.new

  # Find Outputs
  self.script.each_line.with_index{|line,no| 
    output = line.scan((/^\s*set output\W+['"](.*)['"]/))
    if output.length == 1
      string = output[0].join
      self.outputFiles << string #File.basename(string,File.extname(string))
      self.outputFilesLines << no+1
    end
  }
    
  # Also look in the output.list
  if File.file?("output.list")
    File.readlines("output.list").each do |line|
      self.outputFiles << line
      self.outputFilesLines << 1
    end
  end
       
  # Detect User Headers
  self.userHeader = self.script.scan(/TEXHEADER:(.*)/).to_s
      
  # Display the Output according the terminal
    
  case terminal
  when "epslatex"
    self.displayEpslatex(true)
  when "lua"
    if terminalOption == "tikz"
      self.displayLua
    else
      puts "Error:Lua terminal needs tikz option"
      return
    end
  when "aqua"
    # Do nothing because aqua will allready be displayed
  when "pdf","pdfcairo"
    self.openOutputFileInPreview
  when "png","pngcairo"
    self.openOutputFileInPreview
  when "cairolatex"
    case terminalOption
    when "eps"
      self.displayEpslatex(true)
    when "pdf"
      self.displayEpslatex(false)
    else
      puts "Error:cairolatex terminal needs eps or pdf option"
      return
    end
  else
    puts "Error: No Supported Terminal"  
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
    self.outputFiles.each do |f|
      f = File.basename(f,File.extname(f))
      puts %x{bash /usr/texbin/epstopdf #{f}.eps}
    end
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
    self.outputFiles.each do |f|
      path = Pathname.pwd
      path = path.relative_path_from(Pathname.new(ENV["TM_PROJECT_DIRECTORY"]))
      fileName = File.basename(f,File.extname(f))
      path = File.join(path,"#{fileName}")
        
      gnuplottex = File.read(File.expand_path("#{f}"))
      gnuplottex = gnuplottex.gsub(/\\includegraphics\{(.*)\b/,'\includegraphics{' +  path )
        File.open(File.expand_path("#{f}"), 'w') {|fileToWrite| fileToWrite.write(gnuplottex) }  
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
    self.outputFiles.each do |f|
      f = File.basename(f,File.extname(f))
      latex.puts "\\include{#{f}} \\newpage" 
    end
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
    self.outputFilesLines.each do |no|
      if currentLine >= no
        page = page+1
      end
    end
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
    self.outputFiles.each do |f|
      fileList << File.expand_path("#{f}")
    end
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
