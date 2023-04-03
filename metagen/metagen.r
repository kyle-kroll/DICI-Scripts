#!/usr/bin/env Rscript
# Check to make sure packages are loaded
package <- "optparse"
if (!package%in%installed.packages()) {
  
  # Install it
  install.packages(
    package,
    dependencies = TRUE,
    repos = "https://cloud.r-project.org"
  )
  
}
# Preparation of arguments ----
# Define the exit function ----
exit <- function() { invokeRestart("abort") } 
library(optparse)
option_list = list(
  make_option(c("-g", "--generate"), action="store_true", default=FALSE,
              help="Generate template config.yml file."),
  make_option(c("-m", "--move"), action = 'store', type='character', default=NULL,
              help="Copies specified filetype to a data folder.\n\t\tNOTE this does NOT remove the original files")
)

opt_parser = OptionParser(option_list=option_list)
opt = parse_args(opt_parser)

if(isTRUE(opt$generate)) {
  options("encoding" = "UTF-8")
  temp <- "#REQUIRED ITEMS\nschema: SampleID_CellType_CloneNumber\ninput: data\ndelim: '_'\nout: meta.csv\n#Optional items\noptional:\n  researcher: Name\n  platform: Platform\n  project: Project\n  species: Species\n  date: Date"
  write(temp, "config.yml")
  cat("Wrote config template to config.yml. Please edit and rerun script without the --generate flag.")
  exit()
}

if(!is.null(opt$move)) {
  dir.create("data")
  suppressMessages(file.copy(list.files(pattern = paste0("*.", opt$move)), to = "data"))
  cat(paste0("All *.", opt$move, " files have been moved to the folder data. Please --generate the config.yml and run the script."))
  exit()
}
library(yaml)
config <- yaml.load_file("config.yml")

if(is.null(config$input)) {
  stop("Please specify the input data directory within your configuration file.", call.=FALSE)
}

# Check if the config$input actually exists
if(!file.exists(config$input)) {
  stop(paste0("The input folder {", config$input, "} specified in config.yml does not exist. Please verify the folder is spelled correctly.", call.=FALSE))
}

# Define the filename parameters ----
file_columns <- strsplit(config$schema, config$delim)[[1]]

# List files in input directory ----
input_files <- list.files(config$input, recursive = T)
input_files <- input_files[!startsWith(input_files, "Compensation")]
if(length(input_files) == 0) {
  stop("No input files detected. Please check your config.yml for the correct folder and check the folder that it actually contains files.", call.=FALSE)
}
# Create an empty dataframe to hold all the information ----
meta <- data.frame(row.names = input_files, 
                   matrix(nrow = length(input_files), 
                          ncol=length(file_columns)+1))
colnames(meta) <- c(file_columns, "Extension")

# Populate the meta dataframe ----
for(i in 1:length(input_files)) {
  # First split file name based on period to get extension
  ext <- strsplit(input_files[i], "\\.")[[1]]
  # Now split the first element on delimiter to get each element of the file name
  info <- strsplit(ext, config$delim)[[1]]
  info[1] <- ifelse(grepl("/", info[1]), strsplit(info[1], "/")[[1]][length(strsplit(info[1], "/")[[1]])], info[1])
  row_info <- c(info[1:length(file_columns)], ext[2])
  meta[input_files[i],] <- row_info
  cat(paste0("File: ", i, " of ", length(input_files), " completed.\n"))
}

# Add in any additional information contained within config.yml
if("optional" %in% names(config)) {
  for(item in names(config$optional)) {
    meta[, item] <- config$optional[item]
  }
}

# Write to file ----
write.csv(meta, file = config$out)
