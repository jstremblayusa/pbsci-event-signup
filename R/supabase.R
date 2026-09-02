sb_url <- function() sub("/$", "", Sys.getenv("SUPABASE_URL"))
sb_key <- function() Sys.getenv("SUPABASE_ANON_KEY")

supabase_configured <- function() nzchar(sb_url()) && nzchar(sb_key())

sb_request <- function(path) {
  request(paste0(sb_url(), "/rest/v1/", path)) |>
    req_headers(apikey = sb_key(), Authorization = paste("Bearer", sb_key()), Prefer = "return=representation") |>
    req_error(is_error = function(resp) FALSE)
}

sb_perform <- function(req) {
  resp <- req_perform(req)
  if (resp_status(resp) >= 300) {
    body <- tryCatch(resp_body_json(resp, simplifyVector = TRUE), error = function(e) list(message = resp_body_string(resp)))
    stop(body$message %||% paste("Supabase returned HTTP", resp_status(resp)), call. = FALSE)
  }
  if (resp_status(resp) == 204) return(invisible(TRUE))
  resp_body_json(resp, simplifyVector = TRUE)
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

sb_get_events <- function() {
  x <- sb_perform(sb_request("events?select=*&order=event_date.asc,start_sort.asc") |> req_method("GET"))
  as.data.frame(x, stringsAsFactors = FALSE)
}

sb_get_signups <- function() {
  x <- sb_perform(sb_request("signups?select=*&order=event_id.asc,slot_number.asc") |> req_method("GET"))
  if (!length(x)) return(data.frame(signup_id = character(), event_id = integer(), slot_number = integer(), last_name = character()))
  as.data.frame(x, stringsAsFactors = FALSE)
}

sb_claim_slot <- function(event_id, last_name) {
  body <- list(p_event_id = as.integer(event_id), p_last_name = last_name)
  x <- sb_perform(sb_request("rpc/claim_next_slot") |> req_method("POST") |> req_body_json(body, auto_unbox = TRUE))
  if (!length(x)) stop("That event is already full. Refresh to see the latest signups.", call. = FALSE)
  x
}

sb_remove_signup <- function(signup_id) {
  sb_perform(sb_request(paste0("signups?signup_id=eq.", URLencode(signup_id, reserved = TRUE))) |> req_method("DELETE"))
}
