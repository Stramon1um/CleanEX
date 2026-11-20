# Test di regressione di CleanEX
#
# Uso (dalla cartella del progetto):
#   Rscript tests/run_tests.R
#
# Il codice dell'app viene estratto direttamente da CleanEX.qmd (chunk shinylive-r),
# quindi i test provano il codice reale. Richiede R con i pacchetti shiny e bslib.
# Esce con stato 1 se almeno un controllo fallisce.
#
# Variabile opzionale CLEANEX_QMD: percorso di un altro .qmd da provare
# (es. una versione precedente, per verificare che i test rilevino i bug).

suppressPackageStartupMessages({ library(shiny); library(bslib) })

# ── Percorsi ──────────────────────────────────────────────────────────────────
this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
root      <- normalizePath(file.path(dirname(this_file), ".."))
qmd       <- Sys.getenv("CLEANEX_QMD", file.path(root, "CleanEX.qmd"))
EXAMPLE   <- file.path(root, "tests", "data", "example_dualex.csv")
stopifnot(file.exists(qmd), file.exists(EXAMPLE))

# ── Carica il codice dell'app (tutto tranne l'ultima riga shinyApp(...)) ──────
q     <- readLines(qmd, encoding = "UTF-8")
start <- grep("^suppressPackageStartupMessages\\(library\\(shiny\\)\\)", q)[1]
end   <- grep("^shinyApp\\(ui, server\\)", q)[1]
stopifnot(!is.na(start), !is.na(end))
eval(parse(text = q[start:(end - 1)]), envir = globalenv())

# ── Mini framework ────────────────────────────────────────────────────────────
N_PASS <- 0L; N_FAIL <- 0L
check <- function(name, ok, detail = "") {
  ok <- tryCatch(isTRUE(ok), error = function(e) { detail <<- paste("errore:", conditionMessage(e)); FALSE })
  if (ok) N_PASS <<- N_PASS + 1L else N_FAIL <<- N_FAIL + 1L
  cat(sprintf("[%s] %s%s\n", if (ok) "PASS" else "FAIL", name,
              if (!ok && nzchar(detail)) paste0("  ->  ", detail) else ""))
}
section <- function(x) cat("\n==", x, "==\n")
# un errore dentro un blocco testServer conta come fallimento (e non interrompe la suite)
app_test <- function(expr) {
  r <- try(expr, silent = TRUE)
  if (inherits(r, "try-error")) {
    N_FAIL <<- N_FAIL + 1L
    cat("[FAIL] errore nel blocco di test  ->  ", trimws(sub("^Error[^:]*:", "", as.character(r))), "\n")
  }
}
guard <- function(expr) tryCatch(expr, error = function(e) paste("ERRORE:", conditionMessage(e)))

write_tmp <- function(txt = NULL, raw = NULL) {
  f <- tempfile(fileext = ".csv")
  if (!is.null(raw)) writeBin(raw, f) else writeBin(charToRaw(txt), f)
  f
}
upload  <- function(path) list(name = basename(path), datapath = path, size = file.size(path), type = "text/csv")
default_cols <- function(rv) { a <- colnames(rv$df_raw); a[!tolower(a) %in% tolower(DEFAULT_DROP)] }
page_html <- function(x) as.character(x$html)
example_txt <- paste(readLines(EXAMPLE), collapse = "\n")
HDR5 <- paste(readLines(EXAMPLE)[1:5], collapse = "\n")

# ══════════════════════════════════════════════════════════════════════════════
section("1. File di esempio: parsing")
ex <- parse_dx_raw(EXAMPLE)
check("24 misure, 15 colonne", nrow(ex) == 24 && ncol(ex) == 15, paste(dim(ex), collapse = "x"))
check("nessuna riga di commento / riepilogo #Groupe nei dati", !any(grepl("^#", ex[[1]])) && all(grepl("^16/07/2026$", ex[[1]])))
check("4 gruppi, 6 misure ciascuno", identical(as.vector(table(ex$groupe)), rep(6L, 4)))
exr <- apply_rename(ex)
check("colonne rinominate (date, time, group, measure)", all(c("date", "time", "group", "measure") %in% colnames(exr)))
check("valori conservati come testo originale (es. '0.151')", exr$Anth[1] == "0.151" && exr$NBI[4] == "NaN")

# ══════════════════════════════════════════════════════════════════════════════
section("2. NaN: un valore non valido non scarta la colonna")
check("4 parametri riconosciuti nonostante i NaN", setequal(get_param_cols(exr), PARAM_COLS), paste(get_param_cols(exr), collapse = ","))
lng <- pivot_long(exr)
check("formato long: 24 x 4 = 96 righe, tutti i parametri", nrow(lng) == 96 && setequal(unique(lng$parameter), PARAM_COLS), paste(nrow(lng), "righe"))
csv_row <- strsplit(df_to_csv_string(exr), "\n")[[1]][5]    # riga con NaN in NBI
check("CSV: numeri e NaN senza virgolette", grepl(",NaN,", csv_row) && !grepl('"NaN"', csv_row) && !grepl('"[0-9]+\\.[0-9]+"', csv_row), csv_row)
ext <- exr; ext$treatment <- ext$group
mm <- compute_mean_se(ext, "NBI")
check("medie ed SE ignorano i NaN (nessun NA/NaN)", !is.null(mm) && all(is.finite(mm$mean)) && all(is.finite(mm$se)))
for (tok in c("NaN", "nan", "NA", "---")) {
  d <- data.frame(NBI = c("30.2", tok, "31.0"), stringsAsFactors = FALSE)
  check(sprintf("un solo '%s' in NBI: resta parametro", tok), "NBI" %in% get_param_cols(d))
}
check("testo vero in una colonna: NON è un parametro", !"NBI" %in% get_param_cols(data.frame(NBI = c("30.2", "abc"), stringsAsFactors = FALSE)))
check("to_num: mai NaN/Inf, solo NA", all(is.na(to_num(c("NaN", "", "x", "Inf")))) && to_num(" 3.5 ") == 3.5)

# ══════════════════════════════════════════════════════════════════════════════
section("3. Parsing: varianti di formato")
n_ok <- function(txt = NULL, raw = NULL) { r <- guard(parse_dx_raw(write_tmp(txt, raw))); if (is.data.frame(r)) nrow(r) else r }
check("CRLF", identical(n_ok(gsub("\n", "\r\n", example_txt, fixed = TRUE)), 24L))
check("solo CR", identical(n_ok(gsub("\n", "\r", example_txt, fixed = TRUE)), 24L))
check("byte nullo nella riga #Model (come il Dualex reale)", identical(n_ok(raw = append(charToRaw(example_txt), as.raw(0), after = 15)), 24L))
check("UTF-8 con BOM", identical(n_ok(raw = c(as.raw(c(0xEF, 0xBB, 0xBF)), charToRaw(example_txt))), 24L))
u16 <- c(as.raw(c(0xFF, 0xFE)), iconv(example_txt, "UTF-8", "UTF-16LE", toRaw = TRUE)[[1]])
check("UTF-16LE con BOM", identical(n_ok(raw = u16), 24L), as.character(n_ok(raw = u16)))
lat <- charToRaw(iconv(sub("Model.......", "Modèle.....", example_txt), "UTF-8", "latin1"))
check("byte Latin-1 (è) nei metadati", identical(n_ok(raw = lat), 24L), as.character(n_ok(raw = lat)))
check("firmware inglese '#Group': il riepilogo non entra nei dati", identical(n_ok(gsub("#Groupe", "#Group", example_txt, fixed = TRUE)), 24L))
check("blocco #Groupe senza riga vuota: nessuna misura persa", identical(n_ok(gsub("\n\n", "\n", example_txt, fixed = TRUE)), 24L))
short <- paste0(HDR5, "\n16/07/2026;09:58:15;;;;;28.11;1;1;sup;38.675\n")
r <- guard(parse_dx_raw(write_tmp(short))); check("riga troncata: padding, 15 colonne", is.data.frame(r) && ncol(r) == 15 && r$Flav == "")
check("file troppo corto -> err_not_dualex", identical(guard(parse_dx_raw(write_tmp("#a\n#b\n"))), "ERRORE: err_not_dualex"))
check("CSV non-Dualex -> err_not_dualex", identical(guard(parse_dx_raw(write_tmp("a,b,c\n1,2,3\n4,5,6\n7,8,9\n1,2,3\n1,2,3\n"))), "ERRORE: err_not_dualex"))
check("solo intestazione -> err_no_data", identical(guard(parse_dx_raw(write_tmp(paste0(HDR5, "\n")))), "ERRORE: err_no_data"))
check("file vuoto -> errore gestito", grepl("err_", guard(parse_dx_raw(write_tmp("")))))
dec_txt <- gsub("(\\d)\\.(\\d)", "\\1,\\2", example_txt)
check("virgola decimale rilevata", has_decimal_comma(apply_rename(parse_dx_raw(write_tmp(dec_txt)))))
check("punto decimale: nessun falso avviso", !has_decimal_comma(exr))
tr_keys <- lapply(TR, names)
check("dizionario IT/EN/ES/FR con le stesse chiavi", length(unique(lapply(tr_keys, sort))) == 1)
check("errori tradotti in tutte le lingue", all(vapply(names(TR), function(l) all(vapply(c("err_not_dualex", "err_no_data", "err_no_cols"), function(k) !identical(err_text(TR[[l]], k), k), logical(1))), logical(1))))

# ══════════════════════════════════════════════════════════════════════════════
section("4. Date e ordinamento")
for (x in list(c("16/07/2026", "6/7/2026"), c("2026-07-16", "2026-07-06"), c("16.07.2026", "06.07.2026"), c("16-07-2026", "06-07-2026")))
  check(paste("formato data", x[1]), !anyNA(parse_dx_date(x)))
check("anno a 2 cifre = 2026 (non 0026)", format(parse_dx_date("16/07/26"), "%Y") == "2026")
m <- data.frame(date = c("16/07/26", "30/06/2026"), time = "10:00:00", v = 1:2, stringsAsFactors = FALSE)
check("dd/mm/yy e dd/mm/yyyy ordinati insieme", identical(sort_chrono(m)$v, c(2L, 1L)))
dd <- data.frame(date = c("16/07/2026", "", "15/07/2026"), time = "10:00:00", v = 1:3, stringsAsFactors = FALSE)
check("data mancante: righe valide ordinate, quella senza data in fondo", identical(sort_chrono(dd)$v, c(3L, 1L, 2L)))
check("ordine per ora (9:05:03 < 09:59:59 < 10:00:00)", identical(sort_chrono(data.frame(date = "16/07/2026", time = c("9:05:03", "10:00:00", "09:59:59"), v = 1:3, stringsAsFactors = FALSE))$v, c(1L, 3L, 2L)))
check("natural_sort: 3 < 10, T2 < T10", identical(natural_sort(c("10", "3", "11", "4")), c("3", "4", "10", "11")) && identical(natural_sort(c("T10", "T2", "t1")), c("t1", "T2", "T10")))

# ══════════════════════════════════════════════════════════════════════════════
section("5. CSV: scrittura e rilettura")
nasty <- c("Ctrl, low N", 'He said "hi"', "a;b", " lead", "trail ", "é à ü 日本語", "a\nb", "NA", "TRUE", "1e3", "C1")
df <- data.frame(date = "16/07/2026", group = as.character(seq_along(nasty)), treatment = nasty,
                 Chl = sprintf("%.3f", seq_along(nasty) / 7), NBI = rep(c("30.1", "NaN"), length.out = length(nasty)), stringsAsFactors = FALSE)
f <- tempfile(fileext = ".csv"); writeLines(df_to_csv_string(df), f, useBytes = TRUE)
check("round-trip identico (virgole, apici, newline, unicode, colonna con NaN)", identical(read_cleanex_csv(f), df))
d0 <- data.frame(a = c("28.0", "1.50", "007"), stringsAsFactors = FALSE); f0 <- tempfile(); writeLines(df_to_csv_string(d0), f0)
check("zeri finali e iniziali preservati", identical(read_cleanex_csv(f0)$a, d0$a))
check("NA scritti come campo vuoto", !grepl("NA", df_to_csv_string(data.frame(a = c("1", NA), t = c("x", NA), stringsAsFactors = FALSE))))
check("data frame con 0 righe", is.character(guard(df_to_csv_string(data.frame(x = character(0))))))
bom <- tempfile(); writeBin(c(as.raw(c(0xEF, 0xBB, 0xBF)), charToRaw(paste0(df_to_csv_string(df[1:2, ]), "\n"))), bom)
check("BOM UTF-8 nel CSV da Excel", "date" %in% colnames(read_cleanex_csv(bom)))

# ══════════════════════════════════════════════════════════════════════════════
section("6. Grafico: casi limite")
draw <- function(df, params = "P", ...) {
  f <- tempfile(fileext = ".png"); png(f, width = 5.2, height = 4.6, units = "in", res = 60); w <- character()
  r <- withCallingHandlers(tryCatch({ draw_bar_chart(df, params, ...); "ok" }, error = function(e) paste("ERRORE:", conditionMessage(e))),
                           warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") })
  dev.off(); list(res = r, warn = w)
}
mk <- function(v, trt = rep(c("A", "B"), each = 5)) data.frame(treatment = trt, P = as.character(v), stringsAsFactors = FALSE)
r <- draw(mk(rep(0, 10)));                 check("tutti zero: nessun errore né warning", r$res == "ok" && !length(r$warn), paste(r$warn, collapse = ";"))
set.seed(1); r <- draw(mk(round(c(rnorm(5, -.3, .05), rnorm(5, -.1, .05)), 3))); check("tutti negativi", r$res == "ok" && !length(r$warn))
r <- draw(mk(c(.2, .1, -.15, -.2, .35, .3, .4, .2, .1, .3)), show_jitter = TRUE);  check("valori misti +/- con punti", r$res == "ok")
check("1 trattamento, 30 trattamenti, tutto NA, con NaN, trattamento NA",
      all(c(draw(mk(1:10, rep("A", 10)))$res, draw(mk(runif(30), paste0("T", 1:30)))$res, draw(mk(rep(NA, 10)))$res,
            draw(mk(c(1, 2, NaN, 4, 5, 6, 7, NaN, 9, 10)))$res, draw(mk(c(1, NA, 3, NA, 5, 6, 7, 8, 9, 10), c("A", NA, "A", "B", "B", "B", "A", "A", "B", "B")))$res) == "ok"))
dfn <- data.frame(treatment = as.character(c(3, 10, 4, 11, 3, 10, 4, 11)), P = as.character(1:8), stringsAsFactors = FALSE)
check("ordine dei trattamenti naturale (3, 4, 10, 11)", identical(compute_mean_se(dfn, "P")$treatment, c("3", "4", "10", "11")))
lg <- data.frame(treatment = rep(c("A", "B"), each = 4), parameter = rep(c("P", "Q"), 4), value = c("1", "10", "2", "20", "3", "30", "NaN", "40"), stringsAsFactors = FALSE)
check("grafico dal long: parametri separati, NaN ignorato", identical(compute_mean_se(lg, "P")$mean, c(1.5, 3)) && identical(compute_mean_se(lg, "Q")$mean, c(15, 35)))

# ══════════════════════════════════════════════════════════════════════════════
section("7. App (server Shiny reale): flusso completo sul file di esempio")
app_test(testServer(server, {
  session$setInputs(ui_lang = "it", file_in = upload(EXAMPLE))
  check("caricamento: 24 misure", !is.null(rv$df_raw) && nrow(rv$df_raw) == 24)
  check("pannelli dei passi 1-2 renderizzano", guard({ output$step1_panel; output$col_selector_panel; "ok" }) == "ok")
  session$setInputs(selected_cols = default_cols(rv), clean_btn = 1)
  check("pulizia: colonne attese", identical(colnames(rv$df_clean), c("date", "time", "temp", "group", "measure", "face", "Chl", "Flav", "Anth", "NBI")))
  check("gruppi ordinati", identical(rv$groups, as.character(1:4)))
  session$setInputs(trt_edit = list(g = "1", v = "Controllo, N basso"), trt_btn = 1)
  check("trattamenti: nome assegnato / numero del gruppo se vuoto", rv$df_trt$treatment[rv$df_trt$group == "1"][1] == "Controllo, N basso" && rv$df_trt$treatment[rv$df_trt$group == "3"][1] == "3" && is.null(names(rv$df_trt$treatment)))
  session$setInputs(pivot_long = TRUE, pivot_btn = 1)
  check("long: 96 righe con tutti e 4 i parametri", nrow(rv$df_final) == 96 && setequal(unique(rv$df_final$parameter), PARAM_COLS))
  check("pannelli dei passi 3-7 renderizzano", guard({ output$preview_panel; output$treatment_panel; output$pivot_panel; output$final_preview_wrap; output$chart_panel; output$merge_panel; "ok" }) == "ok")
  check("il pannello grafico offre tutti i parametri", all(vapply(PARAM_COLS, function(p) grepl(paste0('data-param="', p, '"'), page_html(output$chart_panel)), logical(1))))
  session$setInputs(chart_params = PARAM_COLS, show_jitter = TRUE, chart_btn = 1)
  check("grafico PNG generato e valido", !is.null(rv$chart_png_b64) && identical(jsonlite::base64_dec(rv$chart_png_b64)[1:4], as.raw(c(0x89, 0x50, 0x4E, 0x47))))
  check("nessun device grafico rimasto aperto", length(dev.list()) == 0)
  n <- nrow(rv$df_final); session$setInputs(ui_lang = "fr")
  check("cambio lingua: dati e trattamenti conservati, testi FR renderizzano", nrow(rv$df_final) == n && identical(rv$trt_vals[["1"]], "Controllo, N basso") && guard({ output$app_subtitle; output$status_badge; "ok" }) == "ok")
  f <- tempfile(fileext = ".csv"); writeLines(df_to_csv_string(rv$df_final), f)
  session$setInputs(merge_file_in = upload(f), merge_btn = 1)
  check("merge con lo stesso file: avviso duplicati (96 righe)", rv$merge_warn == 96 && !is.null(rv$df_merged) && nrow(rv$df_merged) == 192)
  session$setInputs(file_in = upload(EXAMPLE))
  check("nuovo file caricato: stato precedente azzerato", is.null(rv$df_final) && is.null(rv$df_merged) && length(rv$trt_vals) == 0 && rv$merge_warn == 0L)
}))
section("8. App: formato wide, merge fra sessioni, selezioni anomale")
app_test(testServer(server, {
  session$setInputs(ui_lang = "en", file_in = upload(EXAMPLE))
  session$setInputs(selected_cols = default_cols(rv), clean_btn = 1, trt_btn = 1, pivot_long = FALSE, pivot_btn = 1)
  check("wide: 24 righe", nrow(rv$df_final) == 24 && !"parameter" %in% colnames(rv$df_final))
  session$setInputs(chart_params = c("Flav", "Anth", "NBI"), show_jitter = FALSE, chart_btn = 1)
  check("grafico wide con NaN (Flav, Anth, NBI)", !is.null(rv$chart_png_b64))
  # seconda sessione con data diversa e trattamento diverso -> nessun avviso, ordine cronologico
  other <- write_tmp(gsub("16/07/2026", "30/06/2026", example_txt, fixed = TRUE))
  prev <- tempfile(fileext = ".csv")
  cur <- rv$df_final; writeLines(df_to_csv_string(cur), prev)
  session$setInputs(file_in = upload(other))
  session$setInputs(selected_cols = default_cols(rv), clean_btn = 2, trt_btn = 2, pivot_btn = 2, merge_file_in = upload(prev), merge_btn = 1)
  check("merge fra sessioni diverse: nessun avviso, 48 righe, ordine cronologico",
        rv$merge_warn == 0L && nrow(rv$df_merged) == 48 && !is.unsorted(as.Date(rv$df_merged$date, "%d/%m/%Y")) && rv$df_merged$date[1] == "30/06/2026")
  prev_long <- tempfile(fileext = ".csv"); writeLines(df_to_csv_string(pivot_long(cur)), prev_long)
  session$setInputs(merge_file_in = upload(prev_long), merge_btn = 2)
  check("merge wide + long: errore colonne, nessun crash", !is.null(rv$merge_error) && is.null(rv$df_merged))
}))
app_test(testServer(server, {      # righe identiche nel long dopo aver deselezionato data/ora/misura/temp
  session$setInputs(ui_lang = "en", file_in = upload(EXAMPLE))
  sel <- setdiff(colnames(rv$df_raw), c(DEFAULT_DROP, "jj/mm/aaaa", "hh:mm:ss", "mesure", "temp"))
  session$setInputs(selected_cols = sel, clean_btn = 1, trt_btn = 1, pivot_long = TRUE, pivot_btn = 1)
  check("medie dal long = medie dal wide (nessuna riga collassata)", isTRUE(all.equal(compute_mean_se(rv$df_trt, "Chl"), compute_mean_se(rv$df_final, "Chl"))))
}))
app_test(testServer(server, {
  session$setInputs(ui_lang = "it", file_in = upload(EXAMPLE))
  session$setInputs(selected_cols = character(0), clean_btn = 1)
  check("'Deseleziona tutte' + Pulisci: errore, non colonne di default", identical(rv$error, "err_no_cols") && is.null(rv$df_clean) && grepl("Nessuna colonna selezionata", page_html(output$preview_panel)))
  session$setInputs(selected_cols = list(), clean_btn = 2)
  check("lista vuota (come la invia il JavaScript): stesso errore", identical(rv$error, "err_no_cols"))
  session$setInputs(selected_cols = default_cols(rv), clean_btn = 3)
  check("riselezionando le colonne la pulizia riparte", !is.null(rv$df_clean) && is.null(rv$error))
}))
app_test(testServer(server, {
  session$setInputs(ui_lang = "en", file_in = upload(EXAMPLE))
  session$setInputs(selected_cols = setdiff(colnames(rv$df_raw), c(DEFAULT_DROP, "groupe")), clean_btn = 1)
  check("'groupe' deselezionata: avviso visibile", is.null(rv$groups) && grepl("group column", page_html(output$preview_panel), ignore.case = TRUE))
}))
app_test(testServer(server, {
  session$setInputs(ui_lang = "en", file_in = upload(EXAMPLE))
  session$setInputs(selected_cols = setdiff(colnames(rv$df_raw), c(DEFAULT_DROP, "mesure")), clean_btn = 1)
  h <- page_html(output$preview_panel)
  check("rinomine mostrate solo per le colonne tenute", !grepl("mesure", h) && grepl("jj/mm/aaaa", h))
}))
for (lg in c("it", "en", "es", "fr")) app_test(testServer(server, {
  session$setInputs(ui_lang = lg, file_in = upload(write_tmp("a,b,c\n1,2,3\n4,5,6\n7,8,9\n1,2,3\n1,2,3\n")))
  check(paste("file non-Dualex, lingua", lg, "-> errore tradotto"), identical(rv$error, "err_not_dualex") && is.null(rv$df_raw) && grepl(TR[[lg]]$err_not_dualex, page_html(output$preview_panel), fixed = TRUE))
}))
app_test(testServer(server, {
  dec <- write_tmp(gsub("(\\d)\\.(\\d)", "\\1,\\2", example_txt))
  session$setInputs(ui_lang = "en", file_in = upload(dec))
  check("virgola decimale: avviso nel riquadro del file", isTRUE(rv$decimal_warn) && grepl("Decimal comma", page_html(output$file_info_chip)))
}))
app_test(testServer(server, {
  blank <- write_tmp(paste0(HDR5, "\n16/07/2026;10:00:00;;;;;28.1;1;1;sup;38.6;1.2;0.1;30.2;NEW\n16/07/2026;10:00:05;;;;;28.1;;2;sup;38.9;1.3;0.1;31.2;\n16/07/2026;10:00:10;;;;;28.1;2;1;sup;40.1;1.4;0.1;32.2;\n"))
  session$setInputs(ui_lang = "en", file_in = upload(blank))
  session$setInputs(selected_cols = default_cols(rv), clean_btn = 1, trt_btn = 1)
  check("gruppo vuoto: nessun treatment NA", !anyNA(rv$df_trt$treatment), paste(rv$df_trt$treatment, collapse = "|"))
  check("nome per il gruppo vuoto: nessun errore", guard({ session$setInputs(trt_edit = list(g = "", v = "X")); "ok" }) == "ok")
}))

# ══════════════════════════════════════════════════════════════════════════════
section("9. Dati di esempio incorporati nell'app (pulsante 'Prova con dati di esempio')")
check("EXAMPLE_DUALEX identico a tests/data/example_dualex.csv", identical(EXAMPLE_DUALEX, readLines(EXAMPLE, encoding = "UTF-8")))
check("il link compare nel passo 1, in tutte le lingue", {
  ok <- TRUE
  for (lg in c("it", "en", "es", "fr")) testServer(server, { session$setInputs(ui_lang = lg); ok <<- ok && grepl("example_btn", page_html(output$step1_panel)) && grepl(TR[[lg]]$example_btn, page_html(output$step1_panel), fixed = TRUE) })
  ok })
app_test(testServer(server, {
  session$setInputs(ui_lang = "en")
  check("all'avvio nessun dato caricato (il link non scatta da solo)", is.null(rv$df_raw) && !isTRUE(rv$is_example))
  session$setInputs(example_btn = 1)
  check("esempio: 24 misure, nome 'example_dualex', avviso 'sintetici' visibile", !is.null(rv$df_raw) && nrow(rv$df_raw) == 24 && rv$base_name == "example_dualex" && isTRUE(rv$is_example) &&
          grepl(TR$en$example_note, page_html(output$file_info_chip), fixed = TRUE) && grepl("example_dualex.csv", page_html(output$file_info_chip), fixed = TRUE))
  session$setInputs(selected_cols = default_cols(rv), clean_btn = 1, trt_btn = 1, pivot_long = TRUE, pivot_btn = 1)
  check("flusso completo sull'esempio: long con 96 righe e 4 parametri", nrow(rv$df_final) == 96 && setequal(unique(rv$df_final$parameter), PARAM_COLS))
  session$setInputs(chart_params = PARAM_COLS, show_jitter = FALSE, chart_btn = 1)
  check("grafico generato dall'esempio", !is.null(rv$chart_png_b64))
  session$setInputs(example_btn = 2)
  check("ricaricando l'esempio lo stato a valle viene azzerato", is.null(rv$df_final) && is.null(rv$chart_png_b64) && nrow(rv$df_raw) == 24)
  session$setInputs(file_in = upload(EXAMPLE))
  check("caricando un file l'avviso 'esempio' sparisce e compare il nome del file", !isTRUE(rv$is_example) && !grepl(TR$en$example_note, page_html(output$file_info_chip), fixed = TRUE) && grepl("example_dualex.csv", page_html(output$file_info_chip), fixed = TRUE))
}))

# ══════════════════════════════════════════════════════════════════════════════
cat(sprintf("\n==== %d superati, %d falliti ====\n", N_PASS, N_FAIL))
if (N_FAIL > 0) quit(status = 1)
