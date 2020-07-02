library(httr)
library(jsonlite)
library(purrr)

# Fantasy Football API Core GET
fiis_get <- function(.url, .ticker, .path, .query, .verbose=F){
  
  # always return json
  .query = append(.query, list("format"="json"))
  
  # build full url and invokes
  url <- modify_url(url=.url, path=paste(.ticker, .path, sep = "/"), query = .query)
  
  # user agent
  ua <- user_agent("fiiscrapeR")

  # logging activity  
  if(.verbose){
    print(url)
    print(str(.query))
  }
  
  # invoke
  resp <- GET(url,ua)
  
  # check formation type
  if (http_type(resp) != "application/json") {
    stop("API did not return json", call. = FALSE)
  }
  
  # parse
  parsed <- fromJSON(content(resp,"text"))  
  
  # error handling
  if (http_error(resp)) {
    cat("http error: ", status_code(resp), "\n")
    cat(str(parsed))
    stop(
      sprintf(
        "Fantasy API request failed [%s]\n%s\n<%s>", 
        status_code(resp),
        parsed$message,
        parsed$documentation_url
      ),
      call. = FALSE
    )
  }
  
  # S3 return object
  structure(
    list(
      content  = parsed, 
      path     = .path,
      response = resp,
      status   = status_code( resp ),
      success  = !http_error(resp)
    ),
    class = "fiis_api"
  )
  
}


# Fantasy Football API Core GET
fiis_post <- function(.url, .body, .verbose=F){
  
  # build full url and invokes
  url <- modify_url(url=.url)# , path=paste(.ticker, .path, sep = "/"), query = .query)
  body <- jsonlite::toJSON(.body)
  
  # user agent
  ua <- user_agent("fiiscrapeR")
  
  # logging activity  
  if(.verbose){
    print(url)
    print(str(.body))
  }
  
  # invoke
  resp <- POST(url,body = body, ua=ua, encode = "json")
  
  # check formation type
  if (http_type(resp) != "application/json") {
    stop("API did not return json", call. = FALSE)
  }
  
  # parse
  parsed <- fromJSON(content(resp,"text"))  
  
  # error handling
  if (http_error(resp)) {
    cat("http error: ", status_code(resp), "\n")
    cat(str(parsed))
    stop(
      sprintf(
        "Fantasy API request failed [%s]\n%s\n<%s>", 
        status_code(resp),
        parsed$message,
        parsed$documentation_url
      ),
      call. = FALSE
    )
  }
  
  # S3 return object
  structure(
    list(
      content  = parsed, 
      path     = .path,
      response = resp,
      status   = status_code( resp ),
      success  = !http_error(resp)
    ),
    class = "fiis_api"
  )
  
}
