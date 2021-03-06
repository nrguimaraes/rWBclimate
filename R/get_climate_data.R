#' get_climate_data
#'
#'@description Download monthly average climate data from the world bank climate 
#'             data api. Ideally you'll want to use the wrapper functions that call this.
#' 
#' @import httr plyr jsonlite reshape2
#' @param locator The ISO3 country code that you want data about. (http://unstats.un.org/unsd/methods/m49/m49alpha.htm) or the basin ID [1-468]
#' @param geo_type basin or country depending on the locator type
#' @param type the type of data you want "mavg" for monthly averages, "annualavg"
#' @param cvar The variable you're interested in. "pr" for precipitation, "tas" for temperature in celcius.
#' @param start The starting year you want data for, can be in the past or the future. Must conform to the periods outlined in the world bank API.  If given values don't conform to dates, the fuction will automatically round them.
#' @param end The ending year you want data for, can be in the past or the future.  Similar to the start date, dates will be rounded to the nearest end dat.  
#' 

get_climate_data <- function(locator,geo_type,type, cvar, start, end){
  base_url <- "http://climatedataapi.worldbank.org/climateweb/rest/v1/"
  
  ### Error handling
  if(geo_type == "country"){
    check_ISO_code(locator)
  }
  
  if(geo_type == "basin"){
    if(is.na(as.numeric(locator))){
      stop("You must enter a valid Basin number between 1 and 468")
    }
    if(as.numeric(locator) < 1 || as.numeric(locator) > 468){
      as.numeric(locator) < 1 || as.numeric(locator) > 468
    }
    
    
  }
  
  data_url <- paste(geo_type,type,cvar,start,end,locator,sep="/")
  
#  print(data_url)
  
  extension <- ".json"
  full_url <- paste(base_url,data_url,extension,sep="")
  
#  print(full_url)

    res <- GET(full_url)
  stop_for_status(res)
  raw_data <- try(content(res, as = "text"), silent = TRUE)
  if(sum(grep("unexpected",raw_data)) > 0){
    stop(paste("You entered a country for which there is no data. ",locator," is not a country with any data"))
  }
  
  data_out <- jsonlite::fromJSON(raw_data)
  if( type == "mavg" && start < 2010){
    ### Unpack the lists
    tmp <- data.frame(sapply(data_out$monthV,unlist))
    colnames(tmp) <- data_out$gcm
    tmp$fromYear <- rep(start,12)
    tmp$toYear <- rep(end,12)
    data_out <- melt(tmp,id.vars =c("fromYear","toYear"), variable.name = "gcm", value.name = "data")
    data_out$month  <- rep(1:12,dim(data_out)[1]/12)
  }
  
  if(type == "mavg" && start > 2010){
    do_list <- list()
    for( i in 1:length(unique(data_out$scenario))){
      ### Unpack the lists
      split_do <- subset(data_out,data_out$scenario == unique(data_out$scenario)[i])  
      tmp <- data.frame(sapply(split_do$monthV,unlist))
      colnames(tmp) <- split_do$gcm
      tmp$fromYear <- rep(start,12)
      tmp$toYear <- rep(end,12)
      do_list[[i]] <- melt(tmp,id.vars =c("fromYear","toYear"), variable.name = c("gcm"), value.name = "data")
      do_list[[i]]$scenario <- rep(split_do$scenario[1],dim(do_list[[i]])[1])
      do_list[[i]]$month  <- rep(1:12,dim(do_list[[i]])[1]/12)
    } 
    data_out <- do.call(rbind,do_list)  
  }
  
  
  if(start < 2010){
    tmp_names <- c("scenario",colnames(data_out))
    data_out <- cbind(rep("past",dim(data_out)[1]),data_out)
    colnames(data_out)<- tmp_names
    
  }
  
  data_out$locator <- rep(locator,dim(data_out)[1])
  
  return(data_out)
}

