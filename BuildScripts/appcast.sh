#!/bin/sh

set -eu

action=${1:-render}
selection=${2:-current}

case "$action" in
  render|publish) ;;
  *)
    echo "usage: $0 render|publish [current|legacy|all]" >&2
    exit 2
    ;;
esac

case "$selection" in
  current) feeds="current" ;;
  legacy) feeds="legacy" ;;
  all) feeds="current legacy" ;;
  *)
    echo "usage: $0 render|publish [current|legacy|all]" >&2
    exit 2
    ;;
esac

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir="$project_dir/appcast/dist"
mkdir -p "$output_dir"

for feed in current legacy; do
  output_name="tmpdisk.xml"
  manifest="$project_dir/appcast/$feed.json"
  if [ "$feed" = "legacy" ]; then
    output_name="tmpdisk-legacy.xml"
  elif [ -n "${CURRENT_MANIFEST:-}" ]; then
    manifest="$CURRENT_MANIFEST"
  fi
  "$project_dir/node_modules/.bin/twinkle" render \
    "$manifest" \
    "$output_dir/$output_name"
done

if [ "$action" = "publish" ]; then
  if [ -z "${CURRENT_MANIFEST:-}" ]; then
    echo "warning: current feed publishing without signed enclosure (template)" >&2
  fi
  for feed in $feeds; do
    output_name="tmpdisk.xml"
    if [ "$feed" = "legacy" ]; then
      output_name="tmpdisk-legacy.xml"
    fi
    aws s3 cp "$output_dir/$output_name" \
      "s3://tmpdisk-appcast-prod/$output_name" \
      --content-type "application/xml; charset=utf-8" \
      --cache-control "public, max-age=300"
  done
fi
