require 'sinatra'
require 'nokogiri'

class Host
	attr_accessor :name, :results

	def initialize(name,directory)
		@name = name
		@directory = directory
		@results = Dir.glob(@directory+'/*.xml').map{|f| Result.new(f)}
	end

	def result_with_name(result_name)
		@results.select{|r| r.name == result_name}.first
	end
end

class Result

	attr_accessor :name

	def initialize(file_path)
	 	@file_path = file_path
	 	@name = File.basename(@file_path,'.xml')
	 	@doc = Nokogiri::XML(File.open(@file_path))
	 	@doc.remove_namespaces!
	end

	def hostname
		@doc.xpath '//primary_host_name[1]/text()'
	end

	def generation_timestamp
		@doc.xpath '/oval_results/generator/timestamp[1]/text()'
	end

	def results
		result_defs = {}
		@doc.xpath('/oval_results/results//definition').each do |result_definition|
			status = result_definition.attribute('result') == 'true'
			#next unless status
			id = result_definition.attribute('definition_id')
			result_defs[id] = {:status => status, :data => definition_with_id(id).first}
		end
		return result_defs
	end

	def definition_with_id(id)
		@doc.xpath("/oval_results/oval_definitions//definition[@id=\'#{id}\']").to_a.map do |defin| 
			{
				:id => defin.attribute('id'),
				:title => defin.xpath('metadata/title[1]/text()'),
				:description => defin.xpath('metadata/description[1]/text()'),
				:affected_product => defin.xpath('metadata/affected/product/text()'),
				:references => defin.xpath('metadata/reference').to_a.map do |reference|
					{
						:source => reference.attribute('source'),
						:id => reference.attribute('id'),
						:url => reference.attribute('ref_url')
					}
				end
			}
		end
    end
end

class Manager

	attr_accessor :hosts

	def initialize(report_root)
		@report_root = report_root
		@hosts = []
		host_dirs = Dir.glob(report_root+'/*/')

		host_dirs.each do |host_dir|
			host_name = File.basename(host_dir)
			@hosts << Host.new(host_name,host_dir)
		end
	end

	def host_with_name(name)
		@hosts.select{|host| host.name == name}.first
	end
end

manager = Manager.new('report_root')

get '/' do
  erb :index, :locals => {:hosts => manager.hosts}
end

get '/host/:name' do
  host = manager.host_with_name(params[:name])
  erb :host, :locals => {:host => host }
end

get '/result/:host_name/:result_name' do
  host = manager.host_with_name(params[:host_name])
  result = host.result_with_name(params[:result_name])
  erb :result, :locals => {:host => host, :result => result}
end