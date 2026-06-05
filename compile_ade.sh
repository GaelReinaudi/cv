#!/usr/bin/env bash
# Compile Adeline Monzier CV (CV_ade.tex → CV_ade.pdf)
#
# Usage (from repo root):
#   ./compile_ade.sh           # local pdflatex, else Docker
#   ./compile_ade.sh --docker  # always use Docker texlive/texlive
#   ./compile_ade.sh --local   # local pdflatex only

set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ADE_DIR="$ROOT/Latex Sources Adeline"
MAIN=CV_ade.tex
TEX="$ADE_DIR/$MAIN"
OUT="$ADE_DIR/CV_ade.pdf"
JOB=CV_ade.build
LOG="$ADE_DIR/CV_ade.compile.log"
DATED="$ADE_DIR/CV_Adeline_Monzier_$(date +%Y-%m-%d).pdf"

mode=auto
[[ "${1:-}" == "--docker" ]] && mode=docker
[[ "${1:-}" == "--local" ]] && mode=local

build_pdf() {
  echo "$ADE_DIR/$JOB.pdf"
}

pdf_mtime() {
  local f="$OUT"
  [[ -f "$f" ]] || f="$(build_pdf)"
  [[ -f "$f" ]] || return 0
  stat -c %Y "$f" 2>/dev/null || stat -f %m "$f"
}

install_pdf() {
  local built
  built="$(build_pdf)"
  if [[ ! -f "$built" ]]; then
    echo "Error: expected build artifact $built" >&2
    return 1
  fi
  if mv -f "$built" "$OUT" 2>/dev/null; then
    return 0
  fi
  if cp -f "$built" "$OUT" 2>/dev/null; then
    rm -f "$built"
    return 0
  fi
  echo "Error: cannot install $OUT — close it in your PDF viewer, then retry." >&2
  return 1
}

tex_mtime() {
  stat -c %Y "$TEX" 2>/dev/null || stat -f %m "$TEX"
}

check_log() {
  if [[ ! -r "$LOG" ]] || [[ ! -s "$LOG" ]]; then
    echo "Error: no readable compile log at $LOG" >&2
    return 1
  fi
  if rg -qi "can't write on file|I can't write on file" "$LOG"; then
    if [[ -f "$(build_pdf)" ]]; then
      install_pdf || return 1
    else
      echo "Error: cannot write PDF — close $OUT in your PDF viewer, then retry." >&2
      return 1
    fi
  fi
  if rg -qi "Fatal error occurred, no output PDF file produced" "$LOG" && \
     ! rg -q "Output written on .*\.pdf" "$LOG"; then
    echo "Error: pdflatex failed. Last log lines:" >&2
    tail -25 "$LOG" >&2
    return 1
  fi
  if ! rg -q "Output written on .*\.pdf" "$LOG"; then
    echo "Error: pdflatex did not write a PDF. Last log lines:" >&2
    tail -25 "$LOG" >&2
    return 1
  fi
  local built tex_m built_m
  built="$(build_pdf)"
  tex_m="$(tex_mtime)"
  if [[ ! -f "$built" ]]; then
    echo "Error: expected build artifact $built" >&2
    return 1
  fi
  built_m="$(stat -c %Y "$built" 2>/dev/null || stat -f %m "$built")"
  if [[ "$built_m" -lt "$tex_m" ]]; then
    echo "Error: build PDF is older than $MAIN — compile did not refresh output." >&2
    return 1
  fi
  return 0
}

run_local() {
  rm -f "$LOG" "$(build_pdf)"
  (
    cd "$ADE_DIR"
    pdflatex -jobname="$JOB" -interaction=nonstopmode "$MAIN" >>"$LOG" 2>&1 || true
    pdflatex -jobname="$JOB" -interaction=nonstopmode "$MAIN" >>"$LOG" 2>&1 || true
  )
  check_log && install_pdf
}

run_docker() {
  rm -f "$LOG" "$(build_pdf)"
  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$ROOT:/data" \
    -w "/data/Latex Sources Adeline" \
    texlive/texlive \
    sh -c "pdflatex -jobname=$JOB -interaction=nonstopmode $MAIN >CV_ade.compile.log 2>&1 || true; pdflatex -jobname=$JOB -interaction=nonstopmode $MAIN >>CV_ade.compile.log 2>&1 || true"
  check_log && install_pdf
}

echo "Compiling $MAIN..."

built_with=
ok=0
case "$mode" in
  docker)
    run_docker && ok=1 && built_with="Docker (texlive/texlive)"
    ;;
  local)
    run_local && ok=1 && built_with="local pdflatex"
    ;;
  auto)
    if command -v pdflatex >/dev/null 2>&1; then
      if run_local; then
        ok=1
        built_with="local pdflatex"
      else
        echo "Local compile failed; retrying with Docker (texlive/texlive)..." >&2
      fi
    fi
    if [[ "$ok" -eq 0 ]] && command -v docker >/dev/null 2>&1; then
      run_docker && ok=1 && built_with="Docker (texlive/texlive)"
    fi
    ;;
esac

if [[ "$ok" -eq 0 ]]; then
  echo "Compile failed. Full log: $LOG" >&2
  exit 1
fi

echo "Built with $built_with."

if cp -f "$OUT" "$DATED" 2>/dev/null; then
  echo "Output:  $OUT"
  echo "Dated:   $DATED"
else
  echo "Output:  $OUT"
  echo "(Skipped dated copy — could not write $DATED)"
fi

# Show applied horizontal margins from the log (geometry verbose).
if rg -q "h-part:" "$LOG" 2>/dev/null; then
  rg "h-part:" "$LOG" | tail -1 | sed 's/^/* /'
fi
