#!/usr/local/bin/ruby
require 'aws-sdk'
require 'date'
require 'fileutils'

if ARGV.size == 0
   puts "Config  ./script.rb config"
   puts ""
   puts "Usage:   ./script.rb <action>"
   puts ""
   puts "Example: ./script.rb create_snapshots | list_snapshots | remove_snapshots"
  exit 0
end

def get_last_day(month)
	last_day = "31" if ["01","03","05","07","08","10","12"].include? month.to_s
	last_day = "30" if ["04","06","09","11"].include? month.to_s
        last_day = "28" if month == "02"
	return last_day
end

def create_description
	date 	= DateTime.new(2017,rand(1..12),rand(1..28),rand(1..23),rand(1..59),rand(1..59)) # %Y%m%d%H%M%S
	month 	= rand(1..12);month 	= "0#{month}" if month < 10	
	hour 	= rand(1..23);hour 	= "0#{hour}" if hour < 10	
	min 	= rand(1..59);min 	= "0#{min}" if min < 10	
	sec 	= rand(1..59);sec 	= "0#{sec}" if sec < 10	
        last_day = get_last_day(month) #last_day
        n = rand(1..10)
	case n
	   when 1..3
		#random
		description = "backup_#{date.strftime('%Y%m%d%H%M%S')}"
	   when 4..6
		#15th day
		description = "backup_2017#{month}15#{hour}#{min}#{sec}"
	   when 7..10
		#month's last day
		description = "backup_2017#{month}#{last_day}#{hour}#{min}#{sec}"
	end
	return description
end


def create_snapshots
	ec2 = Aws::EC2::Resource.new
	10.times {
		description = create_description
		ec2.instances.each {|i|
  			i.volumes.each {|v|
				snapshot = ec2.create_snapshot(volume_id: v.id,description: description) #creating snapshot
        		  	puts "creating new snapshot..."
			  	while true do
    			    		s = Aws::EC2::Snapshot.new(id: snapshot.id)
    	  		    		break if s.state == 'completed'
          	 	    		sleep 15
  			  	end
  			  	puts "Snapshot: #{snapshot.description} has been created"
			  	puts ""
		    	}  
	 	}
	}  
end

def remove_snapshots
	ec2 = Aws::EC2::Resource.new
	ec2.instances.each {|i|	#search by instance
	  	i.volumes.each {|v|	#search by volume
	  		snapshots_lastdays = {}
	    		v.snapshots.each {|s|
				description_array = s.description.split('_'); date = description_array[1];
				date_array = date.split('')

				month = date_array[4..5].join("")
				day = date_array[6..7].join("")
				last_day = get_last_day(month)

		      		# remove all snapshots except 15th and last day of each month
				if  day != last_day && day != "15"
	    				puts "#{s.description} has been removed"
				        s.delete
				end	     	 
				snapshots_lastdays[s.id] = "#{date_array.join("")}"
	    		}
			#sort snapshots lefts by date
	    		sorted = snapshots_lastdays.sort_by {|snap,date| date}
	    		early_date = "";early_snap = ""
	
	    		# keeping only the last snapshot of each day
        	    	sorted.each {|snap,date|
				date_array = date.split('')
				month_day =  date_array[4..7].join("") #mmdd
				if early_date == month_day
		     			Aws::EC2::Volume.new(v.id).snapshots.each {|s|
					if s.id == early_snap
						puts "#{s.description} has been removed" 
				 		s.delete
					end
  					}
				end
				early_date = month_day;early_snap = snap
		    	}
		}
	}
end

def list_snapshots
	snapshots = [] 
	ec2 = Aws::EC2::Resource.new
	ec2.instances.each {|i|
	  	i.volumes.each {|v|
			puts "Volume: #{v.id}"
  			v.snapshots.each {|s|
				snapshots << s.description
			}
			snapshots.sort.each {|s|puts "     #{s}"};puts ""
		}
	}	
end

def config
	conf = []
	print "aws_access_key_id: ";	conf 	<< STDIN.gets.chomp
	print "aws_secret_access_key: ";conf 	<< STDIN.gets.chomp
	print "region: ";		conf	<< STDIN.gets.chomp

	# filling config files
	file = 'aws/credentials'
	lines = IO.readlines(file).map {|line|line =~ /aws_access_key_id/ ? "aws_access_key_id = #{conf[0]}" : line }
	File.open(file,'w') {|f|f.puts lines}
	lines = IO.readlines(file).map {|line|line =~ /aws_secret_access_key/ ? "aws_secret_access_key = #{conf[1]}" : line }
	File.open(file,'w') {|f|f.puts lines}
	file = 'aws/config'
	lines = IO.readlines(file).map {|line|line =~ /region/ ? "region = #{conf[2]}" : line }
	File.open(file,'w') {|f|f.puts lines}
	
	# moving aws directory to HOME
	FileUtils.copy_entry('aws', "#{Dir.home}/.aws")
	puts "configuration completed"
end

config if ARGV[0] == "config"
create_snapshots if ARGV[0] == "create_snapshots"
list_snapshots if ARGV[0] == "list_snapshots"
remove_snapshots if ARGV[0] == "remove_snapshots"
