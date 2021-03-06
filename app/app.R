## This provides a template for making CMMID-branded shiny apps
## key points:
##  - organized as a navbar page
##  - show audience something first: sidebar layouts are all controls-right
##    which means when viewed on mobile, the plot appears first rather than the controls
##  - the notes markdown is the place to document any long form details.



## load R files in R/
R_files <- dir("R", pattern = "[.]R$", full.names = TRUE)
for (e in R_files) source(e, local = TRUE)

## load required packages
library(shiny)
library(shinyWidgets)
library(incidence)
library(projections)
library(distcrete)
library(ggplot2)
library(invgamma)
library(markdown)


## global variables
app_title   <- "Hospital Bed Occupancy Projections"


admitsPanel <- function(prefix, tabtitle) {
  fmtr = function(inputId) {
    sprintf("%s%s", prefix, inputId)
  }
  
  return(
  tabPanel(tabtitle, sidebarLayout(position = "left",
  sidebarPanel(
      chooseSliderSkin("Shiny", color = slider_color),
      actionButton(fmtr("run"), "Run model", icon("play"),
                   style = "align:right"),
      h2("Starting conditions", style = sprintf("color:%s", cmmid_color)),
      p("Data inputs specifying the starting point of the forecast: a number of new COVID-19 admissions on a given date at the location considered. Reporting refers to the % of admissions notified.",
        style = sprintf("color:%s", annot_color)),
      dateInput(
          fmtr("admission_date"),
          "Date of admission:"),
      numericInput(
          fmtr("number_admissions"),
          "Number of admissions on that date:",
          min = 1,
          max = 10000,
          value = 1
      ),
      sliderInput(
          fmtr("assumed_reporting"),
          "Reporting rate (%):",
          min = 10,
          max = 100,
          value = 100,
          step = 5
      ),
      br(),
      h2("Model parameters", style = sprintf("color:%s", cmmid_color)),
      p("Parameter inputs specifying the COVID-19 epidemic growth as doubling time and associated uncertainty. Use more simulations to account for uncertainty in doubling time and length of hospital stay.",
        style = sprintf("color:%s", annot_color)),
      sliderInput(
          fmtr("doubling_time"),
          "Assumed doubling time (days):",
          min = 0.5,
          max = 10,
          value = 5, 
          step = 0.1
      ),
      sliderInput(
          fmtr("uncertainty_doubling_time"),
          "Uncertainty in doubling time (coefficient of variation):",
          min = 0,
          max = 0.5,
          value = 0.1,
          step = 0.01
      ),
      htmlOutput(fmtr("doubling_CI")),
      br(),
      sliderInput(
          fmtr("simulation_duration"),
          "Forecast period (days):",
          min = 1,
          max = 21,
          value = 7,
          step = 1
      ),
      sliderInput(
          fmtr("number_simulations"),
          "Number of simulations:",
          min = 10,
          max = 100,
          value = 30,
          step = 10
      ),
  ),
  mainPanel(
      includeMarkdown("include/heading_box.md"),
      br(),
      plotOutput(fmtr("main_plot"), width = "60%", height = "400px"),
      br(),
      checkboxInput(fmtr("show_los"), "Show duration of hospitalisation", FALSE),
      conditionalPanel(
          condition = sprintf("input.%s == true", fmtr("show_los")),
          plotOutput(fmtr("los_plot"), width = "30%", height = "300px")
      ),
      checkboxInput(fmtr("show_table"), "Show summary table", FALSE),
      conditionalPanel(
          condition = sprintf("input.%s == true", fmtr("show_table")),
          DT::dataTableOutput(fmtr("main_table"), width = "50%")
      ),
      
  )
  )))
}

## Define UI for application
ui <- navbarPage(
  title = div(
    a(img(src="cmmid_newlogo.svg", height="45px"),
      href="https://cmmid.github.io/"),
    span(app_title, style="line-height:45px")
  ),
  windowTitle = app_title,
  theme = "styling.css",
  position="fixed-top", collapsible = TRUE,
  admitsPanel(prefix = "gen_", tabtitle = "Non-critical care"),
  admitsPanel(prefix = "icu_", tabtitle = "Critical care"),
  tabPanel("Overall", mainPanel(
    plotOutput("gen_over_plot"),
    br(),
    plotOutput("icu_over_plot"),
    style="padding-bottom: 40px;"
  )),
  tabPanel("Information", 
           fluidPage(style="padding-left: 40px; padding-right: 40px; padding-bottom: 40px;", 
                     includeMarkdown("include/info.md"))),
  tabPanel("Acknowledgements", 
           fluidPage(style="padding-left: 40px; padding-right: 40px; padding-bottom: 40px;", 
                     includeMarkdown("include/ack.md")))
  

)

## Define server logic required to draw a histogram
server <- function(input, output) {
  
  ## graphs for the distributions of length of hospital stay (LoS)

  output$gen_los_plot <- renderPlot(plot_distribution(
    los_normal, "Duration of normal hospitalisation"
  ), width = 600)

  output$icu_los_plot <- renderPlot(plot_distribution(
    los_critical, "Duration of ICU hospitalisation"
  ), width = 600)
  
  genpars <- eventReactive(input$gen_run, list(
    date = input$gen_admission_date,
    n_start = as.integer(input$gen_number_admissions),
    doubling = r_doubling(n = input$gen_number_simulations,
                          mean = input$gen_doubling_time,
                          cv = input$gen_uncertainty_doubling_time),
    duration = input$gen_simulation_duration,
    reporting = input$gen_assumed_reporting / 100,
    r_los = los_normal$r
  ), ignoreNULL = FALSE)
  
  icupars <- eventReactive(input$icu_run, list(
    date = input$icu_admission_date,
    n_start = as.integer(input$icu_number_admissions),
    doubling = r_doubling(n = input$icu_number_simulations,
                          mean = input$icu_doubling_time,
                          cv = input$icu_uncertainty_doubling_time),
    duration = input$icu_simulation_duration,
    reporting = input$icu_assumed_reporting / 100,
    r_los = los_critical$r
  ), ignoreNULL = FALSE)
  
  genbeds <- reactive(do.call(run_model, genpars()))
  icubeds <- reactive(do.call(run_model, icupars()))
  
  ## main plot: predictions of bed occupancy
  output$gen_over_plot <- output$gen_main_plot <- renderPlot({
    plot_beds(genbeds(),
    ribbon_color = slider_color,
    palette = cmmid_pal,
    title = "Non-critical care bed occupancy")
  }, width = 600)
  
  output$icu_over_plot <- output$icu_main_plot <- renderPlot({
    plot_beds(icubeds(),
    ribbon_color = slider_color,
    palette = cmmid_pal,
    title = "Critical care bed occupancy")
  }, width = 600)

  output$icu_doubling_CI <- reactive({
    q <- q_doubling(mean = input$icu_doubling_time, 
                    cv   = input$icu_uncertainty_doubling_time,
                    p = c(0.025, 0.975))
    sprintf("<b>Doubling time 95%% range:</b> (%0.1f, %0.1f)", q[1], q[2])
  })
  
  output$gen_doubling_CI <- reactive({
    q <- q_doubling(mean = input$gen_doubling_time, 
                    cv   = input$gen_uncertainty_doubling_time,
                    p = c(0.025, 0.975))
    sprintf("<b>Doubling time 95%% range:</b> (%0.1f, %0.1f)", q[1], q[2])
  })
  
  ## summary tables
  output$gen_main_table <- DT::renderDataTable({
    summarise_beds(genbeds())
  })
  output$icu_main_table <- DT::renderDataTable({
    summarise_beds(icubeds())
  })

  
}

## Run the application 
shinyApp(ui = ui, server = server)
