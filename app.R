library(shiny)
library(bslib)
library(httr2)
library(jsonlite)

source("R/supabase.R", local = TRUE)

event_details <- list(
  explore = tagList(
    tags$p("Explore UNF runs in two phases: common programming followed by self-directed exploration."),
    tags$ul(
      tags$li("8:30–9:00 a.m. — Check-in, Fine Arts Center Lobby"),
      tags$li("9:00–9:45 a.m. — Welcome program, Lazzara Theater"),
      tags$li("9:45–10:30 a.m. — College breakout sessions"),
      tags$li("10:30 a.m.–1:30 p.m. — Self-directed exploration"),
      tags$li("10:30 a.m. and noon — Potential course demonstrations and enrichment sessions")
    )
  )
)

ui <- page_fluid(
  theme = bs_theme(version = 5, bg = "#F5F7F9", fg = "#0A233F", primary = "#0A233F", font_scale = 1.05),
  tags$head(
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(rel = "preconnect", href = "https://fonts.gstatic.com", crossorigin = "anonymous"),
    tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Open+Sans:wght@300;400;600;700;800&display=swap"),
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")
  ),
  div(class = "hero",
      div(class = "hero-inner",
          div(class = "logo-panel",
              tags$img(src = "VerticalLogoBlue-resized.png",
                       alt = "University of North Florida",
                       class = "unf-logo")),
          div(class = "hero-copy",
              div(class = "eyebrow", "PSYCHOLOGICAL & BRAIN SCIENCES"),
              h1("Faculty Recruitment Event Signup"),
              p("Choose an open event below. Enter your last name and select Sign up; the position is then reserved.")))),
  div(class = "app-shell",
      uiOutput("connection_notice"),
      uiOutput("summary"),
      div(class = "toolbar",
          checkboxInput("upcoming_only", "Show upcoming events only", value = TRUE),
          actionButton("refresh", "Refresh", class = "btn-outline-secondary")),
      uiOutput("events"),
      tags$footer("PBSci recruitment coverage · Data refreshes automatically every 15 seconds"))
)

server <- function(input, output, session) {
  tick <- reactiveTimer(15000, session)
  data_version <- reactiveVal(0)
  details_edit_id <- reactiveVal(NULL)
  observeEvent(input$refresh, data_version(data_version() + 1))

  event_data <- reactive({
    tick(); data_version()
    req(supabase_configured())
    list(events = sb_get_events(), signups = sb_get_signups())
  })

  output$connection_notice <- renderUI({
    if (!supabase_configured())
      div(class = "alert alert-warning", strong("Setup required: "),
          "Add SUPABASE_URL and SUPABASE_ANON_KEY as environment variables. See README.md.")
  })

  output$summary <- renderUI({
    req(supabase_configured())
    d <- tryCatch(event_data(), error = function(e) NULL)
    if (is.null(d)) return(div(class = "alert alert-danger", "The database could not be reached. Select Refresh or check the deployment variables."))
    filled <- nrow(d$signups)
    total <- sum(d$events$slots_required)
    div(class = "summary-grid",
        div(class = "summary-card", span("EVENT SESSIONS"), strong(nrow(d$events))),
        div(class = "summary-card", span("POSITIONS FILLED"), strong(filled)),
        div(class = "summary-card", span("POSITIONS OPEN"), strong(total - filled)),
        div(class = "summary-card", span("OVERALL COVERAGE"), strong(sprintf("%.0f%%", 100 * filled / total))))
  })

  output$events <- renderUI({
    req(supabase_configured())
    d <- tryCatch(event_data(), error = function(e) NULL)
    req(d)
    events <- d$events
    if (isTRUE(input$upcoming_only)) events <- events[as.Date(events$event_date) >= Sys.Date(), , drop = FALSE]
    if (!nrow(events)) return(div(class = "empty-state", "No upcoming events."))
    tagList(lapply(seq_len(nrow(events)), function(i) event_card(events[i, ], d$signups)))
  })

  event_card <- function(event, signups) {
    eid <- event$event_id[[1]]
    current <- signups[signups$event_id == eid, , drop = FALSE]
    filled <- nrow(current); required <- event$slots_required[[1]]
    time_display <- if (nzchar(event$end_time[[1]]))
      paste(event$start_time[[1]], "–", event$end_time[[1]])
    else event$start_time[[1]]
    status_class <- if (filled == required) "full" else if (filled == 0) "empty" else "partial"
    status_text <- if (filled == required) "FULL" else paste(required - filled, "OPEN")
    signup_rows <- lapply(seq_len(required), function(slot) {
      who <- current[current$slot_number == slot, , drop = FALSE]
      if (nrow(who)) {
        role <- if ("role" %in% names(who)) trimws(who$role[[1]]) else ""
        signup_location <- if ("location" %in% names(who)) trimws(who$location[[1]]) else ""
        div(class = "slot filled-slot",
            div(class = "slot-person",
                span(class = "slot-number", paste("Slot", slot)),
                strong(who$last_name[[1]]),
                if (nzchar(role)) span(class = "signup-role", strong("Role: "), role),
                if (nzchar(signup_location)) span(class = "signup-location", strong("Location: "), signup_location)),
            div(class = "slot-actions",
                actionButton(
                  paste0("details_", who$signup_id[[1]]),
                  "Edit details",
                  class = "btn-sm btn-link edit-role-link",
                  onclick = sprintf("Shiny.setInputValue('edit_details_request','%s',{priority:'event'})", who$signup_id[[1]])
                ),
                actionButton(
                  paste0("remove_", who$signup_id[[1]]), "Remove",
                  class = "btn-sm btn-link remove-link",
                  onclick = sprintf("Shiny.setInputValue('remove_request','%s',{priority:'event'})", who$signup_id[[1]])
                )))
      } else {
        div(class = "slot open-slot", span(class = "slot-number", paste("Slot", slot)), span("Available"))
      }
    })
    signup_control <- if (filled < required) {
      div(class = "signup-control",
          div(class = "signup-fields",
              textInput(paste0("name_", eid), "Last name", placeholder = "Enter last name"),
              textInput(paste0("role_", eid), "Role", placeholder = "How will you help?"),
              textInput(paste0("location_", eid), "Location", placeholder = "Lab or requested event assignment")),
          actionButton(paste0("signup_", eid), "Sign up", class = "btn-primary",
                       onclick = sprintf("Shiny.setInputValue('signup_event',%s,{priority:'event'})", eid)))
    }
    details <- if (identical(event$details_key[[1]], "explore")) event_details$explore
    div(class = paste("event-card", status_class),
        div(class = "event-top",
            div(span(class = "season", event$season[[1]]), h2(event$event_name[[1]])),
            span(class = paste("status-pill", status_class), status_text)),
        div(class = "event-meta",
            span(icon("calendar"), format(as.Date(event$event_date[[1]]), "%A, %B %d, %Y")),
            span(icon("clock"), time_display),
            span(icon("location-dot"), event$location[[1]])),
        div(class = "signup-instruction",
            strong("Role: "),
            "How will you help/what do you expect to be doing?",
            tags$br(),
            strong("Location: "),
            "Enter the lab where you will be working, or if not in a lab, what job do you hope to do (e.g., moving students across campus, placing signage before/after the event, etc.)."),
        p(class = "description", event$description[[1]]),
        if (nzchar(event$special_notes[[1]])) div(class = "special-note", strong("Special note: "), event$special_notes[[1]]),
        if (!is.null(details)) tags$details(tags$summary("Event schedule and details"), details),
        div(class = "coverage-row",
            div(class = "coverage-heading", paste0("PBSci faculty coverage · ", filled, " of ", required)),
            actionButton(
              paste0("add_slot_", eid), "Add slot", icon = icon("plus"),
              class = "btn-sm btn-outline-secondary add-slot-button",
              onclick = sprintf("Shiny.setInputValue('add_slot_event',%s,{priority:'event'})", eid)
            )),
        div(class = "slots", signup_rows), signup_control)
  }

  observeEvent(input$add_slot_event, {
    eid <- input$add_slot_event
    result <- tryCatch(sb_add_slot(eid), error = function(e) e)
    if (inherits(result, "error")) {
      showNotification(conditionMessage(result), type = "error", duration = 7)
    } else {
      showNotification("One signup slot was added.", type = "message")
      data_version(data_version() + 1)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$signup_event, {
    eid <- input$signup_event
    name <- trimws(input[[paste0("name_", eid)]] %||% "")
    role <- trimws(input[[paste0("role_", eid)]] %||% "")
    signup_location <- trimws(input[[paste0("location_", eid)]] %||% "")
    if (!nzchar(name)) { showNotification("Please enter your last name.", type = "warning"); return() }
    if (!nzchar(role)) { showNotification("Please describe how you will help.", type = "warning"); return() }
    if (!nzchar(signup_location)) { showNotification("Please enter a location or requested event assignment.", type = "warning"); return() }
    result <- tryCatch(sb_claim_slot(eid, name, role, signup_location), error = function(e) e)
    if (inherits(result, "error")) showNotification(conditionMessage(result), type = "error", duration = 7)
    else {
      showNotification(paste("Signed up:", name), type = "message")
      updateTextInput(session, paste0("name_", eid), value = "")
      updateTextInput(session, paste0("role_", eid), value = "")
      updateTextInput(session, paste0("location_", eid), value = "")
      data_version(data_version() + 1)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$edit_details_request, {
    sid <- input$edit_details_request
    d <- tryCatch(event_data(), error = function(e) NULL)
    if (is.null(d)) {
      showNotification("The signup could not be loaded. Select Refresh and try again.", type = "error")
      return()
    }
    signup <- d$signups[d$signups$signup_id == sid, , drop = FALSE]
    if (!nrow(signup)) {
      showNotification("That signup no longer exists.", type = "warning")
      data_version(data_version() + 1)
      return()
    }
    current_role <- if ("role" %in% names(signup)) trimws(signup$role[[1]]) else ""
    current_location <- if ("location" %in% names(signup)) trimws(signup$location[[1]]) else ""
    details_edit_id(sid)
    showModal(modalDialog(
      title = paste("Signup details for", signup$last_name[[1]]),
      textInput("edit_role_value", "Role", value = current_role,
                placeholder = "How will you help?"),
      textInput("edit_location_value", "Location", value = current_location,
                placeholder = "Lab or requested event assignment"),
      footer = tagList(modalButton("Cancel"), actionButton("confirm_details_edit", "Save details", class = "btn-primary"))
    ))
  }, ignoreInit = TRUE)

  observeEvent(input$confirm_details_edit, {
    sid <- details_edit_id()
    role <- trimws(input$edit_role_value %||% "")
    signup_location <- trimws(input$edit_location_value %||% "")
    if (is.null(sid)) return()
    if (!nzchar(role)) {
      showNotification("Please describe how you will help.", type = "warning")
      return()
    }
    if (!nzchar(signup_location)) {
      showNotification("Please enter a location or requested event assignment.", type = "warning")
      return()
    }
    result <- tryCatch(sb_update_signup_details(sid, role, signup_location), error = function(e) e)
    if (inherits(result, "error")) {
      showNotification(conditionMessage(result), type = "error", duration = 7)
    } else {
      removeModal()
      details_edit_id(NULL)
      showNotification("Signup details saved.", type = "message")
      data_version(data_version() + 1)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$remove_request, {
    sid <- input$remove_request
    showModal(modalDialog(title = "Remove signup?", "This will immediately reopen the position.",
                          footer = tagList(modalButton("Cancel"), actionButton("confirm_remove", "Remove signup", class = "btn-danger"))))
  }, ignoreInit = TRUE)

  observeEvent(input$confirm_remove, {
    sid <- input$remove_request
    tryCatch({ sb_remove_signup(sid); removeModal(); showNotification("Signup removed."); data_version(data_version() + 1) },
             error = function(e) showNotification(conditionMessage(e), type = "error"))
  }, ignoreInit = TRUE)
}

shinyApp(ui, server)
