sub.GDROD = function(x, i, j, ... , drop = FALSE) {
	# x[rows, cols, bands, ...]
#	if (!require(sp))
#		stop("could not load package sp")
#	n.args = nargs()
	dots = list(...)
	if (!missing(drop))
		stop("don't supply drop: it needs to be FALSE anyway")
	d = dim(x)
	if (missing(i))
		rows = 1:d[1]
	else 
		rows = i
	if (missing(j))
		cols = 1:d[2]
	else
		cols = j
	if (length(dots) > 0) {
		# fish for an unnamed argument, and rename it bands
		m  = match(names(dots),  c(""))
		if (any(!is.na(m))) 
			names(dots)[m[1]] = "band"
	}
	# process common arguments:
	gdal.args = dots
	if (is.null(gdal.args$half.cell)) half.cell <- c(0.5,0.5)
	else {
		half.cell <- gdal.args$half.cell
		gdal.args$half.cell <- NULL
	}

	gdal.args$dataset = x
	gdal.args$band = dots$band # NULL if not given
	if (is.null(gdal.args$at))
		gdal.args$at = c(1, 1)
	if (is.null(gdal.args$region.dim))
		gdal.args$region.dim = c(max(rows) - gdal.args$at[1] + 1, 
			max(cols) - gdal.args$at[2] + 1)
	rows = rows - gdal.args$at[1] + 1
	cols = cols - gdal.args$at[2] + 1
	# further arguments to getRasterData:
	if (is.null(gdal.args$output.dim))
		gdal.args$output.dim = gdal.args$region.dim
	if (is.null(gdal.args$interleave))
		gdal.args$interleave = c(0, 0)
	if (is.null(gdal.args$as.is))
		gdal.args$as.is = FALSE
	
	# retrieve topology:
	gt = .Call('RGDAL_GetGeoTransform', x, PACKAGE="rgdal")
	# [1] 178400     40      0 334000      0    -40
	p4s <- .Call("RGDAL_GetProjectionRef", x, PACKAGE="rgdal")
	if (nchar(p4s) == 0) p4s <- as.character(NA)

	# retrieve data:
	if (any(gt[c(3,5)] != 0)) {
		warning("grid has an orientation which is not suitable for sp grids; returning points...")
		data = do.call(getRasterTable, gdal.args)
		coordinates(data) = c(1,2)
	} else {
		data = do.call(getRasterData, gdal.args)
		# subset data:
		d = dim(data) # rows=nx, cols=ny
		if (length(d) == 3) {
			if (!is.null(gdal.args$band))
				band = gdal.args$band
			else
				band = 1:d[3]
			data = data[cols,rows,band]
		} else
			data = data[cols,rows]
		cellsize = abs(c(gt[2] * (1 + gdal.args$interleave[2]),
				gt[6] * (1 + gdal.args$interleave[1])))
		d = dim(data) # rows=nx, cols=ny
		cells.dim = c(d[1], d[2]) # c(d[2],d[1])
		ysign <- sign(gt[6])
		co.x <- gt[1] + (gdal.args$at[2] - 1 + half.cell[2]) *
			 cellsize[1]
		co.y <- ifelse(ysign < 0, gt[4] + (ysign*((
			gdal.args$region.dim[1] + 
			gdal.args$at[1] - 1) + (ysign*half.cell[1]))) * 
			abs(cellsize[2]), gt[4] + (ysign*(
			(gdal.args$at[1] - 1) + (ysign*half.cell[1]))) * 
			abs(cellsize[2]))
		cellcentre.offset <- c(x=co.x, y=co.y)
		grid = GridTopology(cellcentre.offset, cellsize, cells.dim)
		if (length(d) == 2)
			df = data.frame(band1 = as.vector(data))
		else {
			df = as.vector(data[,,1])
			for (band in 2:d[3])
				df = cbind(df, as.vector(data[,,band]))
			df = as.data.frame(df)
			names(df) = paste("band", 1:d[3], sep="")
		}
		data = SpatialGridDataFrame(grid, df, proj4string=CRS(p4s))
	}
	return(data)
}
setMethod("[", "GDALDataset", sub.GDROD)
