source("./R/api/standalone_fii_api.R")

https://fiis.com.br/bcri/cotacoes/?periodo=ytd
periodo=ytd

# GET /bcri/cotacoes/?periodo=ytd HTTP/1.1
# Host: fiis.com.br
# User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:73.0) Gecko/20100101 Firefox/73.0
# Accept: application/json, text/plain, */*
#   Accept-Language: pt-BR,pt;q=0.8,en-US;q=0.5,en;q=0.3
# Accept-Encoding: gzip, deflate, br
# X-Requested-With: XMLHttpRequest
# X-CSRF-TOKEN: BUMnR5OPLxcrtjnDwmTxgW19Mo7D4ndOmuQKDQxm
# X-XSRF-TOKEN: eyJpdiI6IkVcLzc4UUNPTCs4eXlXbmhIQTFGOEZBPT0iLCJ2YWx1ZSI6Illxd3FucE55TWZ4MUg3bHV0UFdFd2grV3lCeTFpUTZaVW82alBJK1wvS1F2Rm1KTEE2Z2xGazlPSE9SbWlTcWNTIiwibWFjIjoiYWE2MmNhN2M1ZDIxYTExODg4NjQ1NWRhZDQ1MzMyOGZmNjViYmFkMTJkNGExMGE5ZGNkYWZmZjEwMTMxMDI3MyJ9
# Referer: https://fiis.com.br/bcri11/
#   Connection: keep-alive
# Cookie: __cfduid=df289124ab0af197a54817b97aac02c951572873699; _ga=GA1.3.698651980.1572873702; _fbp=fb.2.1583082156521.96884662; __gads=ID=6357971e7bdc6776:T=1583082155:S=ALNI_MYDpMfAa_fy4fdUXcwBYpSavg1QjQ; _hjid=8b61900e-48a0-48cc-999f-e75449848334; XSRF-TOKEN=eyJpdiI6IkVcLzc4UUNPTCs4eXlXbmhIQTFGOEZBPT0iLCJ2YWx1ZSI6Illxd3FucE55TWZ4MUg3bHV0UFdFd2grV3lCeTFpUTZaVW82alBJK1wvS1F2Rm1KTEE2Z2xGazlPSE9SbWlTcWNTIiwibWFjIjoiYWE2MmNhN2M1ZDIxYTExODg4NjQ1NWRhZDQ1MzMyOGZmNjViYmFkMTJkNGExMGE5ZGNkYWZmZjEwMTMxMDI3MyJ9; fiis_session=eyJpdiI6IiszY1paOHNYaW9xRkJnRWQreEh3T0E9PSIsInZhbHVlIjoiaWRLbytRNTB5WGdpbHVob0tScEZQb3E2VnlIaFhzaVpucndST0VzY21UWjBBUzA3UlJJOXhqZVwvSFNRXC9QdDlVIiwibWFjIjoiMzczYjJjYTY2ZGE1ZjUxNmExZTgyOTYzNDFkMjYwZTUyY2M2OGY1MWIwZTUyMjZlZWIxYTc2NGMxNTJlNTYyYiJ9; _gid=GA1.3.645042739.1583170658; _gat_UA-40534188-1=1; _gat_UA-85692343-5=1; _gat_UA-85692343-11=1; _hjIncludedInSample=1


fii_endpoint(
  .url = "https://fiis.com.br",
  .ticker = "abcp",
  .path = "cotacoes",
  .query = list("periodo"="max")
)

https://fiis.com.br/lupa-de-fiis/data/

{"filters":["0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"]}

list("filters"=as.character(0:15)) %>% 
  jsonlite::toJSON(auto_unbox = )


fiis_post(
  .url="https://fiis.com.br/lupa-de-fiis/data/",
  .body=list("filters"=as.character(0:15))
)



