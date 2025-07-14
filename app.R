# This app will not run unless you create an .Renviron file with OPENAI_API_KEY 
# Use the .Renviron.example file as a sample, but add your actual API key.
# It is meant for local use, unless you are willing to pay for all users' API calls.
# You also need to run the code from the InfoWorld article to generate 
# ukraine_workshop_data_results.parquet and ukraine_workshop_w_metadata.duckdb

library(shiny)
library(shinychat)
library(ellmer)
library(ragnar)
library(reactable)
library(bslib)
library(dplyr)
library(htmltools)
library(promises)
library(arrow)
library(lubridate)

# Load environment variables
if (file.exists(".Renviron")) {
  readRenviron(".Renviron")
}

ui <- page_fillable(
  theme = bs_theme(
    bootswatch = "flatly",
    primary = "#005BBB",  # Ukrainian blue
    base_font = font_google("Roboto")
  ),
  
  # Replace your titlePanel() with this:
  div(
    style = "text-align: center; padding: 10px; background: linear-gradient(to right, #005BBB 50%, #FFD700 50%); margin: -15px -15px 15px -15px;",
    div(
      style = "background: white; padding: 15px; margin: 10px;",
      h2(
        "Workshops for Ukraine Chatbot UNOFFICIAL",
        span(
          style = "display: inline-block; width: 30px; height: 20px; vertical-align: middle; margin-left: 5px; border: 1px solid #ccc;",
          div(style = "background: #005BBB; height: 50%; width: 100%;"),
          div(style = "background: #FFD700; height: 50%; width: 100%;")
        ),
        style = "color: #005BBB; margin: 0;"
      ),
      h3("AI-Powered Workshop Discovery Tool", style = "color: #666; margin: 5px 0;"),
      p(
        "⚠️ Please verify workshop details - AI can make mistakes! - and register at ",
        a("the official site", 
          href = "https://sites.google.com/view/dariia-mykhailyshyna/main/r-workshops-for-ukraine",
          target = "_blank",
          style = "color: #005BBB; font-weight: bold;"),
        style = "margin: 10px 0; font-size: 14px;"
      )
    )
  ),
  
  layout_sidebar(
    sidebar = sidebar(
      width = "50%",
      title = "🤖 Workshops for Ukraine Assistant",
      open = "always", 
      
      # Sample questions
      div(
        style = "margin-bottom: 15px;",
        h5("Sample questions:", style = "margin-top: 0; color: #005BBB;"),
        actionButton("ask_viz", "📊 What workshops could help me improve my R data visualization skills?", 
                     class = "btn-primary", style = "width: 100%; margin-bottom: 5px; white-space: normal; text-align: left;"),
        actionButton("ask_next_month", "📅 Are there any R-related workshops next month?", 
                     class = "btn-primary", style = "width: 100%; white-space: normal; text-align: left;")
      ),
      
      div(
        style = "background: #f8f9fa; padding: 10px; border-radius: 5px; margin-bottom: 15px;",
        p("I can help you find workshops by topic, upcoming workshops by date and/or topic, and more.",
          style = "font-size: 15px; color: #666; margin: 0;")
      ),
      
      chat_ui(
        "workshop_chat",
        messages = list(
          list(
            role = "assistant",
            content = "Hi! 👋 I'm here to help you discover data science Workshops for Ukraine. I can search by topic, date, or help you find workshops that match your learning goals. What are you interested in learning?"
          )
        ),
        placeholder = "Ask about workshops ...",
        height = "400px"
      )
    ),
    
    # Main panel with workshop table
    div(title = "Workshops for Ukraine UNOFFICIAL AI Assistant",
        style = "padding: 15px;",
        div(
          style = "margin-bottom: 15px; padding: 10px; background: #f8f9fa; border-radius: 5px;",
          fluidRow(
            column(8, 
                   h4("📚 Workshop Directory", style = "margin: 0; color: #005BBB;"),
                   p("Click on the triangle to the left any workshop title to see its full description • Descriptions are searchable even when hidden", 
                     style = "margin: 5px 0 0 0; color: #666; font-size: 13px;")
            ),
            column(4,
                   div(
                     style = "text-align: right;",
                     textOutput("table_stats"),
                     style = "font-size: 14px; color: #666; padding: 5px 0;"
                   )
            )
          )
        ),
        reactableOutput("workshop_table", height = "600px")
    )
  )
)

server <- function(input, output, session) {
  
  # Load workshop data
  workshops_data <- reactive({
    tryCatch({
      read_parquet("ukraine_workshop_data_results.parquet") |>
        select(Title = title, Date = date, Description = text, Speaker = speaker_name)
    }, error = function(e) {
      data.frame(
        Title = c("Introduction to R", "Data Visualization with ggplot2"),
        Date = c("2024-01-15", "2024-01-20"),
        Description = c("Learn R basics", "Create beautiful plots"),
        Speaker = c("", "")
      )
    })
  })
  
  # Initialize store connection as a regular variable, not reactive
  store <- NULL
  
  # Try to connect to the store on startup
  tryCatch({
    store <- ragnar_store_connect("ukraine_workshop_w_metadata.duckdb", read_only = TRUE)
  }, error = function(e) {
    # Silent fail - store remains NULL
    message("Could not connect to ragnar store: ", e$message)
  })
  
  # Create the retrieval function with store as parameter
  retrieve_workshops_filtered <- function(query = "data-related", start_date = NULL, end_date = NULL, top_k = 8) {
    # Use the global store variable
    if (is.null(store)) return("No workshop database available.")
    
    # Build filter expression based on provided dates
    if (!is.null(start_date) && !is.null(end_date)) {
      # Both dates provided
      start_date <- as.Date(start_date)
      end_date <- as.Date(end_date)
      
      filter_expr <- rlang::expr(between(
        date,
        !!as.Date(start_date),
        !!as.Date(end_date)
      ))
    } else if (!is.null(start_date)) {
      # Only start date
      filter_expr <- rlang::expr(date >= !!as.Date(start_date))
    } else if (!is.null(end_date)) {
      # Only end date
      filter_expr <- rlang::expr(date <= !!as.Date(end_date))
    } else {
      # no filter
      filter_expr <- NULL
    }
    
    # Perform the retrieval
    tryCatch({
      results <- ragnar_retrieve(
        store,  # Use the correct store variable
        query,
        top_k = top_k,
        filter = !!filter_expr
      ) |>
        select(title, date, speaker_name, speaker_affiliations, text)
      
      if (nrow(results) > 0) {
        # Return the results as a data frame, not concatenated text
        # The LLM will handle formatting
        return(results)
      } else {
        return("No workshops found matching your criteria.")
      }
    }, error = function(e) {
      return(paste("Error searching workshops:", e$message))
    })
  }
  
  # Initialize chat
  chat_obj <- reactiveVal(NULL)
  
  observe({
    # Check API key
    api_key <- Sys.getenv("OPENAI_API_KEY")
    if (api_key == "" || is.null(store)) {
      message("Missing API key or store")
      return()
    }
    
    tryCatch({
      # Create tool
      workshop_retrieval_tool <- tool(
        retrieve_workshops_filtered,
        "Retrieve workshop information based on content query and optional date filtering. Only returns workshops that match both the content query and date constraints.",
        query = type_string(
          "The search query describing what kind of workshop content you're looking for (e.g., 'data visualization', 'data wrangling')"
        ),
        start_date = type_string(
          "Optional start date in YYYY-MM-DD format. Only workshops on or after this date will be returned.",
          required = FALSE
        ),
        end_date = type_string(
          "Optional end date in YYYY-MM-DD format. Only workshops on or before this date will be returned.",
          required = FALSE
        ),
        top_k = type_integer(
          "Number of workshops to retrieve (default: 8)",
          required = FALSE
        )
      )
      
      # System prompt
      system_prompt <- paste0(
        "You are a helpful assistant who only answers questions about Workshops for Ukraine from provided context. ",
        "Do not use your own existing knowledge about workshops. ",
        "Use the retrieve_workshops_filtered tool to search for workshops and workshop information. ",
        "When users mention time periods like 'next month', 'this month', 'upcoming', etc., ",
        "convert these to specific YYYY-MM-DD date ranges and pass them to the tool. ",
        "Past workshops do not have Date entries so would be NULL or NA. ",
        "Today's date is ", Sys.Date(), ". ",
        "If no workshops match the criteria, let the user know. ",
        "Format your responses in a friendly, conversational way with bullet points or numbered lists when appropriate."
      )
      
      # Create chat
      chat <- chat_openai(
        system_prompt = system_prompt,
        model = "gpt-4.1",
        echo = "none"
      )
      
      # Register tool
      chat$register_tool(workshop_retrieval_tool)
      
      chat_obj(chat)
      message("Chat initialized successfully")
      
    }, error = function(e) {
      message("Error initializing chat: ", e$message)
      # Fallback chat without tools
      chat <- chat_openai(
        system_prompt = "You are a helpful assistant for finding R workshops. I don't have access to the workshop database right now.",
        model = "gpt-4.1",
        echo = "none"
      )
      chat_obj(chat)
    })
  })
  
  # Sample question handlers
  observeEvent(input$ask_viz, {
    chat <- chat_obj()
    if (!is.null(chat)) {
      query <- "What workshops could help me improve my R data visualization skills? Please search for workshops related to visualization, ggplot2, plotting, or graphics."
      
      tryCatch({
        response_stream <- chat$stream_async(query)
        chat_append("workshop_chat", response_stream) %>%
          catch(function(error) {
            chat_append("workshop_chat", paste("Sorry, I had trouble searching for workshops:", error$message))
          })
      }, error = function(e) {
        chat_append("workshop_chat", paste("Sorry, I had trouble processing that question:", e$message))
      })
    } else {
      chat_append("workshop_chat", "The chat system is not initialized yet. Please wait a moment and try again.")
    }
  })
  
  observeEvent(input$ask_next_month, {
    chat <- chat_obj()
    if (!is.null(chat)) {
      # Calculate next month's date range
      today <- Sys.Date()
      first_of_next_month <- ceiling_date(today, "month")
      last_of_next_month <- ceiling_date(first_of_next_month, "month") - days(1)
      
      query <- paste0(
        "Are there any R-related workshops next month? ",
        "Please search for workshops between ", first_of_next_month, " and ", last_of_next_month, "."
      )
      
      tryCatch({
        response_stream <- chat$stream_async(query)
        chat_append("workshop_chat", response_stream) %>%
          catch(function(error) {
            chat_append("workshop_chat", paste("Sorry, I had trouble searching for workshops:", error$message))
          })
      }, error = function(e) {
        chat_append("workshop_chat", paste("Sorry, I had trouble processing that question:", e$message))
      })
    } else {
      chat_append("workshop_chat", "The chat system is not initialized yet. Please wait a moment and try again.")
    }
  })
  
  # Handle user chat input
  observeEvent(input$workshop_chat_user_input, {
    req(input$workshop_chat_user_input)
    
    chat <- chat_obj()
    if (is.null(chat)) {
      chat_append("workshop_chat", "The chat system is not initialized yet. Please wait a moment and try again.")
      return()
    }
    
    user_input <- input$workshop_chat_user_input
    
    tryCatch({
      response_stream <- chat$stream_async(user_input)
      chat_append("workshop_chat", response_stream) %>%
        catch(function(error) {
          chat_append("workshop_chat", paste("Sorry, I encountered an error:", error$message))
        })
      
    }, error = function(e) {
      chat_append("workshop_chat", paste("Sorry, I encountered an error:", e$message))
    })
  })
  
  # Render workshop table with reactable
  output$workshop_table <- renderReactable({
    data <- workshops_data()
    
    reactable(
      data,
      columns = list(
        Title = colDef(
          name = "Workshop Title",
          minWidth = 300,
          style = list(fontWeight = "bold", color = "#005BBB")
        ),
        Date = colDef(
          name = "Date",
          width = 120,
          format = colFormat(date = TRUE, locales = "en-US"),
          style = function(value) {
            if (!is.na(value) && as.Date(value) >= Sys.Date()) {
              list(color = "#28a745", fontWeight = "bold")
            } else {
              list(color = "#6c757d")
            }
          }
        ),
        Speaker = colDef(
          name = "Speaker",
          minWidth = 200
        ),
        Description = colDef(
          show = FALSE,
          searchable = TRUE  # Explicitly make descriptions searchable
        )
      ),
      details = function(index) {
        workshop <- data[index, ]
        div(
          style = "padding: 15px; background: #f8f9fa; border-left: 3px solid #005BBB;",
          h5(workshop$Title, style = "color: #005BBB; margin-top: 0;"),
          if (!is.na(workshop$Date)) {
            p(
              strong("Date: "), 
              format(as.Date(workshop$Date), "%B %d, %Y"),
              if (as.Date(workshop$Date) >= Sys.Date()) {
                span(" (Upcoming)", style = "color: #28a745; font-weight: bold;")
              } else {
                span(" (Past)", style = "color: #6c757d;")
              }
            )
          },
          div(
            style = "margin-top: 10px;",
            p(workshop$Description)
          ),
          div(
            style = "margin-top: 15px; padding-top: 15px; border-top: 1px solid #dee2e6;",
            a(
              "Register for this workshop →",
              href = "https://sites.google.com/view/dariia-mykhailyshyna/main/r-workshops-for-ukraine",
              target = "_blank",
              class = "btn btn-primary btn-sm"
            )
          )
        )
      },
      searchable = TRUE,
      filterable = TRUE,
      highlight = TRUE,
      bordered = TRUE,
      striped = TRUE,
      pagination = TRUE,
      defaultPageSize = 10,
      showPageSizeOptions = TRUE,
      pageSizeOptions = c(10, 20, 50),
      theme = reactableTheme(
        searchInputStyle = list(width = "100%"),
        headerStyle = list(background = "#f8f9fa", fontWeight = "bold")
      )
    )
  })
  
  # Update stats
  output$table_stats <- renderText({
    data <- workshops_data()
    total_workshops <- nrow(data)
    upcoming <- sum(!is.na(data$Date) & as.Date(data$Date) >= Sys.Date(), na.rm = TRUE)
    
    paste0(
      "📊 ", total_workshops, " workshops | ",
      "🔜 ", upcoming, " upcoming"
    )
  })
  
  
  
  
}

shinyApp(ui = ui, server = server)