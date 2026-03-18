# Is InnerSource Commons good for open source?

Talk for FOSS Backstage 2025 by Benjamin Nickolls and Andrew Nesbitt.

- [Slides](Is%20InnerSource%20Commons%20good%20for%20open%20source.pdf)
- [Findings](findings.md) -- what the data shows
- [Method](method.md) -- how we collected and processed the data

## Abstract

The InnerSource commons promotes the adoption of open source practices to accelerate development within a company's culture. It's also said that it prepares the ground for those companies to begin contributing and releasing open source software... but can we prove it?

Using data from hundreds of millions of open source repositories provided by ecosyste.ms we seek to answer the question: is The InnerSource Commons good for open source?

We look at data from 108 member organisations to answer what might seem like a simple question, in the process unpacking what it means to support, contribute, and maintain open source software. What a 'healthy' open source project looks like, and where and how we can identify and support important projects that need our help.

## Data

The raw JSON data (8.6GB across 358k files) and SQLite database (438MB) are compressed with [zstd](https://facebook.github.io/zstd/).

To decompress everything:

```sh
# SQLite database
zstd -d data/foss_backstage.db.zst

# JSON data (each dir is a separate archive)
for f in data/*.tar.zst; do
  zstd -d "$f" --stdout | tar xf -
done
```

## License

Code and data are licensed under [CC-BY-SA-4.0](LICENSE).

## Notes

Some of the questions we set out to answer:

1. Do ISC members see growth in contribution to open source over time?
2. Do ISC members publish well-used open source software?
3. Do ISC members contribute to external open source projects?
4. Do staff at ISC members go on to contribute to open source after joining?
5. Do ISC members contribute to their own dependencies?
6. What types of activity do ISC members do externally?
7. What are the most critical shared dependencies across ISC members?
8. Where does contribution not match dependency? Where are the gaps?
9. How does funding line up with contribution?
