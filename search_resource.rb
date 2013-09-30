require 'slim'
require 'cgi'
require 'faraday'
require 'json'
require 'titleize'

PER_PAGE = 10
TOTAL_PAGES = 10
Search = Struct.new(:query, :project, :links, :current_page, :total_pages, :total_results, :choices)

class SearchResource < Webmachine::Resource

  def choices
    {
      'Documentation' => [
        ['', 'All Docs'],
        ['riak','Riak'],
        ['riakcs','Riak CS'],
        ['riakee','Riak Enterprise']
      ]
    }
  end

  def to_html
    params = CGI::parse(request.uri.query.to_s) || {}
    query = params['q'].first.to_s.gsub(/[,\:]/,' ').strip
    project = params['p'].first.to_s.strip
    project = nil if project == '' || !%w{riak riakee riakcs}.include?(project)
    current_page = params['page'].first.to_i
    current_page = 1 if current_page < 1
    
    total_pages = 1
    links = []
    if query != ''

      # If there's a forward slash, quote it
      if query.scan("/").length > 0
        query = "\"#{query.gsub(/(^\")|(\")$/, '')}\""
      end

      # base_url = 'http://ec2-54-242-92-147.compute-1.amazonaws.com:8098'
      base_url = 'http://208.118.230.104:8098'
      # base_url = "http://localhost:10018"
      docs_url = 'http://docs.basho.com/'

      conn = Faraday.new(:url => base_url) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        # faraday.response :logger                # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      start = (current_page - 1) * PER_PAGE

      language = 'en'
      body_field = "body_#{language}"

      q = ''
      unless project.nil?
        q = "project_s:#{project} AND "
      end
      q += query.split(/ /).map{|x| x}.join(' AND ')
      # q += "text_en:#{query}"

      response = conn.get '/search/docs', {
        wt: 'json',
        q: q,
        df: body_field,
        sort: 'score desc',
        omitHeader: true,
        hl: 'true',
        start: start,
        rows: PER_PAGE,
        defType: 'edismax',
        :'hl.fl' => body_field,
        fl: '_yz_id,_yz_rk,project_s,title_s,path_s,audience_s,score'
      }

      reply = JSON.parse(response.body)

      highlights = reply['highlighting'] || {}
      docs = reply['response']['docs'] || {}
      total = reply['response']['numFound'].to_i
      total_pages = (total / PER_PAGE).to_i + 1

      count = 0
      docs.each do |doc|
        id = doc['_yz_id']
        hl = highlights[id]
        proj = doc['project_s']
        title = doc['title_s']
        link = docs_url + doc['path_s']
        text = (hl[body_field] || []).first.to_s
        text.gsub!(/(\<[^>]+?\>)/) do
          (tag = $1) =~ /(\<\/?em\>)/ ? $1 : ''
        end
        links << {
          text: text,
          link: link,
          title: title,
          project: proj
        }
        count +=1
      end
    end

    search = Search.new(query, project, links, current_page, total_pages, total, choices)
    Slim::Template.new('search.slim', {}).render(search)
  end
end
