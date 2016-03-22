#!/usr/bin/ruby

require 'rubygems'
require 'google/api_client'
require 'open-uri'
require 'tempfile'
require 'fileutils'
require 'parallel'
require 'trollop'

module Colors      # this allows using colors with ANSI escape codes
    
    def colorize(text, color_code)
        if STDOUT.tty?
            return "\e[#{color_code}m#{text}\e[0m"
        else
            return text
        end
    end
    
    def red(text); colorize(text, 31); end
    def green(text); colorize(text, 32); end
    def yellow(text); colorize(text, 33); end
    def blue(text); colorize(text, 34); end
    def magenta(text); colorize(text, 35); end
    def cyan(text); colorize(text, 36); end
    def white(text); colorize(text, 37); end
end

module Output		# prityfied outputs
	def print_error(message, *argument)
		if argument == []
			puts red("Error: ")+message
		else
			puts red("Error: ")+message+" <#{argument}>"
		end
	end

	def print_warning(message)
        puts yellow("Warning: ")+message
    end

    def echo(argument)    #  this behaves exactly like puts, unless quiet is on. Use for all output messages.
        puts argument unless @opts[:quiet]
    end

    def info(argument)
        echo blue("Info: ")+argument
    end
end

module Messages		
	STR_NO_FILE       = "The api key file doesn't exist."
	STR_FAIL_CONN     = "There was an error connecting with the API."
	STR_FAIL_REQ      = "There was an error making the API request."
	STR_FAIL_DOWNLOAD = "Failed to download. This is usually a problem from www.youtubeinmp3.com"
	STR_NIL_MODE      = "Flag --mode is required. See --help for help"
	STR_WRONG_MODE    = "That mode isn't supported. See --help for help."
	STR_NIL_QRY       = "You need to tell me what to download. See --help for help."
	STR_WRONG_NUM_RESULTS = "Can't download that number of results. See --help for help."
	STR_EMPTY 		  = "Couldn't find any items."
	STR_REDIRECT	  = "You can try going to: "
end

module Everything    
    include Colors
    include Output
    include Messages
end



=begin 
Class to make API requests
=end
class API 		
	include Everything

	def initialize(file)
		if File.exist? File.expand_path(file)
			@key = File.read(File.expand_path(file))
		else
			printError(STR_NO_FILE, file)
			exit 1
		end
	end

	def connect()
		begin
			@client = Google::APIClient.new(
			    :key => @key,
			    :authorization => nil,
			    :application_name => "YoutubeDownloader",
			    :application_version => "1.0.0"
			)
		 	@youtube = @client.discovered_api("youtube", "v3")
		rescue Exception => error
			print_error(STR_FAIL_CONN, error)
		end
	end

	def search_playListItems_by_id(id, max_results)
		begin
			search_response = @client.execute!(
		    	:api_method => @youtube.playlist_items.list,
		    	:parameters => {
		        	:part => "snippet",
		        	:playlistId => id,
		        	:maxResults => max_results
		      	}
		    )
		rescue Exception => error
	    	print_error(STR_FAIL_REQ, error)
	    	exit 1
	    end

	    return search_response.data.items
	end

	def search_video_by_id(id, max_results)
		begin
			search_response = @client.execute!(
		    	:api_method => @youtube.videos.list,
		    	:parameters => {
		        	:part => "snippet",
		        	:id => id,
		        	:maxResults => max_results
		      	}
		    )
		rescue Exception => error
	    	print_error(STR_FAIL_REQ, error)
	    	exit 1
	    end

	    return search_response.data.items
	end

	def search_query(q, max_results)
		begin
			search_response = @client.execute!(
		    	:api_method => @youtube.search.list,
		    	:parameters => {
		        	:part => "snippet",
		        	:q => q,
		        	:type => "video",
		        	:maxResults => max_results
		      	}
		    )
		rescue Exception => error
	    	print_error(STR_FAIL_REQ, error)
	    	exit 1
	    end

	    #puts "#{search_response.data.items}"
	    return search_response.data.items
	end
end


=begin 
This is the real deal
=end
class App  
	include Everything

	def initialize()
		@modes = Set.new [:list, :video, :search]
        @opts = Trollop::options do
	    	opt :mode, "Type of the download (list, video, search)", :type => String, :default => nil
	    	opt :query, "What to download. For list and video should be the id, for search should be a query", :type => String, :default => nil
	    	opt :out, "Where the downloads will store", :type => String, :default => "~/Music"
	    	opt :key, "Path to the file with the API key", :type => String, :default => "~/.config/youtubedownloader/apikey"
	    	opt :quiet, "To silence the output"
	    	opt :max_results, "Max items to download [1, 50]", :type => :int, :default => 25
		end

		check_options
    end

    def check_options
    	if @opts[:mode].nil?
    		print_error(STR_NIL_MODE)
    		exit 1
    	end

    	unless @modes.include?(@opts[:mode].to_sym)
    		print_error(STR_WRONG_MODE)
    		exit 1
    	end

    	if @opts[:query].nil?
    		print_error(STR_NIL_QRY)
    		exit 1
    	end

    	if @opts[:max_results] < 1 || @opts[:max_results] > 50
    		print_error(STR_WRONG_NUM_RESULTS)
    		exit 1
    	end 

    	Dir.mkdir(File.expand_path(@opts[:out])) unless File.exists?(File.expand_path(@opts[:out]))
    end

    def youtube_in_mp3(title, video_id)
    	info("Downloading <#{title}> with id <#{video_id}>")

    	mp3 = open("http://www.youtubeinmp3.com/fetch/?video=http://www.youtube.com/watch?v=#{video_id}")
		if mp3.is_a? Tempfile
			FileUtils.mv(mp3.path, File.expand_path("#{@opts[:out]}/#{title}.mp3"))
		else
			print_error(STR_FAIL_DOWNLOAD, title, video_id) 
			print_warning(STR_REDIRECT, "http://www.youtubeinmp3.com/fetch/?video=http://www.youtube.com/watch?v=#{video_id}")
		end
    end

	def run
		api = API.new(@opts[:key])
		api.connect

		case @opts[:mode].to_sym
		when :list
			videos = api.search_playListItems_by_id(@opts[:query], @opts[:max_results])

			if videos.length == 0
				info(STR_EMPTY)
			end

			Parallel.each(videos) do |video|
				youtube_in_mp3(video.snippet.title, video.snippet.resourceId.videoId)
			end
		when :video # Multiple ids should be comma separeted
			videos = api.search_video_by_id(@opts[:query], @opts[:max_results])

			if videos.length == 0
				info(STR_EMPTY)
			end

			Parallel.each(videos) do |video|
				youtube_in_mp3(video.snippet.title, video.id)
			end
		when :search
			videos = api.search_query(@opts[:query], @opts[:max_results])

			if videos.length == 0
				info(STR_EMPTY)
			end

			Parallel.each(videos) do |video|
				youtube_in_mp3(video.snippet.title, video.id.videoId)
			end
		end
	end
end

app = App.new
app.run
