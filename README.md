This is a personal project to generate custom diary/planner pages. Written in Zig because I wanted to learn Zig.

# Instructions

Update the year in `src/main.zig`.
```bash
zig build run
soffice --convert-to 'pdf:writer_pdf_Export' --outdir out_files out_files/*.fodg
lpr -o media=a5 -o page-ranges=1 out_files/*.pdf
```
Reload pages into printer. Make sure to offset them by one, since each file contains the pages facing each other, not the back-to-back pages.
```bash
lpr -o media=a5 -o page-ranges=2 out_files/*.pdf
```

