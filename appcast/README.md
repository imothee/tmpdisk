# TmpDisk appcasts

`current.json` is the feed embedded by TmpDisk 2.3.0 and later. Future releases add a new-key signed enclosure there.

`legacy.json` is the permanent recovery feed for releases that trust the unavailable old signing key. It must only offer a manual-download page—never an enclosure signed with the new key.

Install the pinned Twinkle release and render both feeds locally:

```sh
npm ci
npm run appcast:render
```

After the static infrastructure is deployed, publish the initial pair with:

```sh
AWS_PROFILE=cg-prod npm run appcast:publish -- all
```

Normal releases publish only the current feed:

```sh
AWS_PROFILE=cg-prod npm run appcast:publish
```

Publishing validates both manifests before any upload. Published objects are versioned in S3; CloudFront caches them for five minutes.

## Offline metrics

Download the retained CloudFront logs and generate local JSON and HTML reports:

```sh
AWS_PROFILE=cg-prod npm run appcast:report
```

Outputs are written to the gitignored `appcast/report/` directory. Raw logs remain local in `appcast/logs/`. The report counts update checks and estimates version adoption; it does not measure installations or completed downloads.
