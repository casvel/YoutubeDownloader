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
            return "\e[1m\e[#{color_code}m#{text}\e[0m"
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

	def print_warning(message, *argument)
		if argument == []
        	puts yellow("Warning: ")+message
        else
        	puts yellow("Warning: ")+message+" <#{argument}>"
        end
    end

    def print_songs(songs)
    	songs.each do |song|
    		puts green(song[:title])+" with id "+green(song[:id])
    	end
    end

    def echo(argument)    #  this behaves exactly like puts, unless quiet is on. Use for all output messages.
        puts argument unless @opts[:quiet]
    end

    def info(argument)
        echo blue("Info: ")+argument
    end

    def info2(argument)
        echo cyan("Info: ")+argument
    end
end

module Messages		
	STR_NO_FILE       = "The api key file doesn't exist."
	STR_FAIL_CONN     = "There was an error connecting with the API."
	STR_FAIL_REQ      = "There was an error making the API request."
	STR_FAIL_DOWNLOAD = "Failed to download."
	STR_NIL_MODE      = "Flag --mode is required. See --help for help"
	STR_WRONG_MODE    = "That mode isn't supported. See --help for help."
	STR_NIL_QRY       = "Flag --query is required. See --help for help."
	STR_WRONG_NUM     = "Input a number inside the correct range. See --help for help."
	STR_EMPTY 		  = "Couldn't find any items."
	STR_REQUEST_ERROR = "Request error. Retrying: "
	STR_FAILED_SONGS  = "Error while downloading: "
	STR_RETRY_DOWNLOAD = "Retry download? (y/n)"
	STR_YOU_CAN_DO_IT = "Please type \"y\" or \"n\"."
	STR_FAIL_MOVE     = "There was an error moving the file. "
	STR_FAIL_CREATE   = "Can't create output directory. "
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
			print_error(STR_NO_FILE, file)
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

	def request(method, params, skip)

		items = []
		total = nil
		max_results = params[:maxResults]

		while (total.nil? || total > 0) && max_results > 0
			begin

				params[:maxResults] = max_results > 50 ? 50 : max_results

				search_response = @client.execute!(
			    	:api_method => method,
			    	:parameters => params
			    )

				total ||= search_response.data.pageInfo.totalResults

				search_response.data.items.each do |item| 
					if skip == 0
						items << item
						max_results -= 1
					else
						skip -= 1
						total -= 1
					end
				end

			    unless search_response.data.next_page_token.nil?
			    	params[:pageToken] = search_response.data.next_page_token
			    end 

			rescue Exception => error
		    	print_error(STR_FAIL_REQ, error)
		    	exit 1
		    end
		end

		#puts "#{items}"
	    return items
	end

	def search_playListItems_by_id(id, max_results, skip)

	    params = {
	    	:part => "snippet",
		    :playlistId => id,
		    :maxResults => max_results
		}
	    response = request(@youtube.playlist_items.list, params, skip)
	    return response
	end

	def search_video_by_id(id, max_results, skip)

	    params = {
	    	:part => "snippet",
        	:id => id,
        	:maxResults => max_results
	    }
	    response = request(@youtube.videos.list, params, skip)
	    return response
	end

	def search_query(q, max_results, skip)

	    params = {
	    	:part => "snippet",
        	:q => q,
        	:type => "video",
        	:maxResults => max_results
	    }
	    response = request(@youtube.search.list, params, skip)
	    return response
	end
end


=begin 
This is the real deal
=end
class App  
	include Everything

	def initialize()
		@modes = Set.new [:list, :video, :search]
		@mutex = Mutex.new
        @opts = Trollop::options do
	    	opt :mode, "Type of the download (list, video, search).", :type => String, :default => nil
	    	opt :query, "What to download. For list and video should be the id, for search should be a query.", :type => String, :default => nil
	    	opt :out, "Where the downloads will store.", :type => String, :default => "~/Music"
	    	opt :key, "Path to the file with the API key.", :type => String, :default => "~/.config/youtubedownloader/apikey"
	    	opt :quiet, "To silence the output."
	    	opt :max_results, "Max items to download. >= 1", :type => :int, :default => 25
	    	opt :skip, "Skip the first <i> items of the query. >= 0", :type => :int, :default => 0
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

    	if @opts[:max_results] < 1
    		print_error(STR_WRONG_NUM)
    		exit 1
    	end 

    	if @opts[:skip] < 0
    		print_error(STR_WRONG_NUM)
    		exit 1
    	end 

    	begin
    		Dir.mkdir(File.expand_path(@opts[:out])) unless File.exists?(File.expand_path(@opts[:out]))
    	rescue Exception => error
    		print_error(STR_FAIL_CREATE, error)
    		exit 1
    	end
    end

    def youtube_in_mp3(title, id)
    	
    	info("Downloading <#{title}> with id <#{id}>")

    	mp3 = open("http://www.youtubeinmp3.com/fetch/?video=http://www.youtube.com/watch?v=#{id}")
    	retries = 3

		while (!(mp3.is_a? Tempfile) || mp3.size < 20_000) && retries > 0
			info2(STR_REQUEST_ERROR+" "+title)
			mp3 = open("http://www.youtubeinmp3.com/fetch/?video=http://www.youtube.com/watch?v=#{id}")
			retries -= 1
		end

		if !(mp3.is_a? Tempfile) || mp3.size < 20_000
			print_error(STR_FAIL_DOWNLOAD, title, id)
			return STR_FAIL_DOWNLOAD
		else
			begin
				FileUtils.mv(mp3.path, File.expand_path("#{@opts[:out]}/#{title}.mp3"))
			rescue Exception => error
				print_error(STR_FAIL_MOVE, error)
				return STR_FAIL_MOVE
			end
			return "Success"
		end 
    end

	def run
		api = API.new(@opts[:key])
		api.connect

		fails = Array.new # to retry download

		case @opts[:mode].to_sym
		when :list
			videos = api.search_playListItems_by_id(@opts[:query], @opts[:max_results], @opts[:skip])

			if videos.length == 0
				info(STR_EMPTY)
			end

			fails += Parallel.map(videos) do |video|
				title = video.snippet.title
				id    = video.snippet.resourceId.videoId

				result = youtube_in_mp3(title, id)	
				{title:title, id:id} if result != "Success"
			end
		when :video # Multiple ids should be comma separeted
			videos = api.search_video_by_id(@opts[:query], @opts[:max_results], @opts[:skip])

			if videos.length == 0
				info(STR_EMPTY)
			end

			fails += Parallel.map(videos) do |video|
				title = video.snippet.title
				id    = video.id

				result = youtube_in_mp3(title, id)	
				{title:title, id:id} if result != "Success"
			end
		when :search
			videos = api.search_query(@opts[:query], @opts[:max_results], @opts[:skip])

			if videos.length == 0
				info(STR_EMPTY)
			end

			fails += Parallel.map(videos) do |video|
				title = video.snippet.title
				id    = video.id.videoId

				result = youtube_in_mp3(title, id)	
				{title:title, id:id} if result != "Success"
			end
		end

=begin
Don't give up retry
=end
		fails.compact!
		while true 

			break if fails.length == 0

			puts ""
			print_error(STR_FAILED_SONGS)
			print_songs(fails)
			print STR_RETRY_DOWNLOAD+" "

			continue = gets.chomp.downcase
			while continue != "y" && continue != "n"
				print_error(STR_YOU_CAN_DO_IT)
				print STR_RETRY_DOWNLOAD+" "
				continue = gets.chomp.downcase
			end

			if continue == "y"
				videos = fails
				fails = Array.new

				fails += Parallel.map(videos) do |video|

					next if video.nil?

					title = video[:title]
					id    = video[:id]

					result = youtube_in_mp3(title, id)	
					{title:title, id:id} if result != "Success"
				end

				fails.compact!
			else
				break
			end

		end
	end
end

app = App.new
app.run
