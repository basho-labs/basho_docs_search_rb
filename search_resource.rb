require 'slim'
require 'cgi'
require 'faraday'
require 'json'
require 'titleize'

PER_PAGE = 10
TOTAL_PAGES = 10
Search = Struct.new(:query, :links, :current_page, :total_pages, :total_results)

class SearchResource < Webmachine::Resource

  def to_html
    params = CGI::parse(request.uri.query.to_s) || {}
    query = params['q'].first.to_s.strip
    current_page = params['page'].first.to_i
    current_page = 1 if current_page < 1
    
    total_pages = 1
    links = []
    if query != ''

      base_url = 'http://ec2-54-242-92-147.compute-1.amazonaws.com:8098'
      docs_url = 'http://docs.basho.com'

      conn = Faraday.new(:url => base_url) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        # faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      start = (current_page - 1) * PER_PAGE

      response = conn.get '/search/riakdoc2', {
        wt: 'json',
        q: "text_t:#{query}",
        omitHeader: 'true',
        hl: 'true',
        start: start,
        rows: PER_PAGE,
        :'hl.fl' => 'text_t',
        fl: 'id,_yz_rk,score'
      }

      reply = JSON.parse(response.body)

      highlights = reply['highlighting'] || {}
      docs = reply['response']['docs'] || {}
      total = reply['response']['numFound'].to_i
      total_pages = (total / PER_PAGE).to_i + 1

      count = 0
      docs.each do |doc|
        id = doc['id']
        hl = highlights[id]
        key = doc['_yz_rk']
        title = key.sub(/(\/)$/, '').scan(/[^\/]+$/).first.to_s.gsub(/[\-]/, ' ').titleize
        link = docs_url + key
        text = (hl['text_t'] || []).first
        text.gsub!(/(\<[^>]+?\>)/) do
          (tag = $1) =~ /(\<\/?em\>)/ ? $1 : ''
        end
        links << {
          text: text,
          link: link,
          title: title
        }
        count +=1
      end
    end

    search = Search.new(query, links, current_page, total_pages, total)
    Slim::Template.new('search.slim', {}).render(search)
  end
end
