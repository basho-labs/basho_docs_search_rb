require 'slim'
require 'cgi'
require 'faraday'
require 'json'

Search = Struct.new(:query, :links)

class SearchResource < Webmachine::Resource
  # def allowed_methods
  #   %W[GET HEAD POST]
  # end

  # def content_types_provided
  #   # [ [ 'application/json;version="1.0"', :to_json ] ]
  #   [ [ 'text/html;version="1.0"', :to_html ] ]
  # end

  # def encodings_provided
  #   { "gzip" => :encode_gzip, "identity" => :encode_identity }
  # end

  # def post_is_create?
  #   true
  # end

  # def create_path
  #   response.body = to_html
  #   # '/path-to-resource'
  #   '/'
  # end

  # def process_post
  #   # raise 'der'
  #   # to_html
  #   true
  # end

  # def last_modified
  #   File.mtime(__FILE__)
  # end

  # def last_modified
  #   @page.updated_at
  # end

  # def generate_etag
  #   @page.robject.etag
  # end

  def to_html
    params = CGI::parse(request.uri.query.to_s) || {}
    query = params['q'].first.to_s.strip
    
    links = []
    if query != ''

      # http://ec2-54-242-92-147.compute-1.amazonaws.com:8098/search/riakdoc2?wt=json&q=text_t:search&omitHeader=true&hl=true&hl.fl=text_t&fl=_yz_rk,score
      conn = Faraday.new(:url => 'http://ec2-54-242-92-147.compute-1.amazonaws.com:8098') do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        # faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      
      # ?wt=json&q=text_t:search&omitHeader=true&hl=true&hl.fl=text_t&fl=_yz_rk,score
      response = conn.get '/search/riakdoc2', {
        wt: 'json',
        q: "text_t:#{query}",
        omitHeader: 'true',
        hl: 'true',
        :'hl.fl' => 'text_t',
        fl: '_yz_rk,score'
      }
      
      reply = JSON.parse(response.body)

      highlights = reply['highlighting'] || {}
      links = highlights.map do |key, hl|
        (hl['text_t'] || []).first
      end
    end

    search = Search.new(query, links)
    Slim::Template.new('search.slim', {}).render(search)
  end
end
