#!/usr/bin/env bash
# Compile Adeline Monzier CV (CV_ade.tex → CV_ade.pdf)
#
# Usage (from repo root):
#   ./compile_ade.sh           # Docker if available, else local
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
EXPECTED_PAGES=3

mode=auto
[[ "${1:-}" == "--docker" ]] && mode=docker
[[ "${1:-}" == "--local" ]] && mode=local

fail() {
  echo "" >&2
  echo "============================================================" >&2
  echo "  COMPILE FAILED — CV_ade.pdf was NOT updated" >&2
  echo "============================================================" >&2
  echo "$1" >&2
  if [[ -f "$LOG" ]]; then
    echo "" >&2
    echo "Last errors from $LOG:" >&2
    rg "^!" "$LOG" 2>/dev/null | tail -10 >&2 || true
    echo "" >&2
    echo "Last log lines:" >&2
    tail -15 "$LOG" >&2
  fi
  if [[ -f "$OUT" ]] && [[ -f "$TEX" ]]; then
    local pdf_m tex_m
    pdf_m="$(stat -c %Y "$OUT" 2>/dev/null || stat -f %m "$OUT")"
    tex_m="$(stat -c %Y "$TEX" 2>/dev/null || stat -f %m "$TEX")"
    if [[ "$pdf_m" -lt "$tex_m" ]]; then
      echo "" >&2
      echo "STALE PDF: $OUT is older than $MAIN" >&2
      echo "  Close CV_ade.pdf in your viewer, then run:" >&2
      echo "    ./compile_ade.sh --docker" >&2
    fi
  fi
  echo "" >&2
  echo "Full log: $LOG" >&2
  echo "============================================================" >&2
  exit 1
}

build_pdf() {
  echo "$ADE_DIR/$JOB.pdf"
}

file_mtime() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  stat -c %Y "$f" 2>/dev/null || stat -f %m "$f"
}

install_pdf() {
  local built
  built="$(build_pdf)"
  if [[ ! -f "$built" ]] || [[ ! -s "$built" ]]; then
    fail "Build artifact missing or empty: $built"
  fi
  if mv -f "$built" "$OUT" 2>/dev/null; then
    return 0
  fi
  if cp -f "$built" "$OUT" 2>/dev/null; then
    rm -f "$built"
    return 0
  fi
  fail "Cannot write $OUT — close it in your PDF viewer, then retry."
}

check_log() {
  if [[ ! -r "$LOG" ]] || [[ ! -s "$LOG" ]]; then
    fail "No readable compile log at $LOG"
  fi

  # Only trust the final pdflatex pass.
  if ! tail -20 "$LOG" | rg -q "Output written on ${JOB}\\.pdf"; then
    fail "pdflatex did not finish successfully (no 'Output written on ${JOB}.pdf' in log tail)."
  fi

  local built
  built="$(build_pdf)"
  if [[ ! -f "$built" ]] || [[ ! -s "$built" ]]; then
    fail "Expected build artifact missing: $built"
  fi

  local built_m tex_m
  built_m="$(file_mtime "$built")"
  tex_m="$(file_mtime "$TEX")"
  if [[ "$built_m" -lt "$tex_m" ]]; then
    fail "Build PDF is older than $MAIN — source changes were not compiled."
  fi
}

verify_output() {
  if [[ ! -f "$OUT" ]] || [[ ! -s "$OUT" ]]; then
    fail "Output missing or empty: $OUT"
  fi

  local pdf_m tex_m
  pdf_m="$(file_mtime "$OUT")"
  tex_m="$(file_mtime "$TEX")"
  if [[ "$pdf_m" -lt "$tex_m" ]]; then
    fail "Installed PDF is older than $MAIN — you are still viewing a stale file."
  fi

  if command -v pdfinfo >/dev/null 2>&1; then
    local pages
    pages="$(pdfinfo "$OUT" 2>/dev/null | rg '^Pages:' | awk '{print $2}')"
    if [[ -n "$pages" && "$pages" != "$EXPECTED_PAGES" ]]; then
      fail "Expected $EXPECTED_PAGES pages, got $pages — layout may have broken."
    fi
  fi
}

run_pdflatex() {
  local via="$1"
  rm -f "$LOG" "$(build_pdf)" "$ADE_DIR/$JOB.aux" "$ADE_DIR/$JOB.out"

  if [[ "$via" == docker ]]; then
    docker run --rm \
      -u "$(id -u):$(id -g)" \
      -v "$ROOT:/data" \
      -w "/data/Latex Sources Adeline" \
      texlive/texlive \
      sh -c "pdflatex -jobname=$JOB -interaction=nonstopmode $MAIN >CV_ade.compile.log 2>&1 || true; pdflatex -jobname=$JOB -interaction=nonstopmode $MAIN >>CV_ade.compile.log 2>&1 || true"
  else
    (
      cd "$ADE_DIR"
      pdflatex -jobname="$JOB" -interaction=nonstopmode "$MAIN" >>"$LOG" 2>&1 || true
      pdflatex -jobname="$JOB" -interaction=nonstopmode "$MAIN" >>"$LOG" 2>&1 || true
    )
  fi

  check_log
  install_pdf
  verify_output
}

echo "Compiling $MAIN..."

built_with=
ok=0
case "$mode" in
  docker)
    run_pdflatex docker && ok=1 && built_with="Docker (texlive/texlive)"
    ;;
  local)
    run_pdflatex local && ok=1 && built_with="local pdflatex"
    ;;
  auto)
    # Prefer Docker: local TeX installs often miss Palatino bold-italic (pplbi8t).
    if command -v docker >/dev/null 2>&1; then
      if run_pdflatex docker; then
        ok=1
        built_with="Docker (texlive/texlive)"
      fi
    elif command -v pdflatex >/dev/null 2>&1; then
      if run_pdflatex local; then
        ok=1
        built_with="local pdflatex"
      fi
    fi
    ;;
esac

[[ "$ok" -eq 1 ]] || fail "No working TeX toolchain (need docker or pdflatex)."

pages=""
size=""
if command -v pdfinfo >/dev/null 2>&1; then
  pages="$(pdfinfo "$OUT" 2>/dev/null | rg '^Pages:' | awk '{print $2}')"
  size="$(stat -c %s "$OUT" 2>/dev/null || stat -f %z "$OUT")"
fi

echo ""
echo "============================================================"
echo "  COMPILE OK"
echo "============================================================"
echo "Built with: $built_with"
echo "Output:     $OUT"
[[ -n "$pages" ]] && echo "Pages:      $pages"
[[ -n "$size" ]] && echo "Size:       $size bytes"
echo "Fresh:      PDF is newer than $MAIN"
if cp -f "$OUT" "$DATED" 2>/dev/null; then
  echo "Dated:      $DATED"
fi
echo "============================================================"
