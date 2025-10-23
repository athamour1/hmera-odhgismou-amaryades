#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# generate_qr.sh
# Φτιάχνει QR PNGs για τις σελίδες του site με βάση ένα base URL.
# Προτεραιότητα σε τοπικό 'qrencode'. Αν λείπει, χρήση public API με curl.
# Δημιουργεί επίσης qrs.html για εύκολη εκτύπωση.
# ------------------------------------------------------------
# Χρήση:
#   chmod +x generate_qr.sh
#   ./generate_qr.sh https://example.com/game_site
#
# Επιλογές:
#   QR_SIZE=300 ./generate_qr.sh https://example.com/game_site
#   PAGES="index.html station-1.html" ./generate_qr.sh https://example.com/game_site
# ============================================================

if [[ $# -lt 1 ]]; then
  echo "❌ Δώσε base URL (π.χ. https://example.com/game_site)"
  exit 1
fi

BASE_URL="${1%/}"   # κόψε τυχόν τελικό /
QR_SIZE="${QR_SIZE:-300}"   # πλάτος/ύψος σε pixels
OUT_DIR="qrs"
mkdir -p "$OUT_DIR"

# Αν δεν έχει δοθεί PAGES, αυτόματη ανίχνευση
if [[ -z "${PAGES:-}" ]]; then
  # index + όλα τα station-*.html που υπάρχουν
  PAGES_LIST=(index.html)
  while IFS= read -r -d '' f; do
    PAGES_LIST+=("$(basename "$f")")
  done < <(find . -maxdepth 1 -type f -name "station-*.html" -print0 | sort -z)
else
  # split PAGES string σε array
  IFS=' ' read -r -a PAGES_LIST <<< "$PAGES"
fi

# Έλεγχος εργαλείων
have_qrencode=false
if command -v qrencode >/dev/null 2>&1; then
  have_qrencode=true
fi

have_curl=false
if command -v curl >/dev/null 2>&1; then
  have_curl=true
fi

if [[ "$have_qrencode" = false && "$have_curl" = false ]]; then
  echo "❌ Χρειάζεσαι είτε 'qrencode' είτε 'curl'."
  exit 1
fi

echo "➡️  Base URL: $BASE_URL"
echo "➡️  Μέγεθος QR: ${QR_SIZE}x${QR_SIZE}"
echo "➡️  Σελίδες: ${PAGES_LIST[*]}"
echo "➡️  Έξοδος: ${OUT_DIR}/"

# Παραγωγή QRs
for page in "${PAGES_LIST[@]}"; do
  url="${BASE_URL}/${page}"
  out="${OUT_DIR}/${page%.html}.png"
  if [[ "$have_qrencode" = true ]]; then
    # -s: pixel size auto από μέγεθος, -m: quiet zone, -l: error correction (L/M/Q/H)
    # Προσεγγίζουμε το target size ρυθμίζοντας --size (αν υποστηρίζεται) ή με -s/-m.
    qrencode -o "$out" -l M -m 2 -s 8 "$url"
  else
    # Χρήση public API με σωστό URL-encoding μέσω --data-urlencode
    curl -sS -G \
      --data-urlencode "data=${url}" \
      --data "size=${QR_SIZE}x${QR_SIZE}" \
      "https://api.qrserver.com/v1/create-qr-code/" \
      -o "$out"
  fi
  echo "✅ ${out}"
done

# Δημιουργία qrs.html για εκτύπωση
QRS_HTML="qrs.html"
cat > "$QRS_HTML" <<HTML
<!doctype html>
<html lang="el">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>QR Codes – Μεγάλο Παιχνίδι</title>
  <style>
    body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,sans-serif;margin:20px}
    h1{font-size:20px;margin:0 0 12px}
    .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:16px;align-items:start}
    .card{border:1px solid #e5e7eb;border-radius:12px;padding:12px}
    .card img{width:100%;height:auto;display:block}
    .url{font-size:12px;color:#334155;word-break:break-all;margin-top:8px}
    .label{font-weight:600;margin-bottom:6px}
    @media print{
      body{margin:0}
      .card{break-inside:avoid}
    }
  </style>
</head>
<body>
  <h1>QR Codes – Μεγάλο Παιχνίδι</h1>
  <div class="grid">
HTML

for page in "${PAGES_LIST[@]}"; do
  url="${BASE_URL}/${page}"
  png="${OUT_DIR}/${page%.html}.png"
  label="${page%.html}"
  cat >> "$QRS_HTML" <<ITEM
    <div class="card">
      <div class="label">${label}</div>
      <img src="${png}" alt="QR για ${label}">
      <div class="url">${url}</div>
    </div>
ITEM
done

cat >> "$QRS_HTML" <<HTML
  </div>
</body>
</html>
HTML

echo "🧾 Δημιουργήθηκε: ${QRS_HTML}"
echo "🎉 Έτοιμο! Άνοιξε το ${QRS_HTML} για εκτύπωση ή πάρε τα PNG από το ${OUT_DIR}/"
