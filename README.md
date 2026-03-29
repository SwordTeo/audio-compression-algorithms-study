# Comparative Study of Audio Signal Compression Algorithms

This repository contains the code and experimental material developed for the thesis **“Comparative Study of Audio Signal Compression Algorithms”**. The project focuses on the implementation, evaluation, and comparison of audio compression techniques using **MATLAB** and **FFmpeg**.

The study includes experiments on:
- bitrate ladder analysis
- CBR versus VBR encoding
- computational complexity and processing cost
- sampling rate and quantization effects
- noise robustness
- MP3 versus AAC comparison

The repository also includes the **MATLAB Audio Compression Analyzer**, a graphical user interface developed to automate compression, decompression, metric calculation, and result visualization.

## Repository Structure

- `experiments/` — code for the individual experiments
- `gui/` — MATLAB GUI source code for the Audio Compression Analyzer
- `audio/` — input audio files used in the experiments
- `results/` — generated results, plots, and exported tables
- `docs/` — thesis-related documentation or supplementary material

## Requirements

To run the code, the following tools are required:

- **MATLAB**
- **FFmpeg**
- **Signal Processing Toolbox** for MATLAB
- basic MATLAB audio processing functions such as:
  - `audioread`
  - `audiowrite`
  - `audioinfo`
  - `resample`
  - `writetable`

Some scripts may also use MATLAB GUI functions such as:
- `uigetfile`
- `uialert`
- `figure`
- `bar`

## Reproducibility

The experiments were designed to be reproducible. To execute them successfully, make sure that:

1. FFmpeg is installed and accessible from your system path.
2. The input and output folder paths are correctly configured.
3. The required audio files are available in the expected directories.
4. MATLAB and the necessary toolboxes are properly installed.

If additional metrics such as **PESQ** or **STOI** are used in specific scripts, the corresponding implementations must also be available.

## Notes

This repository was created to support the experimental part of the thesis and to make the methodology and implementation easier to reproduce, inspect, and extend.
