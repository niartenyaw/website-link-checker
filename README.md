# Website Link Checker

Scrapes a website and records whether links are successful.

Usage:

```bash
bin/links crawl BASE
```

Example:

```bash
bin/links crawl https://docs.mesosphere.com
```

Optional flags:

- `-s=SCOPE`: only scrape links from pages who's URL starts with BASE/SCOPE
- `-o=OUTPUTDIR`: output results here
