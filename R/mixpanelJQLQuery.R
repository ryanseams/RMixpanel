mixpanelJQLQuery <- function(
  account,      # Mixpanel account.
  jqlString,    # JQL script as string.
  jqlScripts,   # List of JQL script file names.
  paths=".",    # Paths to search JS files.
  columnNames,  # Column names for the resulting data.frame.
  toNumeric=c() # Column indices which should be converted to numeric.
) {
  ## Write all JQL code into 1 script file.
  filePath = paste("temp_", uuid::UUIDgenerate(), ".js", sep="")
  on.exit( { unlink(filePath) } )
  
  append <- FALSE
  if(!missing(jqlString)) {
    cat(jqlString, file=filePath, append=append)
    append <- TRUE
  }
  
  if(!missing(jqlScripts)) {
    for(i in 1:length(jqlScripts))
      for(path in paths) {
        fn <- file.path(path, jqlScripts[i])
        if(file.exists((fn)))
          cat(readLines(fn), file=filePath, append=append)
        append <- TRUE
      }
  }
  
  ## Perform query by CURL.
  curlCall <- paste0("curl https://mixpanel.com/api/2.0/jql ",
                     "-u ", account$apiSecret, ": ",
                     "--data-urlencode script@", filePath)
  
  ## Results could be truncated.
  options(warn=-1)
  results <- system(curlCall, intern=TRUE, ignore.stderr=TRUE)
  options(warn=0)
  jsonRes <- paste(results, collapse="")
  
  ## Parse to data.frame.
  rawRes <- jsonlite::fromJSON(jsonRes)
  
  ## Error Handling.
  if("error" %in% names(rawRes))
    stop(paste0("\nJQL query stopped. Message:\n", rawRes$error))    
  if(length(rawRes) == 0)
    return(as.data.frame(rawRes))
  
  res <- c()
  for(i in 1:length(rawRes)) {
    ri <- rawRes[[i]]
    if (class(ri) == "data.frame") {
      if(length(res))
        res <- cbind(res, ri) 
      else
        res <- ri
    } else {
      x <- unlist(ri)
      res <- cbind(res, matrix(x, length(ri), byrow=TRUE))
    }
  }

  res <- as.data.frame(res, stringsAsFactors=FALSE)
  if(!missing(columnNames))
    colnames(res) <- columnNames
  
  if (length(toNumeric) && toNumeric[1] < 0)
    toNumeric <- (1:ncol(res))[toNumeric]
  for(i in toNumeric)
    res[, i] <- as.numeric(res[, i])
  res
}
