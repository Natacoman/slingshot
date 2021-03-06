#' @rdname slingBranchID
#'
#' @description Extracts lineage assignments from \code{slingshot} results. This
#'   produces a categorical variable indicating which lineage (or combination of
#'   lineages) each cell is assigned to.
#' @param x an object containing \code{slingshot} output, generally either a
#'   \code{\link{SlingshotDataSet}} or \code{\link{SingleCellExperiment}}.
#' @param thresh weight threshold for assigning cells to lineages. A cell's
#'   weight on a certain lineage must be greater than this value (default =
#'   \code{1/L}, for \code{L} lineages).
#' @return a factor variable that assigns each cell to a particular lineage or
#'   set of lineages.
#'
#' @examples
#' data("slingshotExample")
#' rd <- slingshotExample$rd
#' cl <- slingshotExample$cl
#' sds <- slingshot(rd, cl)
#' slingBranchID(sds)
#' 
#' @export
setMethod(f = "slingBranchID",
          signature = signature(x = "ANY"),
          definition = function(x, thresh = NULL){
              L <- length(slingLineages(x))
              if(is.null(thresh)){
                  thresh <- 1/L
              }else{
                  if(thresh < 0 | thresh > 1){
                      stop("'thresh' value must be between 0 and 1.")
                  }
              }
              return(factor(apply(slingCurveWeights(x) > thresh, 1, 
                                  function(bin){
                                      paste(which(bin), collapse = ',')
                                  })))
          })

#' @rdname slingBranchGraph
#'
#' @description Builds a graph describing the relationships between the
#'   different branch assignments
#' @param x an object containing \code{slingshot} output, generally either a
#'   \code{\link{SlingshotDataSet}} or \code{\link{SingleCellExperiment}}.
#' @param thresh weight threshold for assigning cells to lineages. A cell's
#'   weight on a certain lineage must be greater than this value (default =
#'   \code{1/L}, for \code{L} lineages).
#' @param max_node_size the \code{size} of the largest node in the graph, for
#'   plotting (all others will be drawn proportionally). See
#'   \code{\link{igraph.plotting}} for more details.
#' @return an \code{igraph} object representing the relationships between
#'   lineages.
#'   
#' @examples
#' data("slingshotExample")
#' rd <- slingshotExample$rd
#' cl <- slingshotExample$cl
#' sds <- slingshot(rd, cl)
#' slingBranchGraph(sds)
#'   
#' @importFrom igraph graph_from_literal graph_from_edgelist
#'   graph_from_adjacency_matrix vertex_attr vertex_attr<-
#' @export
setMethod(f = "slingBranchGraph",
          signature = signature(x = "ANY"),
          definition = function(x, thresh = NULL, max_node_size = 100){
              brID <- slingBranchID(x, thresh = thresh)
              nodes <- as.character(levels(brID))
              which.lin <- strsplit(nodes, split='[,]')
              nlins <- vapply(which.lin, length, 0)
              maxL <- max(nlins)
              if(maxL == 1){ # only one lineage
                  g <- graph_from_literal(1)
                  vertex_attr(g, 'cells') <- length(brID)
                  vertex_attr(g, 'size') <- max_node_size
                  return(g)
              }
              if(length(nodes)==1){ # only one node, possibly multiple lineages
                  m <- matrix(0, dimnames = list(nodes[1], nodes[1]))
                  g <- graph_from_adjacency_matrix(m)
                  vertex_attr(g, 'cells') <- length(brID)
                  vertex_attr(g, 'size') <- max_node_size
                  return(g)
              }
              
              el <- NULL
              # for each node n at level l
              for(l in seq(2,maxL)){
                  for(n in nodes[nlins==l]){
                      # find all descendants of n
                      desc <- .under(n, nodes)
                      for(d in desc){
                          if(l - nlins[which(nodes==d)] >= 2){
                              # check for intermediates
                              granddesc <- unique(unlist(lapply(desc, .under, 
                                                                nodes)))
                              if(! d %in% granddesc){
                                  # add edge
                                  el <- rbind(el, c(n, d))
                              }
                          }else{
                              # add edge
                              el <- rbind(el, c(n, d))
                          }
                      }
                  }
              }
              g <- igraph::graph_from_edgelist(el)
              vertex_attr(g, 'cells') <- table(brID)[
                  igraph::vertex_attr(g)$name]
              vertex_attr(g, 'size') <- max_node_size * vertex_attr(g)$cells / 
                  max(vertex_attr(g)$cells)
              return(g)
          })






