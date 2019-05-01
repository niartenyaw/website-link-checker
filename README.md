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
    ```bash
    bin/links crawl https://docs.mesosphere.com -s=/1.12/installing
    ```
- `-o=OUTPUTDIR`: output results here
    ```bash
    bin/links crawl https://docs.mesosphere.com -o=my_dir
    ```
