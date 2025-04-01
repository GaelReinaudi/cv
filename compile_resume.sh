#!/bin/bash

# Script to compile CV.tex and create a dated copy
# Created: $(date)
# Usage: ./compile_resume.sh

echo "Compiling CV.tex..."
pdflatex CV.tex && pdflatex CV.tex

DATED_FILENAME="CV_Gael_Reinaudi_HedgeFund_$(date +"%Y-%m-%d").pdf"
echo "Creating dated copy: $DATED_FILENAME"
cp CV.pdf "$DATED_FILENAME"

echo "Resume compilation complete!"
echo "Output files:"
ls -lh CV.pdf "$DATED_FILENAME" 