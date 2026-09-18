#!/bin/bash
# Same build as Latex Sources - Quant (pdflatex twice)
cd "$(dirname "$0")"
pdflatex CV_ade.tex && pdflatex CV_ade.tex
cp CV_ade.pdf "CV_Adeline_Monzier_$(date +%Y-%m-%d).pdf"
echo "Done: CV_ade.pdf"
