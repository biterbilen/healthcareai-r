#' Build efficient features from from high-cardinality, multiple-membership
#' factors
#'
#' @param d Data frame to use in models, at desired grain. Has id and outcome
#' @param longsheet Data frame containing multiple observations per grain. Has
#'   id and groups
#' @param id Name of identifier column, unquoted. Must be present and identical
#'   in both tables
#' @param groups Name of grouping column, unquoted
#' @param outcome Name of outcome column, unquoted
#' @param n_levels Number of levels to return, default = 100. An attempt is made
#'   to return half levels positively associated with the outcome and half
#'   negatively. If n_levels is greater than the number present, all levels will
#'   be returned
#' @param min_obs Minimum number of observations a level must be found in in
#'   order to be considered. Defaults to one, but larger values are often useful
#'   because a level present in only a few observation will rarely be a useful.
#' @param positive_class If classification model, the positive class of the
#'   outcome, default = "Y"; ignored if regression
#' @param levels Use this argument when add_best_levels was used in training and
#'   you want to add the same columns for deployment. You can pass the model
#'   trained on the data frame from \code{add_best_levels}, the data frame from
#'   \code{add_best_levels}, or a character vector of levels to add.
#' @param fill Passed to \code{\link{pivot}}. Column to be used to fill the
#'   values of cells in the output, perhaps after aggregation by \code{fun}. If
#'   \code{fill} is not provided, counts will be used, as though a fill column
#'   of 1s had been provided.
#' @param fun Passed to \code{\link{pivot}}. Function for aggregation, defaults
#'   to \code{sum}. Custom functions can be used with the same syntax as the
#'   apply family of functions, e.g. \code{fun = function(x)
#'   some_function(another_fun(x))}.
#' @param missing_fill Passed to \code{\link{pivot}}. Value to fill for
#'   combinations of grain and spread that are not present. Defaults to NA, but
#'   0 may be useful as well.
#'
#' @return For \code{add_best_levels}, d with new columns for the best levels
#'   added and best_levels attribute containing a named list of levels added.
#'   For \code{get_best_levels}, a character vector of the best levels.
#' @export
#' @seealso \code{\link{pivot}}
#' @description In healthcare, we are often faced with high cardinality
#'   variables, where each observation may have zero, one, or more levels, e.g.
#'   medications for a model at the patient grain. In these cases, creating a
#'   feature variable for each level (each medication) as in one-hot encoding
#'   can be prohibitively computationally intensive and can hurt performance by
#'   diminishing the signal-to-noise ratio. \code{get_best_levels} identifies a
#'   subset of categories that are likely to be valuable features, and
#'   \code{add_best_levels} adds them to a model data frame.
#'
#'   \code{get_best_levels} finds levels of \code{groups} that are likely to be
#'   useful predictors in \code{d} and returns them as a character vector.
#'   \code{add_best_levels} does the same and adds them, pivoted, to \code{d}.
#'   The function attempts to find both positive and negative predictors of
#'   \code{outcome}.
#'
#'   \code{add_best_levels} stores the identified best levels and passes them
#'   through model training so that in deployment, the same columns created in
#'   training are again created (see the final example).
#'
#'   \code{add_best_levels} accepts arguments to \code{\link{pivot}} so that
#'   values associated with the levels (e.g. doses of medications) can be used
#'   in the new features. However, note that these are not used in determining
#'   the best levels. I.e. \code{get_best_levels} determines which levels are
#'   likely to be good predictors looking only at outcomes where the levels are
#'   present or abssent; it does not use \code{fill} or \code{fun} in this
#'   determination. See \code{details} for more info about how levels are
#'   selected.
#'
#' @details Here is how \code{get_best_levels} determines the levels of
#'   \code{groups} that are likely to be good predictors. \itemize{\item{For
#'   regression: For each group, the difference of the group-mean from the
#'   grand-mean is divided by the standard deviation of the group as a sample
#'   (i.e. centered_mean(group) / sqrt(var(group) / n(group))), and the groups
#'   with the largest absolute values of that statistic are retained.} \item{For
#'   classification: For each group, two "log-loss-like" statistics are
#'   calculated. One is log of the fraction of observations in which the group
#'   does not appear. The other is the log of the difference of the proportion
#'   of different outcomes from all the same outcome (e.g. if 4/5 observations
#'   are positive class, this statistic is log(.2)). To ensure retainment of
#'   both positive- and negative-predictors, the all-same-outcome that is used
#'   as the comparison is determined by which side of the median proportion of
#'   positive_class the group falls on.}}
#'
#' @examples
#' set.seed(45796)
#'
#' # We have two tables we want to use in our models:
#' # - df is the model table. It has the outcomes (survived), and we want one
#' #   prediction for each row in df
#' # - meds has detailed information on each row (patient) in df. Each patient
#' #   may have zero, one, or more observations (drugs) in meds, and meds may
#' #   have associated values (doses).
#'
#' df <- tibble::tibble(
#'   patient = paste0("Z", sample(10, 5)),
#'   age = sample(20:80, 5),
#'   survived = sample(c("N", "Y"), 5, replace = TRUE, prob = c(1, 2))
#' )
#'
#' meds <- tibble::tibble(
#'   patient = sample(df$patient, 10, replace = TRUE),
#'   drug = sample(c("Quinapril", "Vancomycin", "Ibuprofen",
#'                   "Paclitaxel", "Epinephrine", "Dexamethasone"),
#'                 10, replace = TRUE),
#'   dose = sample(c(100, 250), 10, replace = TRUE)
#' )
#'
#' # Identify three drugs likely to be good predictors of survival
#'
#' get_best_levels(d = df,
#'                 longsheet = meds,
#'                 id = patient,
#'                 groups = drug,
#'                 outcome = survived,
#'                 n_levels = 3)
#'
#' # Identify four drugs likely to make good features and add them to df.
#' # The "fill", "fun", and "missing_fill" arguments are passed to
#' # `pivot`, which allows us to use the total doses of each drug given to the
#' # patient as our new features
#'
#' new_df <- add_best_levels(d = df,
#'                           longsheet = meds,
#'                           id = patient,
#'                           groups = drug,
#'                           outcome = survived,
#'                           n_levels = 4,
#'                           fill = dose,
#'                           fun = sum,
#'                           missing_fill = 0)
#' new_df
#'
#' # The names of the medications that were added to df in new_df are stored in the
#' # best_levels attribute of new_df so that the same columns can be added in
#' # deployment. This is useful because you need to have the same columns to make
#' # predictions as you had in model training. When you are ready to add levels to
#' # a deployment data frame, you can pass to the "levels" argument of
#' # add_best_levels either the models trained on new_df, new_df itself, or the
#' # character vector of levels to add.
#'
#' deployment_df <- tibble::tibble(
#'   patient = "p6",
#'   age = 30
#' )
#' deployment_meds <- tibble::tibble(
#'   patient = rep("p6", 2),
#'   drug = rep("Vancomycin", 2),
#'   dose = c(100, 250)
#' )
#'
#' # Now, even though Vancomycin is the only drug that appears in
#' # deployment_meds, because we pass new_df to "levels", we get all the columns
#' # needed to make predictions on a model trained on new_df
#'
#' add_best_levels(d = deployment_df,
#'                 longsheet = deployment_meds,
#'                 id = patient,
#'                 groups = drug,
#'                 levels = new_df,
#'                 fill = dose,
#'                 missing_fill = 0)
add_best_levels <- function(d, longsheet, id, groups, outcome, n_levels = 100,
                            min_obs = 1, positive_class = "Y", levels = NULL,
                            fill, fun = sum, missing_fill = NA) {
  id <- rlang::enquo(id)
  groups <- rlang::enquo(groups)
  outcome <- rlang::enquo(outcome)
  fill <- rlang::enquo(fill)

  add_as_empty <- character()
  if (is.null(levels)) {
    to_add <- get_best_levels(d, longsheet, !!id, !!groups, !!outcome,
                              n_levels, min_obs, positive_class)
  } else {
    levels_name <- paste0(rlang::quo_name(groups), "_levels")
    # If a data frame or model_list was passed to levels, pull levels from it
    if (is.model_list(levels) || is.data.frame(levels)) {
      levels <- attr(levels, "best_levels")[[levels_name]]
      if (is.null(levels))
        stop("Looked for ", levels_name, " as an attribute of ",
             match.call()$levels, " but it was NULL.")
      # If the best_levels list was passed in pull the appropriate element out
    } else if (is.list(levels)) {
      levels <- levels[[levels_name]]
    } else if (!is.character(levels)) {
      stop("You passed a ", class(levels), " to levels. It should be a data frame ",
           "returned from add_best_levels, a model_list trained on such a data frame ",
           "the 'best_levels' attribute from such a data frame, or a character ",
           "vector of levels to use.")
    }
    present_levels <- unique(dplyr::pull(longsheet, !!groups))
    to_add <- levels[levels %in% present_levels]
    add_as_empty <- levels[!levels %in% present_levels]
  }
  longsheet <- dplyr::filter(longsheet, (!!groups) %in% to_add)

  pivot_args <- list(
    d = longsheet,
    grain = eval(id),
    spread = eval(groups),
    fun = fun,
    missing_fill = missing_fill
  )
  if (!missing(fill))
    pivot_args$fill <- eval(fill)
  if (length(add_as_empty))
    pivot_args$extra_cols <- add_as_empty
  pivoted <- do.call(pivot, pivot_args) %>%
    dplyr::left_join(d, ., by = rlang::quo_name(id))
  # Replace any rows not found in the pivot table in the join with missing_fill
  new_cols <- setdiff(names(pivoted), names(d))
  pivoted[new_cols][is.na(pivoted[new_cols])] <- missing_fill
  # Add new best_levels to any that came in on d
  attr(pivoted, "best_levels") <-
    c(attr(d, "best_levels"),
      setNames(list(to_add), paste0(rlang::quo_name(groups), "_levels")))
  return(pivoted)
}

#' @export
#' @rdname add_best_levels
get_best_levels <- function(d, longsheet, id, groups, outcome, n_levels = 100,
                            min_obs = 1, positive_class = "Y") {
  id <- rlang::enquo(id)
  groups <- rlang::enquo(groups)
  outcome <- rlang::enquo(outcome)
  missing_check(d, outcome)
  if (!is.numeric(n_levels) || !is.numeric(min_obs))
    stop("n_levels and min_obs should both be integers")

  tomodel <-
    longsheet %>%
    # Don't want to count the same outcome twice, so only allow one combo of grain x grouper
    dplyr::distinct(!!id, !!groups) %>%
    dplyr::filter(!is.na(!!groups)) %>%
    dplyr::inner_join(d, ., by = rlang::quo_name(id)) %>%
    # Filter any level present in only one grain
    group_by(!!groups) %>%
    filter(n_distinct(!!id) >= min_obs) %>%
    ungroup()

  if (!nrow(tomodel)) {
    warning("No levels present in at least ", min_obs, " observations")
    return(character())
  }

  if (is.numeric(dplyr::pull(tomodel, !!outcome))) {
    # Regression
    # Use the distance from the grand-mean divided by the sample SD to rank predictors
    # Groups with no variance in outcome rise to the top even if they're very small
    tomodel <-
      tomodel %>%
      mutate(!!rlang::quo_name(outcome) := !!outcome - mean(!!outcome)) %>%
      group_by(!!groups) %>%
      summarize(mean_ssd = mean(!!outcome) / sqrt(stats::var(!!outcome) / n())) %>%
      arrange(desc(abs(mean_ssd)))
    tozip <-
      split(tomodel, sign(tomodel$mean_ssd)) %>%
      purrr::map(~ pull(.x, !!groups))
  } else {
    # Classification
    # Using basically the log-loss from being present in all observations and
    # from perfect separation of outcomes. Epislon for present in all is 1/2 a
    # record; for perfect separation is 1/2 an observation.
    total_observations <- n_distinct(dplyr::pull(tomodel, !!id))
    levs <-
      tomodel %>%
      group_by(!!groups) %>%
      summarize(fraction_positive = mean(!!outcome == positive_class),
                # If perfect separation of outcomes, say it got 1/2 of one wrong
                fraction_positive = dplyr::case_when(
                  fraction_positive == 1 ~ 1 - (.5 / total_observations),
                  fraction_positive == 0 ~ .5 / total_observations,
                  TRUE ~ fraction_positive),
                # If level present in every observation, call it every one minus one-half
                present_in = ifelse(n_distinct(!!id) == total_observations,
                                    total_observations - .5, n_distinct(!!id)),
                log_dist_from_in_all = -log(present_in / total_observations)) %>%
      dplyr::select(-present_in)
    median_positive <- stats::median(levs$fraction_positive)
    levs <-
      levs %>%
      mutate(predictor_of = as.integer(fraction_positive > stats::median(fraction_positive)),
             log_loss = - (predictor_of * log(fraction_positive) + (1 - predictor_of) * log(1 - fraction_positive)),
             badness = log_loss * log_dist_from_in_all) %>%
      arrange(badness)
    tozip <-
      split(levs, levs$predictor_of) %>%
      purrr::map(~ pull(.x, !!groups))
  }
  out <-
    if (length(tozip) == 1) {
      tozip[[1]]
    } else {
      zip_vectors(tozip[[1]], tozip[[2]])
    }
  if (length(out) > n_levels)
    out <- out[seq_len(n_levels)]
  return(out)
}

#' Create one vector from two, with each vectors' first element in the first and
#' second positions, the second elements third and fourth, etc.
#' @noRd
zip_vectors <- function(v1, v2) {
  ll <- list(v1, v2)
  lengths <- purrr::map_int(ll, length)
  zipped <-
    lapply(seq_len(min(lengths)), function(i) {
      c(ll[[1]][i], ll[[2]][i])
    }) %>%
    unlist()
  # if they had different lengths, add trailing part of the longer vector
  if (length(unique(lengths)) > 1)
    zipped <- c(zipped, ll[[which.max(lengths)]][(min(lengths) + 1):max(lengths)])
  return(zipped)
}
