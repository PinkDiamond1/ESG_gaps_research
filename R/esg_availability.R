# ==================================================
# project:       Country coverage (availability) of indicators
#                Over time
# Author:        Andres Castaneda
# Dependencies:  The World Bank
# ----------------------------------------------------
# Creation Date:    2019
# Modification Date:
# Script version:    01
# References:
#
#
# Output:             output
# ==================================================

#----------------------------------------------------------
#   Load libraries
#----------------------------------------------------------
library("viridis")
# find if load_data.R has been executed

if (!all(c("mtd", "mrv_series", "x")  %in% ls())) {
  source("R/load_data.R")
}

source("R/utils.R")
#----------------------------------------------------------
#   Number of countries per indicator over time"
#----------------------------------------------------------

#--------- heatmap indicators years and No. of countries

d1 <- x %>%
  group_by(indicatorID,indicator, date) %>%
  count(date) %>%
  mutate(text = paste0("Indicator: ", indicator, "\n",
                       "Indicator ID: ", indicatorID, "\n",
                       "Year: ", date, "\n",
                       "No. countries: ", n, "\n"))

# Sort indicators from most data points to less overall
o <- d1 %>%
  group_by(indicatorID) %>%
  summarise(n2 = sum(n)) %>%
  arrange(n2) %>%
  mutate(ind = factor(indicatorID, levels = unique(indicatorID)))

d1 <- inner_join(d1, o)


d2 <- x %>%
  group_by(indicatorID,indicator, date) %>%
  summarise(n = n_distinct(iso3c)) %>%
  group_by(indicatorID,indicator)  %>%
  summarise(mean = mean(n, na.rm = TRUE)) %>%
  ungroup()

#--------------- -------------------------------------------
#   Average growth of countries per year in each indicator
#----------------------------------------------------------

fillin <- expand_grid(
  date        = c(2000:2019),
  indicatorID = unique(x$indicatorID)
) %>%
  inner_join(
    tibble(
      indicatorID  = unique(x$indicatorID),
      indicator    = unique(x$indicator)
    ),
    by = "indicatorID"
  )


x2 <- x %>%  # coverage improvement over time
  group_by(indicatorID,indicator, date) %>%
  summarise(nc = n_distinct(iso3c)) %>%
  ungroup() %>%
  full_join(fillin, by = c("indicatorID", "indicator", "date")) %>%
  arrange(indicatorID, date) %>%
  mutate(
    nc = if_else(is.na(nc), 0L, nc)
  )


lmdi <- x2 %>%
  nest(data = -c(indicator, indicatorID)) %>%
  mutate(

    # linear regression
    fit  = purrr::map(data, ~lm(nc ~ date, data = .)),

    # extract beta
    beta = purrr::map(fit, ~broom::tidy(.)[["estimate"]][2]),

    # Find number of year with at least one count ry
    nyc  = purrr::map(data, ~count(nyc = nc > 0, x = .) %>%
                        filter(nyc == TRUE) %>%
                        pull(n)
    )
  ) %>%
  unnest(c(beta, nyc)) %>%
  select(indicatorID, indicator, beta, nyc) %>%
  mutate(
    penalty = nyc/(2019-2000+1),
    beta    = penalty*beta
  ) %>%
  arrange(-beta) %>%
  select(-penalty)



# cci <- x %>%  # coverage improvement over time
#   group_by(indicatorID,indicator, date) %>%
#   summarise(nc = n_distinct(iso3c)) %>%
#   ungroup() %>%
#   full_join(fillin, by = c("indicatorID", "indicator", "date")) %>%
#   arrange(indicatorID, date) %>%
#   mutate(
#     nc = if_else(is.na(nc), 0L, nc)
#   )
#



# indtest <- "SH.STA.DIAB.ZS"
#
# ggplot(data = filter(cci, indicatorID == indtest),
#        aes(
#          x = date,
#          y = nc
#          )) +
#   geom_bar(stat="identity")


#----------------------------------------------------------
#   Intermittent coverage
#----------------------------------------------------------

ici <- x2 %>%
  arrange(indicatorID, date) %>%
  group_by(indicatorID, indicator) %>%
  mutate(
    nyc = if_else(nc > 0, 1, 0),

    # Beginning of each new interval
    cnyc = case_when(
      nyc == 0 & row_number() == 1 ~ 1,
      nyc == 0 & nyc != lag(nyc)   ~ 1,
      TRUE ~ 0
    ),

    # cumulative intervals
    ni = cumsum(cnyc)

  ) %>%
  summarise(
    nyc = sum(nyc, na.rm = TRUE),
    cv  = cv(nc),
    ni  = max(ni) # numer of intervals
  ) %>%
  ungroup() %>%
  mutate(
    aci   = max(nyc)/nyc, # average coverage interval

    # lumpinnes index
    li   = round((cv^2)/aci, digits = 5)
  ) %>%
  arrange(-ni, -aci, -cv) %>%
  select(-cv)

# ggplot(data = filter(ici, cv2 < 50),
#        aes(
#          x = cv2,
#          y = aci
#        )
#        ) +
#   geom_point()


#----------------------------------------------------------
#   Indicators stable over time
#----------------------------------------------------------

si <- x2 %>%
  group_by(indicatorID, indicator) %>%
  summarise(
    mean = mean(nc, na.rm = TRUE),
    sd   = sd(nc, na.rm = TRUE)
  ) %>%
  filter(mean > 0) %>%
  ungroup() %>%
  arrange(sd, -mean)


#----------------------------------------------------------
#   Sudden decline
#----------------------------------------------------------

sdd <- x %>%
  group_by(indicatorID,indicator, date) %>%
  summarise(nc = n_distinct(iso3c))   %>%
  full_join(fillin,
            by = c("indicatorID", "indicator", "date")
  ) %>%
  arrange(indicatorID, date) %>%
  mutate(
    nc = if_else(is.na(nc), 0L, nc)
  ) %>%
  group_by(indicatorID, indicator) %>%
  mutate(
    sdi = nc - lag(nc)
  ) %>%
  group_by(indicatorID) %>%
  filter(sdi == min(sdi, na.rm = TRUE)) %>% # min because they are negative values.
  filter(sdi < 0) %>%
  filter(date == max(date)) %>%
  mutate(sdi = sdi*-1) %>%
  arrange(-sdi) %>%
  select(indicatorID, indicator, date, sdi)


#----------------------------------------------------------
#   High coverage No gap
#----------------------------------------------------------

hc <-  mtd %>%
  filter(no_gap == 1) %>%
  arrange(-n_no_gaps) %>%
  select(cetsid, input_name, sector)

#----------------------------------------------------------
#   Charts
#----------------------------------------------------------


# Plot Heatmap
g1 <- ggplot(data = filter(d1, date >= 2000, date <= 2018),
             aes( x = date,
                  y = ind,
                  fill = n,
                  text = text)) +
  geom_tile() +
  scale_fill_viridis_c(option = "A", alpha = .8,
                       limits = c(0, 220),
                       breaks = c(0, 50, 100, 150, 200)) +
  labs(x = "", y = "") +
  scale_x_continuous(breaks = c(2000:2018),
                     # leaves some padding on either side of the heatmap - necessary for PDF versions
                     limits=c(1999,2019),
                     expand = c(0,0)) +
  theme(axis.text.x = element_text(size = rel(0.8), angle = 330, hjust = 0, colour = "grey50"),
        axis.text.y = element_text(size = rel(0.5), colour = "grey50"))

# ggtitle(label = "Number of countries per indicator over time")
#g1
# make it interactive
# ggsave("figs/ciavailability.png", plot = g1, width = 7, height = 7, dpi = "retina")
# pg1 <- plotly::ggplotly(g1, tooltip = "text")




#----------------------------------------------------------
#   heatmap by explanation
#----------------------------------------------------------


d1a <- d1 %>%
  inner_join(select(mtd, cetsid, matches("^expl")),
             by = c("indicatorID" = "cetsid")) %>%
  ungroup() %>%
  mutate(ideal = if_else(rowSums(select(., matches("^expl"))) == 0,
                         1, 0))


hm_expl <- function(x, expl,
                    label = NULL, png_layers=theme()) {
  expl <- enquo(expl)

  if (length(label) > 0) {
    labelf <-  paste0("Number of countries over time per indicator (",
                      label, ")")
  } else {
    labelf <- "Number of countries over time per indicator"
  }

  y <- filter(x, !!expl == 1, date >= 2000, date <= 2018)

  if (dim(y)[[1]] == 0) {
    invisible("")
  } else {
    g1a <- ggplot(data = y,
                  aes(text = text)) +
      geom_tile(aes( x = date,
                     y = ind,
                     fill = n)) +
      scale_fill_viridis_c(option = "A", alpha = .8,
                           limits = c(0, 220),
                           breaks = c(0, 50, 100, 150, 200)) +
      labs(x = "", y = "") +
      scale_x_continuous(breaks = c(2000:2018),
                         # leaves some padding on either side of the heatmap - necessary for PDF versions
                         limits=c(1999,2019),
                         expand = c(0,0)) +
      theme(axis.text.x = element_text(size = rel(0.8),
                                       angle = 330,
                                       hjust = 0,
                                       colour = "grey50"),
            axis.text.y = element_text(size = rel(0.5),
                                       colour = "grey50"))
    # ggtitle(label = labelf)
    name = paste('expl-', str_replace_all(tolower(label), ' ', ''), sep='')
    # plotly::ggplotly(g1a, tooltip = "text")
    report.graphic(g1a, name,
        pdf=list(
          layers=theme(
            axis.text.x = element_text(size=rel(0.5))
            # plot.margin=margin(t=20)
          ),
          args=list(width=4)
        ))
  }
}
