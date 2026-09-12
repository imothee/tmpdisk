#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
logs_dir="$project_dir/appcast/logs"
report_dir="$project_dir/appcast/report"
account_id=$(aws sts get-caller-identity --query Account --output text)
log_source="s3://tmpdisk-appcast-logs-prod/AWSLogs/$account_id/CloudFront/tmpdisk/"

mkdir -p "$logs_dir" "$report_dir"
aws s3 sync "$log_source" "$logs_dir" --exclude "*" --include "*.gz"

log_paths=$(find "$logs_dir" -type f -name "*.gz" -print)
if [ -z "$log_paths" ]; then
  echo "no appcast logs found at $log_source" >&2
  exit 1
fi

# CloudFront-generated object names contain no whitespace, so splitting the
# newline-delimited find output produces one argument per log file.
# shellcheck disable=SC2086
"$project_dir/node_modules/.bin/twinkle" report \
  "$project_dir/appcast/current.json" \
  $log_paths \
  --html "$report_dir/index.html" \
  > "$report_dir/report.json"

cat "$report_dir/report.json"
