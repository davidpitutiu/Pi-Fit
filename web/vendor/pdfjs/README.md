# Local PDF preview runtime

`pdfjs-dist` 4.10.38, distributed by Mozilla under Apache-2.0.
Only the browser module, its module worker, and the upstream license are vendored.
`ORIGIN.json` records the official NPM artifact URL, its verified SHA-512 integrity,
and the SHA-256 of each extracted file. The upstream files are unmodified.

`web/index.html` loads this module and configures its same-origin worker before
starting Flutter. Printing's web plugin detects `globalThis.pdfjsLib` and uses it
without downloading its default runtime from UNPKG. The bootstrap adapter copies
PDF input bytes before worker transfer so Printing retains its original data for
subsequent sharing and printing. The report embeds Inter and
uses vector graphics, so no external font, image, CMap, or standard-font asset is
needed for Pi Fit's generated reports.

When updating, obtain package metadata from the official NPM registry, verify the
published artifact integrity before extraction, retain LICENSE, update origin
checksums, and test a real generated report through Printing's web preview.
