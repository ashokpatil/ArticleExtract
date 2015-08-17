# encoding: UTF-8
require 'rubygems'
require 'httparty'
require 'pp'
require 'FileUtils'
require 'json'
require 'nokogiri'
require 'crack'
require 'uri'
require 'desk_api'

#brew is installed as a part of dev env setup
#brew install ruby
# with the latest ruby, the below would suffice
#gem install httparty, json, nokogiri, crack

# CLI to pull the forums

#ruby pull-zendesk-forum.rb

login = "ashok@paxata.com"
password = "Guessme24"

infile = "/Users/ashokpatil/Downloads/June30"



class Zenuser
  include HTTParty
  headers 'content-type'  => 'application/json'
  def initialize(u, p)
      @auth = {:username => u, :password => p}
      self.class.base_uri 'https://paxata.zendesk.com'
    end
  def get_entries(nextPageURL)
    options = {:basic_auth => @auth}
    self.class.get(nextPageURL.to_s, options)
  end
  def get_name(articleName, rdir)

    dir = rdir + "/" + articleName + "/"

     FileUtils.mkdir_p(dir) unless File.exists?(dir)

         return articleName
  end   


def get_attachments(article_id,attach_dir,subtype, rootDir)
    attachmentsPath = '/api/v2/help_center/articles/' + article_id.to_s + '/attachments/' + subtype + '.json'
    options = {:basic_auth => @auth}
    
    
          attachments=  self.class.get(attachmentsPath, options)
          attachmentsBody = JSON.parse(attachments.body)
          imageDir = attach_dir
          
          
         if !attachmentsBody['article_attachments'].nil?
          attachmentsBody['article_attachments'].each do |attachment|

            File.open(rootDir + '/ImageExtractsCmd.txt', 'a') { |f| f.puts 'curl ' + attachment['content_url'] + ' -v -u ashok@paxata.com:Guessme24 > ' + rootDir+'/hc/en-us/articles/'+ attachment['article_id'].to_s + '/' + attachment['id'].to_s + attachment['file_name'].gsub(/(paxata)/i, '@CiscoImage@')  }
 
            end # end of attachment bidy


          end # end of attachment If

end # end of def

def checkIfApplicable(sectionID)
  # The below  2 categories are for APplication Feattures and Starting with Paxata categories
    validCategoryIDs = '200079158 , 200079238'
    urlPath = '/api/v2/help_center/sections/' + sectionID.to_s + '.json'
     options = {:basic_auth => @auth}
    
    
          section=  self.class.get(urlPath, options)
          sectionBody = JSON.parse(section.body)
          categoryID = sectionBody["section"]["category_id"].to_s
          return validCategoryIDs.include?categoryID
          

         
           #puts "********************* category found " + categoryID.include? (sectionBody['section']).['category_id'] 
          # return false 
          # ( categoryID.include? sectionBody['section']['category_id'] )
  end
            


def get_content(rootDir,contentType)
      nextPageURL = '/api/v2/help_center/' + contentType + '.json' 
      while nextPageURL != nil do
          test = get_entries(nextPageURL)
          testBody = JSON.parse(test.body)
          testBody[contentType].each do |article|

            outdated = article['outdated'] != nil ? article['outdated'] : false
            draft = article['draft'] != nil ? article['draft'] : false

            applicableSection = checkIfApplicable(article['section_id'])

            if ( !applicableSection) 
              puts "--------++++++++++++****************Found includevalid Section  article ignoring ...." + article['section_id'].to_s

            end

            if(!outdated and !draft and applicableSection)

             subdirName= URI(article['html_url']).path
             articleDir = rootDir + "/" + subdirName + "/"
             print "********Creating articleDir *************************\n" + articleDir + "\n"
             FileUtils.mkdir_p(articleDir) unless File.exists?(articleDir)
                        
             get_attachments(article['id'], articleDir, "inline", rootDir)
           
              articleTargetBody = Nokogiri::HTML(article['body'],nil,'utf-8')

              htmltag = articleTargetBody.css('html')
              if (  htmltag.children.first != nil )
                head = articleTargetBody.create_element('head')
                head['charset'] = 'utf-8'
                head.content = ' '
              
                htmltag.children.first.add_previous_sibling(head)
              end
              
              articleTargetBody.css('img').each do |img|  
               if  ((img['src'].split('/').last =~ /^small/ ) != 0 ) 
                     img['width'] = '100%' 
                  end        
                  srcNameArray = img['src'].split('/')
                  img['src'] = (srcNameArray[srcNameArray.size - 2].to_s + srcNameArray[srcNameArray.size - 1] ).gsub(/(paxata)/i, '@CiscoImage@') 
                                   
                  
              end

              bodyTag = articleTargetBody.at('body')

              tableTag = articleTargetBody.create_element('table')
              row1Tag = articleTargetBody.create_element('tr')
              row1Tag.inner_html = '<H1> ' + article['title'] + ' </H1>'
              row2Tag = articleTargetBody.create_element('tr')
              col1Tag = articleTargetBody.create_element('td')
              col2Tag = articleTargetBody.create_element('td')
              col2Tag['width'] = '25%'
              col3Tag = articleTargetBody.create_element('td')
              col3Tag['width'] = '25%'
              col1Tag.children = bodyTag.children
              bodyTag.inner_html = ' '
              tableTag.parent = bodyTag
              row1Tag.parent=tableTag
              row1Tag.add_next_sibling(row2Tag)
              col1Tag.parent = row2Tag
              col1Tag.add_next_sibling(col2Tag)
              col2Tag.add_next_sibling(col3Tag)




              #bodyTag.content = '<table> <tr> <td> ' + bodyTag.content + '</td>  <td width=\'25%\'> <td width=\'25%\'> </tr> </table> '

                  
              


              articleTargetBody.css("a").each do |link|
                if (link.attributes["href"] != nil) 
                    puts "---------Link attribute " +  link.attributes["href"].value
                    hrefString = link.attributes["href"].value
                    lastStr = hrefString
                    if( hrefString.include?"/hc/en-us/" )
                    
                        if( hrefString.include?"servicedesk.paxata.com" )
                            dataMatchHref =  /(?<removeStr>(http[s]*:\/\/[a-z.]*.com))		(?<articleNumber>([0-9]*))/.match(hrefString)
                           lastStr = dataMatchHref[2] +  dataMatchHref[3]
                         elsif ( hrefString.start_with?"/hc/en-us/" )
                            dataMatchHref =  /(?<keep>([a-z\-\/]*))(?<articleNumber>([0-9]*))/.match(hrefString)
                            lastStr = dataMatchHref[1] +  dataMatchHref[2]

                         end
                  
                    elsif ( hrefString.include?"mailto:" or hrefString.include? "servicedesk.paxata.com"  ) 
                         File.open(rootDir + '/serviceDeskHrefLink.txt', 'a') { |f| f.puts 'replacing ' + link.attributes["href"].value + ' with @serviceDeskHrefLink@'  }
                        dataMatchmailTo = "@serviceDeskHrefLink@"
                        lastStr = dataMatchmailTo

                    elsif( hrefString.include? "paxata.com/"  )
                      File.open(rootDir + '/companyHrefLink.txt', 'a') { |f| f.puts 'replacing ' + link.attributes["href"].value + ' with @companyHrefLink@'  }
                        
                       lastStr = "@companyHrefLink@"
                    end
                
                    puts "=========Replacing href " + link.attributes["href"].value + " with " + lastStr
                    link.attributes["href"].value = lastStr
                end
              end
              File.open(articleDir  + "index.html", 'w+') do |the_file|
                puts "****** Writing file ******* " + articleDir  + "index.html"
                articleString = articleTargetBody.to_xhtml.gsub(/(servicedesk@paxata.com)/i, '@serviceDeskContactContent@')

                the_file.puts articleString.gsub(/(paxata)/i, '@productFullName@')
               end
             end
            end
          nextPageURL = testBody['next_page']
        end
    end






end # end of class


   
x = Zenuser.new(login, password)

rootDir = infile

x.get_content( rootDir, 'articles')

puts "Done with extracting Articles"
