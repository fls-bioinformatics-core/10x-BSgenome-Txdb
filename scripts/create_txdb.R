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
        if(param == "assembly") msg <- paste(msg, ', e.g. assembly="GRCh38.p13" or assembly="GRCh38" if GTF is sourced from Ensembl')
        if(param == "gtfFile") msg <- paste(msg, ', e.g. gtfFile="xxxxx..gtf.filtered"')
        if(param == "chromSize") msg <- paste(msg, ', e.g. chromSize="xxxxx.chrom.sizes"')
        stop(msg)
    }
}

create_txdb <- function(organism, assembly, gtfFile, chromSize) {
    gtf_vec <- strsplit(basename(gtfFile), "\\.")[[1]]

    # If using Gencode GTF
    if(gtf_vec[1] == "gencode") {
        gtf_source <- "Gencode"
        gtf_version <- gtf_vec[2]
    } else {
        # To store the index of the genome in the vector
        idx <- NULL

        # If using Ensembl GTF, find and use "genome" in place of assembly
        # e.g. Homo_sapiens.GRCh38.115.chr.gtf.gz
        idx <- match(assembly, gtf_vec)
	if(is.null(idx)) stop("Unrecognised GTF source. Currently supports Gencode and Ensembl.")

        # Check if value in the next index is a number (as in Ensembl GTF)
        if(grepl("^[[:digit:]]+", gtf_vec[idx+1])) {
            gtf_source <- "Ensembl"
            gtf_version <- gtf_vec[idx+1]
        } else {
            stop("Unrecognised Ensembl version.")
        }
    }

    chrominfo <- read.table(chromSize, , col.names = c("chrom","length"))
    chrominfo$is_circular <- FALSE
    chrominfo$is_circular[chrominfo$chr %in% c("chrM","MT")] <- TRUE

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
    sqlitefile <- sprintf("%s.%s.%s.%s.txdb.sqlite", name, assembly, gtf_source, gtf_version)
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
