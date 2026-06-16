#!/usr/bin/env bash
set -euo pipefail

# ---- EDIT THESE TWO VALUES ----
BUCKET="nearbuyallim.com"            # your S3 bucket name (check S3 console)
DISTRIBUTION_ID="E1MCDD8F88E6T8"  # CloudFront distribution ID (nearbuyallim.com)
# -------------------------------

# Run from the website/ directory: ./deploy.sh

# 1. Build (client + SSR prerender)
npm run build

# 2. Upload hashed assets with a 1-year immutable cache.
#    Safe because Vite fingerprints every filename: a new build = new names.
aws s3 sync out/assets/ "s3://${BUCKET}/assets/" \
  --cache-control "public, max-age=31536000, immutable" \
  --delete

# 3. Upload everything else (index.html, *.svg) with no hard cache,
#    so a new deploy is picked up immediately.
aws s3 sync out/ "s3://${BUCKET}/" \
  --exclude "assets/*" \
  --cache-control "public, max-age=0, must-revalidate" \
  --delete

# 4. Invalidate CloudFront so the edge serves the fresh index.html now.
aws cloudfront create-invalidation \
  --distribution-id "${DISTRIBUTION_ID}" \
  --paths "/*"

echo "Deployed."
