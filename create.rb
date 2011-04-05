#!/usr/bin/ruby
# create.rb

require 'optparse'
require 'erb'
require 'fileutils'

options = {}
name = nil
template_dir = nil

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: create.rb -n NAME [options]"

  options[:verbose] = false
  options[:run_as] = nil
  options[:name] = nil
  options[:owner] = nil
  options[:force] = false

  opts.on( '-v', '--verbose', 'Output more information' ) do options[:verbose] = true end
  opts.on( '-n', '--ime IME', 'Name of server (UNIX name)' ) do |s| options[:name] = s end
  # opts.on( '-o', '--owner USERNAME', 'Owner username' ) do |s| options[:owner] = s end
  # opts.on( '-t', '--template DIR', 'Alternative template directory' ) do |dir| options[:template_dir] = dir end
  opts.on( '-f', '--force', 'Force creation if server already exists' ) do options[:force] = true end
  opts.on( '-h', '--help', 'Display this' ) do puts opts; exit end
end
optparse.parse!
@opts = options

name = options[:name]
template_dir = options[:template_dir]

cfg_template = <<EOF
echo Executing Server Config...
lanmode 0
rcon_password <%= server_rcon %>
maxplayers <%= server_maxpl %>
port <%= server_port %>
hostname <%= server_hostname %>
gamemode0 grandlarc 1
filterscripts base gl_actions gl_property gl_realtime
announce 0
query 1
weburl www.sa-mp.com
maxnpc 0
onfoot_rate 40
incar_rate 40
weapon_rate 40
stream_distance 300.0
stream_rate <%= server_stream_rate %>
EOF

def verbose?() @opts[:verbose] end
def info(msg) puts "INFO: #{msg}" end
def warn(msg) puts "WARN: #{msg}" end
def err(msg)  puts "ERR: #{msg}"; exit end

(puts "You must pass name as argument!"; puts " example:  ./create.rb -n newserver1"; exit) if name.nil? or name.empty?
dir = `pwd | sed 's/.*\\///g'`.chop
err "PWD is not hosting dir!" if !File.exist? "./.samphosting"
err "Name contains unallowed characters!" if name =~ /[^a-z0-9\-_]/ or name =~ /[\.\/\\]/
if File.directory? "#{name}" and !options[:force]
  err "server/dir with name '#{name}' already exists!"
end
err "Name is too short!" if name.length < 3
err "Name is too long!" if name.length > 20
(template_dir_exist = File.directory? 'template') # if template_dir.nil?

if template_dir_exist
  info "creating new server (#{name}) from template ..."
  cmd = "cp -r template #{name}"
  if system cmd
    if File.directory? "#{name}"
      info "Done! Continuing with setup of server ..."
    else err "no dir #{name}!" end
  else err "error occurred while executing '#{cmd}'" end
else
  warn "There is no template/ directory! Creating one with SAMP 0.3r8 server from web ..."
  info "downloading ..."
  `wget -q -O samp03asvr_R8.tar.gz http://files.sa-mp.com/samp03asvr_R8.tar.gz`
  info "extracting ..."
  `tar xzf samp03asvr_R8.tar.gz`
  info "moving extracted server to template/"
  `mv samp03 template`
  info "generating server startup script"
  File.open("template/start", 'w+') do |f| f.puts('mkdir -p logs; ./samp03svr | tee -a logs/log__`date +"%Y_%m_%d-%H_%M_%S" | xargs echo`.txt') end
  info "mkdir logs for server"
  `mkdir -p template/logs`
  info "making startup script executable"
  FileUtils.chmod 0755, "template/start"
  info "Done! Continuing with setup of server ..."

  info "creating new server (#{name}) from template ..."
  cmd = "cp -r template #{name}"
  if system cmd
    if File.directory? "#{name}"
      info "Done! Continuing with setup of server ..."
    else err "no dir #{name}!" end
  else err "error occurred while executing '#{cmd}'" end
end

if verbose?
  puts
  puts "---------------"
  puts "  Configuring  "
  puts "---------------"
end

@vars = []
def addvar(name, msg, default=nil) @vars << [name, msg, default, nil] end
def unosvars()
  for var in @vars do
    must = var[2].nil? or var[2].empty?; uneseno, errors = false, 10
    while !uneseno
      print "#{var[1]} #{(!must)? "["+var[2]+"]" : "[!]"}: "
      STDOUT.flush
      in_txt = STDIN.gets.chomp
      if !in_txt.empty?
        var[3] = in_txt
        uneseno = true
      elsif in_txt.empty?
        if !must
          var[3] = var[2]
          uneseno = true
        end
      end
      if errors
        errors-=1
      else
        err "WT* ??"
      end
    end
  end
end
def getvar(ime) @vars.each {|var| return var[3] if var[0]==ime}; return false end

addvar "server_rcon", "RCON password", "#{name}#{10000+rand(99999-10000)}"
addvar "server_maxpl", "Max players", "50"
addvar "server_port", "Server port", "7778"
addvar "server_hostname", "Server hostname"
addvar "server_stream_rate", "Server stream rate", "1000"

unosvars() # input variables through stdin

template = ERB.new cfg_template
cfg = template.result(
  lambda do
    server_rcon  = getvar("server_rcon")
    server_maxpl = getvar("server_maxpl")
    server_port  = getvar("server_port")
    server_hostname = getvar("server_hostname")
    server_stream_rate = getvar("server_stream_rate")
  lambda { }
  end.call
)

info "Generating server.cfg"
File.open("#{name}/server.cfg", 'w+') do |f| f.puts(cfg) end
File.open("#{name}/.sampserver", 'a').close

puts ":: Server is configured! ::"
puts " - and can be started with `./control NAME start`"
