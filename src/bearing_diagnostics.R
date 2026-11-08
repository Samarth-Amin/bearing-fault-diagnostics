# ==============================================================================
# ROTARY MACHINERY VIBRATION DIAGNOSTICS & CONDITION-BASED MAINTENANCE PIPELINE
# Multi-Stage Automated Bearing Health Assessment & Demodulation Engine
# Dataset: CWRU Bearing Data Center (48 kHz Sampling Rate, Drive-End Accelerometer)
# Bearing Model: SKF 6205-2RS Deep Groove Ball Bearing
# Operational Loads: 0 hp (No Load ~1796 RPM) & 3 hp (Full Load ~1725 RPM)
# ==============================================================================

# Required Libraries
suppressPackageStartupMessages({
  library(R.matlab)
  library(seewave)
  library(ggplot2)
})

# ------------------------------------------------------------------------------
# 1. CONFIGURATION & AUTOMATED DATA PATH RESOLUTION
# ------------------------------------------------------------------------------
LOADS <- c("0hp", "3hp")   # Full dual-load evaluation (0 hp & 3 hp)
FS    <- 48000             # Sampling frequency (48 kHz)

# Resolve data directory (checks local data folder, parent folders, or test rig archives)
find_data_dir <- function() {
  candidates <- c(
    "data",
    "./data",
    "../data",
    file.path("..", "data"),
    file.path("..", "EXP 7"),
    file.path(".", "EXP 7")
  )
  for (path in candidates) {
    if (dir.exists(path)) return(normalizePath(path, winslash = "/"))
  }
  stop("Bearing dataset directory not found. Please place dataset in 'data/' folder.")
}

DATA_DIR <- find_data_dir()
cat(">>> Found Bearing Data Directory at:", DATA_DIR, "\n")
cat(">>> Executing Multi-Load Analysis for:", paste(LOADS, collapse = " & "), "at", FS, "Hz sampling rate\n\n")

# ------------------------------------------------------------------------------
# 2. BEARING KINEMATICS CALCULATOR (SKF 6205)
# ------------------------------------------------------------------------------
# Bearing Parameters:
Nb   <- 9            # Number of rolling elements (balls)
Bd   <- 7.94         # Ball diameter (mm)
Pd   <- 39.04        # Pitch circle diameter (mm)
beta <- 0            # Contact angle (radians, 0 degrees for deep groove)
gamma <- (Bd * cos(beta)) / Pd  # Dimensionless geometry ratio (~0.2034)

calc_kinematic_freqs <- function(rpm) {
  fr <- rpm / 60
  list(
    fr   = fr,                                           # Shaft Speed (Hz)
    BPFO = (Nb * fr / 2) * (1 - gamma),                  # Ball Pass Freq Outer Race (~3.585 * fr)
    BPFI = (Nb * fr / 2) * (1 + gamma),                  # Ball Pass Freq Inner Race (~5.415 * fr)
    BSF  = (Pd * fr / (2 * Bd)) * (1 - gamma^2),         # Ball Spin Frequency (~2.357 * fr)
    FTF  = (fr / 2) * (1 - gamma)                        # Fundamental Train / Cage Freq (~0.398 * fr)
  )
}

# ------------------------------------------------------------------------------
# 3. STATISTICAL CONDITION INDICATORS (TIME-DOMAIN SCREENING)
# ------------------------------------------------------------------------------
rms <- function(x) {
  sqrt(mean(x^2))
}

skewness <- function(x) {
  n <- length(x); m <- mean(x); s <- sd(x)
  sum((x - m)^3 / ((n - 1) * s^3))
}

kurtosis <- function(x) {
  n <- length(x); m <- mean(x); s <- sd(x)
  sum((x - m)^4 / ((n - 1) * s^4))
}

crest_factor <- function(x) {
  max(abs(x)) / rms(x)
}

form_factor <- function(x) {
  rms(x) / mean(abs(x))
}

extract_features <- function(x) {
  c(
    RMS         = rms(x),
    Kurtosis    = kurtosis(x),
    CrestFactor = crest_factor(x),
    Skewness    = skewness(x),
    FormFactor  = form_factor(x),
    PeakToPeak  = max(x) - min(x),
    StdDev      = sd(x)
  )
}

# ------------------------------------------------------------------------------
# 4. SMART SIGNAL LOADER HELPER
# ------------------------------------------------------------------------------
load_cwru_mat <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(paste("File does not exist:", file_path))
  }
  mat <- readMat(file_path)
  
  # Find Drive End (DE) acceleration channel
  de_key <- grep("DE(\\.time|_time)", names(mat), value = TRUE)
  if (length(de_key) == 0) {
    stop(paste("No Drive-End (DE) channel found in:", file_path))
  }
  signal <- as.vector(mat[[de_key[1]]])
  
  # Find actual motor RPM
  rpm_key <- grep("RPM", names(mat), value = TRUE)
  rpm <- if (length(rpm_key) > 0) as.numeric(mat[[rpm_key[1]]][1, 1]) else NA
  
  return(list(signal = signal, rpm = rpm))
}

# ------------------------------------------------------------------------------
# 5. DUAL-LOAD PIPELINE EXECUTION (0 HP & 3 HP)
# ------------------------------------------------------------------------------
severities  <- c("0.007", "0.014", "0.021")
fault_types <- c("OuterRace" = "OR", "InnerRace" = "IR", "Ball" = "Ball")

time_stats_list <- list()
diag_results    <- list()
env_spectra     <- list()

for (current_load in LOADS) {
  cat(paste0("\n=== PROCESSING MOTOR LOAD: ", current_load, " ===\n"))
  
  # Load Healthy Baseline for current load
  healthy_file <- file.path(DATA_DIR, "Healthy_data", paste0(current_load, ".mat"))
  healthy_data <- load_cwru_mat(healthy_file)
  healthy_sig  <- healthy_data$signal
  healthy_rpm  <- if (!is.na(healthy_data$rpm)) healthy_data$rpm else (if (current_load == "0hp") 1796 else 1725)
  
  # Compute theoretical kinematic frequencies
  kin_base <- calc_kinematic_freqs(healthy_rpm)
  cat(sprintf("  Healthy Baseline: %d RPM | fr = %.2f Hz\n", round(healthy_rpm), kin_base$fr))
  cat(sprintf("  BPFO: %.2f Hz | BPFI: %.2f Hz | 2xBSF: %.2f Hz | FTF: %.2f Hz\n",
              kin_base$BPFO, kin_base$BPFI, 2 * kin_base$BSF, kin_base$FTF))
  
  # Record Healthy Baseline in results
  h_feats <- extract_features(healthy_sig)
  time_stats_list[[length(time_stats_list) + 1]] <- data.frame(
    Motor_Load = current_load, Condition = "Healthy", Severity = "0.000",
    t(h_feats), stringsAsFactors = FALSE
  )
  
  # Store Healthy spectrum for 0.007 comparison
  h_spec <- spec(healthy_sig[1:50000] - mean(healthy_sig[1:50000]), f = FS, flim = c(0, 0.4), plot = FALSE)
  env_spectra[[paste(current_load, "Healthy", sep = "_")]] <- data.frame(
    Freq = h_spec[, 1] * 1000, Amp = h_spec[, 2], Condition = "Healthy Baseline", Motor_Load = current_load, Fault_Freq = NA
  )
  
  # Process all severities (0.007", 0.014", 0.021") and fault types
  for (sev in severities) {
    for (f_label in names(fault_types)) {
      f_code <- fault_types[[f_label]]
      mat_file <- file.path(DATA_DIR, current_load, "48k", sev, paste0(f_code, ".mat"))
      
      loaded <- load_cwru_mat(mat_file)
      sig <- loaded$signal
      rpm <- if (!is.na(loaded$rpm)) loaded$rpm else healthy_rpm
      kin <- calc_kinematic_freqs(rpm)
      
      # --- LEVEL 1: Time-Domain Statistical Screening ---
      feats <- extract_features(sig)
      time_stats_list[[length(time_stats_list) + 1]] <- data.frame(
        Motor_Load = current_load, Condition = f_label, Severity = sev,
        t(feats), stringsAsFactors = FALSE
      )
      
      # --- LEVEL 2: High-Frequency Resonance Demodulation (HFRT) & Envelope Spectrum ---
      sig_sub <- sig[1:min(50000, length(sig))]
      e <- env(sig_sub, f = FS, plot = FALSE)
      env_sig <- e[, 1]
      env_detrend <- env_sig - mean(env_sig)
      
      spec_out <- spec(env_detrend, f = FS, flim = c(0, 1), plot = FALSE)
      freq_hz  <- spec_out[, 1] * 1000
      amp      <- spec_out[, 2]
      
      theo_freq <- switch(f_label,
        "OuterRace" = kin$BPFO,
        "InnerRace" = kin$BPFI,
        "Ball"      = 2 * kin$BSF
      )
      
      # Store 0.007 spectrum for multi-panel comparison plot
      if (sev == "0.007") {
        key_name <- paste(current_load, f_label, sep = "_")
        env_spectra[[key_name]] <- data.frame(
          Freq = freq_hz, Amp = amp, Condition = f_label, Motor_Load = current_load, Fault_Freq = theo_freq
        )
      }
      
      # Search in targeted window around theoretical frequency (+/- 8 Hz)
      win_mask <- (freq_hz >= theo_freq - 8) & (freq_hz <= theo_freq + 8)
      sub_freq <- freq_hz[win_mask]
      sub_amp  <- amp[win_mask]
      detected_freq <- sub_freq[which.max(sub_amp)]
      peak_amp <- max(sub_amp)
      
      surround_mask <- (freq_hz >= theo_freq - 30) & (freq_hz <= theo_freq + 30) & (!win_mask)
      noise_floor <- mean(amp[surround_mask])
      snr <- if (noise_floor > 0) peak_amp / noise_floor else 1.0
      
      error_pct <- abs(detected_freq - theo_freq) / theo_freq * 100
      is_detected <- (error_pct <= 2.0) && (snr >= 2.5)
      
      diag_results[[length(diag_results) + 1]] <- data.frame(
        Motor_Load        = current_load,
        Condition         = f_label,
        Severity_in       = paste0(sev, "\""),
        RPM               = round(rpm),
        RMS               = round(feats["RMS"], 4),
        Kurtosis          = round(feats["Kurtosis"], 2),
        CrestFactor       = round(feats["CrestFactor"], 2),
        Theoretical_Hz    = round(theo_freq, 2),
        Detected_Peak_Hz  = round(detected_freq, 2),
        Freq_Error_Pct    = round(error_pct, 2),
        SNR_Ratio         = round(snr, 1),
        Diagnostic_Status = if (is_detected) "DETECTED" else "NOT DETECTED",
        stringsAsFactors  = FALSE
      )
    }
  }
}

# Combine Results
stats_df <- do.call(rbind, time_stats_list)
stats_df$Severity_Num <- as.numeric(stats_df$Severity)
cbm_matrix <- do.call(rbind, diag_results)

# ------------------------------------------------------------------------------
# 6. RESULTS OUTPUT & CSV EXPORT
# ------------------------------------------------------------------------------
cat("\n=================================================================================================\n")
cat("                BEARING CONDITION MONITORING & FAULT DIAGNOSTICS SUMMARY MATRIX                  \n")
cat("=================================================================================================\n")
print(cbm_matrix, row.names = FALSE)
cat("=================================================================================================\n\n")

if (!dir.exists("results/tables")) dir.create("results/tables", recursive = TRUE)
write.csv(cbm_matrix, file = "results/tables/CBM_Diagnostic_Summary.csv", row.names = FALSE)
cat(">>> Saved results table to 'results/tables/CBM_Diagnostic_Summary.csv'\n\n")

# ------------------------------------------------------------------------------
# 7. HIGH-RESOLUTION DIAGNOSTIC VISUALIZATIONS (0 HP vs 3 HP)
# ------------------------------------------------------------------------------
if (!dir.exists("results/plots")) dir.create("results/plots", recursive = TRUE)

# --- FIGURE 1: Kurtosis vs Severity Across 0hp & 3hp ---
p1 <- ggplot(stats_df[stats_df$Condition != "Healthy", ], 
             aes(x = Severity_Num, y = Kurtosis, color = Condition, shape = Motor_Load, group = interaction(Condition, Motor_Load))) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 3.0, linetype = "dashed", color = "black", alpha = 0.6) +
  facet_wrap(~ Motor_Load) +
  scale_color_manual(values = c("OuterRace" = "red", "InnerRace" = "blue", "Ball" = "darkorange")) +
  labs(
    title = "Fault Severity Progression: Kurtosis Across Operating Loads (0 hp vs 3 hp)",
    subtitle = "Kurtosis provides early shock-pulse warning, spiking sharply at 0.007\"",
    x = "Defect Diameter (inches)",
    y = "Kurtosis"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "top")

# --- FIGURE 2: RMS vs Severity Across 0hp & 3hp ---
p2 <- ggplot(stats_df[stats_df$Condition != "Healthy", ], 
             aes(x = Severity_Num, y = RMS, color = Condition, shape = Motor_Load, group = interaction(Condition, Motor_Load))) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3) +
  facet_wrap(~ Motor_Load) +
  scale_color_manual(values = c("OuterRace" = "red", "InnerRace" = "blue", "Ball" = "darkorange")) +
  labs(
    title = "Fault Severity Progression: Overall Vibration RMS Across Operating Loads",
    subtitle = "RMS scales monotonically with gross surface spall progression",
    x = "Defect Diameter (inches)",
    y = "Overall Acceleration RMS (g)"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "top")

ggsave("results/plots/Severity_Kurtosis_Trend.png", plot = p1, width = 9, height = 5, dpi = 300)
ggsave("results/plots/Severity_RMS_Trend.png", plot = p2, width = 9, height = 5, dpi = 300)
cat(">>> Saved 'results/plots/Severity_Kurtosis_Trend.png' and 'Severity_RMS_Trend.png'\n")

# --- FIGURE 3: Multi-Panel Envelope Spectra Comparison (0 hp vs 3 hp) ---
spectra_df <- do.call(rbind, env_spectra)
spectra_df <- spectra_df[spectra_df$Freq <= 350, ]

p3 <- ggplot(spectra_df, aes(x = Freq, y = Amp, color = Condition)) +
  geom_line() +
  geom_vline(aes(xintercept = Fault_Freq), linetype = "dashed", color = "black", alpha = 0.7) +
  facet_grid(Condition ~ Motor_Load, scales = "free_y") +
  labs(
    title = "Hilbert Envelope Demodulation Spectra (0.007\" Incipient Defect)",
    subtitle = "Comparison across 0 hp (No Load) and 3 hp (Full Load); dashed lines indicate theoretical defect frequencies",
    x = "Frequency (Hz)",
    y = "Demodulated Amplitude"
  ) +
  theme_minimal(base_size = 10) +
  theme(plot.title = element_text(face = "bold"), legend.position = "none")

ggsave("results/plots/Envelope_Spectra_Diagnostic_Comparison.png", plot = p3, width = 11, height = 8, dpi = 300)
cat(">>> Saved 'results/plots/Envelope_Spectra_Diagnostic_Comparison.png'\n")
cat("\n>>> DUAL-LOAD CONDITION MONITORING PIPELINE EXECUTION COMPLETE!\n")
