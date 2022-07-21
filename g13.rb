#!/usr/bin/ruby
#########################################################
#g13
# Author : Alex Auvenshine
#   Date : 2021-05-01
#License : MIT
#
#########################################################

##Requirements#
require 'tomlrb'
require 'pp'

###Constants###
VERSION='1.0.0'
DEFAULT_CONFIG_DIR='~/.config/g13'
DEFAULT_PROFILE='default'
G13_PATH='/opt/g13/g13d'
KEY_SHORT_NAMES={
'apostrophe' => "'",
'backslash' => '\\',
'backspace' => 'bks',
'capslock' => 'cap',
'comma' => ',',
'delete' => 'del',
'dot' => '.',
'down' => 'dwn',
'enter' => 'ent',
'equal' => '=',
'grave' => '`',
'home' => 'hom',
'insert' => 'ins',
'kpasterisk' => '*',
'kpdot' => '.',
'kpminus' => '-',
'kpplus' => '+',
'left' => 'lft',
'leftalt' => 'alt',
'leftbrace' => '[',
'leftctrl' => 'ctr',
'leftshift' => 'shf',
'minus' => '-',
'numlock' => 'num',
'pagedown' => 'pdn',
'pageup' => 'pup',
'right' => 'rgt',
'rightalt' => 'alt',
'rightbrace' => ']',
'rightctrl' => 'ctr',
'rightshift' => 'shf',
'scrolllock' => 'slk',
'semicolon' => ';',
'slash' => '/',
'space' => 'spa'
}
USAGE=<<~END

  Usage: #{File.basename(__FILE__)} [-h|--help] [-V|--version] [-c|--config-dir <DIR>] [--] [PROFILE]

END
HELP=<<~END

  #{File.basename(__FILE__)}:v#{VERSION}
    g13d wrapper script and profile manager

  Usage: #{File.basename(__FILE__)} [OPTIONS...] [PROFILE]

  [OPTIONS]:
   -c,--config-dir <DIR>  check for profile configs in <DIR>
                          <DIR>:
                            may be any readable directory
                          NOTE: if not specified, '#{DEFAULT_CONFIG_DIR}'
                            will be assumed

   -h, --help             display this help message and exit.
   -V, --version          display version info and exit.

   --                     process no more options. Treat all 
                          remaning args like [PROFILE].

  [PROFILE]:
   name of a profile config located in '#{DEFAULT_CONFIG_DIR}'
   cofig directory can be changed through --config-dir

   if no [PROFILE] is specified, '#{DEFAULT_PROFILE}' will be used.

END

#####Vars######
at=[]
flag=''   #main portion of the current arg
after=''  #any subsiquent portions to the current arg (possible "arg arg's" or continued short options)
dashes=0  
holding=''
configFile=''
mode=''

###Switches####
profile=DEFAULT_PROFILE
#configDir=Pathname(DEFAULT_CONFIG_DIR)
configDir=DEFAULT_CONFIG_DIR

###Functions###

#nextArg - get the next arg for a flag that requires it's own arg(s)
#takes the current flag, any text after the portion that matched the current flag, and the list of args
#returns a trimmed version of the 'after' text or the next arg in args
#if neither supplies an arg exit gracfully
def nextArg(flag, after, args)
	ret=''
	#if 'after' is not empty, use it for the next arg
	if ! after.empty?
		#if it starts with an equals, trim it off first
		if after.start_with?('=')
			ret=String.new(after[1..-1])
			after.clear
			return ret
		#otherwise just return it normally
		else
			ret=String.new(after)
			after.clear
			return ret
		end

	#if 'after' is empty, check the next arg
	else
		if args.length > 0
			ret=String.new(args[0])
			args.shift
			return ret
		else
			#if there is no next arg, complain and exit
			STDERR.puts "#{File.basename(__FILE__)}: Flag '#{flag}' requires an option!"
			exit 2
		end
	end
end

#check given configDir for a file matching profile (with or without a '.toml')
#return the found file, or false if none was found
def findConfig(configDir, profile)
	if File.file?("#{configDir}/#{profile}")
		return "#{configDir}/#{profile}"
	elsif File.extname(profile) != '.toml' && File.file?("#{configDir}/#{profile}.toml")
		return "#{configDir}/#{profile}.toml"
	else
		$stderr.puts "#{File.basename(__FILE__)}: profile '#{profile}' could not be found in '#{configDir}'!"
		exit 2
	end
end

#read the given file and process it as toml
#return the parsed toml as a hash
def readConfg(configFile)
	if File.readable?(configFile)
		return Tomlrb.load_file(configFile)
	else
		$stderr.puts "#{File.basename(__FILE__)}: profile '#{profile}' config '#{configFile}' could not be read!"
		exit 2
	end
end

def getStartingMode(config)
	if config['meta'].has_key?('startingMode')
		if config['mode'].has_key?(config['meta']['startingMode'])
			return config['meta']['startingMode']
		else
			$stderr.puts "#{File.basename(__FILE__)}: startingMode '#{config['meta']['startingMode']}' is undefined!"
			exit 3
		end
	else
		return config['mode'][config['mode'].first[0]]
	end
end

def getKeyDisplayName(modeName, keySetting)
	displayName=''
	if keySetting == nil
		return '   '
	else
		case keySetting
			when /^KEY_[^+]+$/ then displayName=keySetting.delete_prefix('KEY_').downcase
			when /^KEY_[^+]+\+.*$/ then displayName='K+K'
			when /^!/ then displayName='COM'
			when /^>/
				case keySetting
					when /^>mode/
						case keySetting
							when /^>modeup/, /^>modenext/
								displayName="M>"
							when /^>modedown/, /^>modeprev/
								displayName="M<"
							else
								if keySetting.delete_prefix('>mode ') == modeName
									displayName="*M#{keySetting.delete_prefix('>mode ')[0]}"
								else
									displayName="M#{keySetting.delete_prefix('>mode ')[0]}"
								end
						end
					else displayName='>'
				end
			when '' then displayName='   '
			else displayName='???'
		end
		if KEY_SHORT_NAMES.has_key?(displayName)
			displayName=KEY_SHORT_NAMES[displayName]
		end
		case displayName.length 
			when 3 then return displayName
			when 2 then return " " + displayName
			when 1 then return " " + displayName + " "
			else return '???'
		end
	end
end

def keyDisplay(config, modeName)
	return <<~END
	[#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['bd'])}]  [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['l1'])}] [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['l2'])}] [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['l3'])}] [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['l4'])}]
	   [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['m1'])}]   [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['m2'])}]     [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['m3'])}]   [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['mr'])}]
	 [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g1'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g2'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g3'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g4'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g5'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g6'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g7'])}]
	 [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g8'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g9'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g10'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g11'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g12'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g13'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g14'])}]
	     \\[#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g15'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g16'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g17'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g18'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g19'])}]/
	          \\[#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g20'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g21'])}][#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['g22'])}]/    [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['top'])}]
	                           [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['left'])}] o
	                               [#{getKeyDisplayName(modeName, config['mode'][modeName]['keys']['down'])}]
	END
end

def setMode(config, modeName)
	output=''
	rgb=[ 255, 0, 0 ]

	if config['mode'][modeName]['settings'].has_key?('rgb')
		rgb=config['mode'][modeName]['settings']['rgb']
	elsif config['meta'].has_key?('rgb')
		rgb=config['meta']['rgb']
	end
	output+="rgb #{rgb[0]} #{rgb[1]} #{rgb[2]}\n"
	config['mode'][modeName]['keys'].each { |key,value|
		if value == ''
			output+="bind #{key.upcase} !mod 0\n"
		else
			output+="bind #{key.upcase} #{value}\n"
		end
	}
	if config['mode'][modeName]['settings'].has_key?('keyDisplay')
		if config['mode'][modeName]['settings']['keyDisplay']
			puts keyDisplay(config, modeName)
		end
	elsif config['meta'].has_key?('keyDisplay')
		if config['meta']['keyDisplay']
			puts keyDisplay(config, modeName)
		end
	end
	return output
end

#####Main######
#parse args
args=Array.new($*)
while args.length > 0

	flag=''
	after=''
	holding=''
	dashes=0

	#handle single dash sep ('-' with no following chars does not count)
	if args[0] =~ /^-[^-]/
		dashes=1
		if args[0].length > 2
			flag=args[0][0..1]
			after=args[0][2..-1]
		else
			flag=args[0]
		end

	#handle double dash sep ('--' with no following chars does not count)
	elsif args[0] =~ /^--.+/
		dashes=2
		if args[0].include? '='
			flag,after=args[0].split('=',2)
			after.prepend('=')
		else
			flag=args[0]
		end

	#no dash ('-' and '--' with no following chars count as 'no dash')
	else
		flag=args[0]
	end

	#puts "flag='#{flag}'"
	#puts "after='#{after}'"

	#now that we've split the arg off, we can shift past it
	args.shift

	case flag
		when '-c','--config-dir'
			holding=nextArg(flag, after, args)
			if File.exist?(holding) && File.directory?(holding)
				configDir=holding
			else
				STDERR.puts "#{File.basename(__FILE__)}: '#{holding}' no such directory!"
				exit 2
			end
		when '-h','--help' then puts HELP; exit 0
		when '-V','--version' then puts "#{File.basename(__FILE__)}:v#{VERSION}"; exit 0
		when '--'
			at+=args
			if ! after.empty?
				at.unshift(after)
				after.clear
			end
			args.shift(args.length - 1)
		when /^-/ then STDERR.puts "#{File.basename(__FILE__)}: unrecognized arg '#{flag}'!"; puts USAGE; exit 2
		else at+=[flag]
	end

	#if we didn't use our 'after' arg, and this was an option (started with a dash)
	if ! after.empty? && dashes > 0
		#if this was a single dash arg, and the remainder didn't start with an equals sign
		if dashes == 1 && ! after.starts_with?('=')
			#add a beginning dash as these should be interperated as more single dash args
			args.unshift(after.prepend('-'))
		else
			#otherwise 'after' should have been used, so print an error
			STDERR.puts "#{File.basename(__FILE__)}: Flag '#{flag}' does not take options ('#{after[1..-1]}')!"
			exit 2
		end
	end

end
args=at
$*.keep_if {|arg| args.include?(arg)}

if $*.length > 0
	profile=$*[0]
	$*.shift
end

#puts "profile='#{profile}'"
#puts "configDir='#{configDir}'"
#puts "args='#{args}'"
#puts "$*='#{$*}'"

config=readConfg(findConfig(configDir, profile))

#pp config

if ! config.has_key?('mode') || config['mode'].length < 1
	$stderr.puts "#{File.basename(__FILE__)}: no modes defined!"
	exit 3
end

if config['meta'].has_key?('startingMode') #need to check that this is really a string (need retreiver methods)
	if config['mode'].has_key?(config['meta']['startingMode'])
		mode=config['meta']['startingMode']
	else
		$stderr.puts "#{File.basename(__FILE__)}: startingMode '#{config['meta']['startingMode']}' is undefined!"
		exit 3
	end
else
	mode=config['mode'].first[0]
end

g13 = Thread.new { system("sudo /opt/g13/g13d") }

trap("SIGINT") { 
	Thread.kill(g13)
	exit 1
}

until File.exist?('/tmp/g13-0_out')
	sleep 1
end

inio=IO.new(IO.sysopen('/tmp/g13-0','w'))
outio=IO.new(IO.sysopen('/tmp/g13-0_out','r'))

#puts setMode(config, mode)

inio << setMode(config, mode)
inio.flush
until outio.eof?
	line = outio.gets.chomp
	case line
		when /^modeup/
			puts 'modeup'
		when /^modedown/
			puts 'modedown'
		when /^mode .+/
			newMode=line.delete_prefix('mode ')
			if config['mode'].has_key?(newMode)
				#puts "setMode(config, '#{newMode}')"
				inio << setMode(config, newMode)
				inio.flush
			else
				$stderr.puts "#{File.basename(__FILE__)}: mode '#{newMode}' is undefined!"
			end
		else puts line
	end
end
