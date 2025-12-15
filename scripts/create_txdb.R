#

check_param <- function(args, param) {
    if(sum(grepl(paste0(param, "="), args)) == 1) {
        x <- strsplit(args[grep(paste0(param, "="), args)] , "=")
        k <- x[[1]][1]
	v <- x[[1]][2]
	#message(sprintf("%s: %s", k, v))
	return(setNames(as.list(v), k))
    } else {
        msg <- paste0('Use to ', param, '"=" to give an input')
        if(param == "organism") msg <- paste(msg, ', e.g. organism="Homo sapiens"')
        if(param == "assembly") msg <- paste(msg, ', e.g. assembly="GRCh38.p13,"')
        if(param == "gtfFile") msg <- paste(msg, ', e.g. gtfFile="xxxxx..gtf.filtered"')
        if(param == "chromSize") msg <- paste(msg, ', e.g. chromSize="xxxxx.chrom.sizes"')
        stop(msg)
    }
}

create_txdb <- function(organism, assembly, gtfFile, chromSize) {
    gtf_list <- strsplit(basename(gtfFile), "\\.")
    gencode_ver <- if(gtf_list[[1]][1] == "gencode") gtf_list[[1]][2] else NA
    if(is.na(gencode_ver)) stop("Unrecognised Gencode GTF version.")

    chrominfo <- read.table(chromSize, , col.names = c("chrom","length"))
    chrominfo$is_circular <- FALSE
    chrominfo$is_circular[chrominfo$chr == "chrM"] <- TRUE

    message(paste0("\nMaking TxDb from \"", gtfFile, "\""))
    txdb <- txdbmaker::makeTxDbFromGFF(file = gtfFile, 
				       format = "gtf",
				       dataSource = gtfFile, 
				       organism = organism, 
				       chrominfo = chrominfo, 
				       metadata = data.frame(name = "Genome", value = assembly))
    if(organism == "Homo sapiens") {
        name <- "Human"
    } else if(organism == "Mus musculus") {
        name <- "Mouse"
    } else {
        name <- sub(" ", "_", organism)
    }
    sqlitefile <- sprintf("%s.%s.Gencode.%s.txdb.sqlite", name, assembly, gencode_ver)
    message(paste0("\nSaving TxDb to \"", sqlitefile, "\""))
    AnnotationDbi::saveDb(txdb, file = sqlitefile)

    message(paste0("\n* To load the TxDb object, run `txdb <- AnnotationDbi::loadDb(\"", sqlitefile, "\")` in R.\n"))
}

args <- commandArgs()

params <- c(check_param(args, "organism"),
            check_param(args, "assembly"),
            check_param(args, "gtfFile"),
            check_param(args, "chromSize"))

create_txdb(params[["organism"]], params[["assembly"]], params[["gtfFile"]], params[["chromSize"]])
