#!/bin/bash

# Script to compile CV.tex and create a dated copy
# Created: $(date)
# Usage: ./compile_resume.sh

echo "Compiling CV.tex..."
docker run --rm -v "/mnt/data/repos/gaelreinaudi/cv":/data -w "/data/Latex Sources - Quant" texlive/texlive pdflatex -interaction=nonstopmode CV.tex 2>&1 | grep -E "(error|Output|Fatal)"

# cp "Latex Sources - Quant/CV.pdf" "Latex Sources - Quant/Gael_Reinaudi.pdf"