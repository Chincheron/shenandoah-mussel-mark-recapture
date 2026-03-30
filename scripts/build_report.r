# =============================================================================
# Script: build_report.r
#
# Purpose: Automation of rendering quatro documents to word version of report 
# =============================================================================

library(quarto)

quarto_render("doc/Methods/report.qmd", output_file = "shenandoah_mark_recapture_methods_results_v0.1")