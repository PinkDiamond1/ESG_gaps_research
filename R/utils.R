# library(ggmosaic)
# library(ggiraph)
# library(ggtext)
# library(extrafont)

source("R/report.R")

nf <- function(n) {
  prettyNum(n, big.mark = ',')
}
plot_mosaic <- function(df,
                        explanation = "explanation A",
                        fill_colors = c("#cf455c", "#444444"),
                        alpha = .7) {
  # my_title <- paste0("Data gaps due to ", explanation)
  # my_subtitle <- paste0('<b style="color:#cf455c">Red areas</b> show the proportion of excluded indicators')

  p <- ggplot(data = df) +
    ggmosaic::geom_mosaic(aes(x = ggmosaic::product(sector), fill = factor(status), na.rm = TRUE), alpha = alpha) +
    labs(#title = my_title,
         #subtitle = my_subtitle,
         x = "",
         y = "") +
    scale_y_continuous(labels = scales::percent) +
    scale_fill_manual(values = fill_colors) +
    ggthemes::theme_hc() +
    theme(
      axis.ticks.x = element_blank(),
      legend.position = "none",
      text = element_text(family = "Calibri")
    )

  labels <- ggplot_build(p)$data[[1]] %>%
    group_by(x1__sector) %>%
    mutate(
      percent = paste0(round(.wt / sum(.wt) * 100, 1), "%")
    ) %>%
    ungroup()

  p <- p + geom_text(data = labels,
                     aes(x = (xmin + xmax) / 2,
                         y = (ymin + ymax) / 2,
                         label = percent))

  return(p)
}

# Custom palettes
my_palette2 <- c("#29115AFF", "#F4685CFF")
my_palette3 <- c("#56147DFF", "#C03A76FF", "#FD9A6AFF")


# generating new theme

theme_esg <- function(base_size = 12,
                      base_family = "Calibri",
                      base_line_size = base_size / 22,
                      base_rect_size = base_size / 22){
  theme_minimal(base_size = base_size,
                base_family = base_family,
                base_line_size = base_line_size) %+replace%
    theme(
      legend.position = "bottom",
      #legend.position = "none",
      complete = TRUE
    )
}

add_and <- function(x) {
  if (!(is.character(x))) {
    warning("`x` must be character. coercing to character")
    x <- as.character(x)
  }

  lx <- length(x)
  if (lx == 1) {
    y <- x
  }
  else if (lx == 2) {
    y <- paste(x[1], "and", x[2])
  }
  else {
    y <- c(x[1:lx-1], paste("and", x[lx]))
    y <- paste(y, collapse = ", ")
  }
  return(y)
}

# population sd:
popsd <- function(x) {
  sqrt( sum((x - mean(x, na.rm=TRUE))^2, na.rm = TRUE) / length(which(!is.na(xx))) )
}

# coefficient of variation
cv <- function(x) {
  # one of the following lines computes the sample stdev but returns NA if there is only 1 value
  # popsd computes the population stdev and will return 0 if there is only 1 value
  sd(x, na.rm = TRUE) / mean(x, na.rm = TRUE)
  # popsd(x) / mean(x, na.rm = TRUE)
}


# Quartile coefficient of dispersion
qcd <- function(x) {
  q <- quantile(x, na.rm = TRUE)

  a <- (q[[4]] - q[[2]])/2 # Interquantile range
  b <-  (q[[4]] + q[[2]])/2 # Midhinge
  c <- a/b  # qcd
  return(c)
}

norm_prox <- function(x) {
  #p <- (x - mean(x, na.rm = TRUE)) / sd(x, TRUE)  # normalize
  p <- scales::rescale(x, na.rm = TRUE)
  #p <- zoo::na.approx(p, na.rm = FALSE)                # interpolate missings
  return(p)
}

