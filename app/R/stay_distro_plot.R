#' Function to plot discretised duration distribution
#'
#' This function provides custom plots for the output of `distcrete`.
#'
#' @param distribution a length of stay distribution of class `distcrete`
#' @param main a string to be added to the resulting plot as a title
#' @param type 1-character string giving the type of plot desired. See \code{\link[graphics]{plot}}
#' @param col The colors for lines and points.
#' @param lwd a vector of line widths, see \code{\link{par}}
#' @param lend The line end style.
#' @param xlab string of text for x axis label
#' @param ylab string of text for y axis label
#' @param cex.lab expansion factor for labels
#' @param cex.main expansion factor for main title
#' 
#' @author Carl AB Pearson
#' 

stay_distro_plot <- function(
    distribution, main,
    type = "h", col = "black",
    lwd = 14, lend = 2,
    xlab = "Days in hospital", ylab = "Probability",
    cex.lab = 1.3, cex.main = 1.5
) {
    days <- 0:max(1, distribution$q(.999))
    plot(
        days, distribution$d(days),
        main = main,
        type = type, col = col,
        lwd = lwd, lend = lend,
        xlab = xlab, ylab = ylab,
        cex.lab = cex.lab, cex.main = cex.main
    )
}