# Benchmark: the index page

How long Wibawa, ActiveAdmin and Administrate take to build the same index page, and how much they send.

**In short:** the three are about equally fast. Wibawa's page is the largest, two to three times the HTML of the others, and still the largest after compression.

## Results

One table of 1,000 orders, an index page of 50 and of 500 rows. Measured on 26 November 2026 on an Apple M4 Pro, macOS 27.2, Ruby 3.4.3, Rails 8.1.4.1, SQLite in memory; 100 requests per case after 10 to warm up.

| Rows | Admin | Median | 95th percentile | Objects allocated | SQL queries | HTML | HTML, gzipped |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | Wibawa 0.1.0 | 15.4 ms | 31.6 ms | 70,380 | 3 | 252 KB | 14 KB |
| 50 | ActiveAdmin 3.5.2 | 14.4 ms | 17.5 ms | 88,627 | 3 | 80 KB | 4 KB |
| 50 | Administrate 1.0.0 | 14.5 ms | 16.4 ms | 67,359 | 3 | 114 KB | 9 KB |
| 500 | Wibawa 0.1.0 | 123.7 ms | 145.7 ms | 628,309 | 3 | 2,304 KB | 84 KB |
| 500 | ActiveAdmin 3.5.2 | 134.8 ms | 140.2 ms | 793,146 | 3 | 745 KB | 24 KB |
| 500 | Administrate 1.0.0 | 116.6 ms | 137.5 ms | 598,643 | 3 | 1,091 KB | 67 KB |

## Reading them

- **Time.** Medians are within about 15% of each other at both sizes. Over four runs, Wibawa was the slowest at 50 rows every time, by 3 to 7%, and Administrate the fastest at 500 rows every time; Wibawa and ActiveAdmin swapped places at 500. The gaps are small next to a real database query or a network round trip. Wibawa's slowest requests at 50 rows (the 95th percentile) are slower than the others'; the likeliest cause is the larger page, which is not confirmed.
- **Objects allocated.** Wibawa and Administrate allocate about the same, ActiveAdmin about a quarter more. This is the claim the README makes for the index table: one component for the whole table, not one per cell.
- **SQL.** Three queries each: the rows, the customers they belong to, and the count.
- **HTML size.** This is where Wibawa is behind. A Wibawa row is about 4.6 KB. More than half of that is `class` attributes, and the row's three action buttons account for 2.9 KB: each repeats the full list of utility classes and carries its icon as inline SVG. Compression removes most of the repetition, and Wibawa's page is still the largest sent, 14 KB against 4 KB and 9 KB at 50 rows. A browser also has to parse the uncompressed page.

Giving the row buttons and the pinned first cell one short class each, in place of the repeated utilities, would remove roughly a quarter of the page. That has not been done.

## What was measured

One Rails app with the three admins mounted side by side on the same table (`benchmark/app.rb`). The page is requested through the Rack stack in the same process, so routing, the controller, the queries and rendering are timed, and the network, a web server and the browser are not.

To compare like with like, each admin was set up to show the same thing:

- six columns: id, number, customer (a `belongs_to`, shown by name), status, total as money, created at;
- the customer eager-loaded, so no query per row;
- a checkbox per row for batch actions, and the admin's own row actions;
- no filters, no search and no sign-in. ActiveAdmin shows filters by default; they were turned off, since they add queries of their own;
- Rails in production mode with everything loaded up front, and no asset pipeline, so an asset tag costs the same nothing for each.

## Limits

- **One machine, one run published.** Timings move by 10% or more between runs; the sizes, object counts and query counts do not.
- **The pages are not identical.** Each admin draws its own chrome around the table. Wibawa's includes its sidebar and the command palette's list of pages.
- **ActiveAdmin 3.5.2 is the stable line.** ActiveAdmin 4 is in beta, renders differently, and was not measured.
- **Only the index page.** Forms, record pages and filters were not measured.
- **SQLite in memory** makes the queries nearly free, so the comparison is mostly of rendering. On a real database the three queries would weigh more and the differences would shrink further.
- Nothing here measures how the page feels in a browser.

## Running it yourself

```sh
BUNDLE_GEMFILE=benchmark/Gemfile bundle install
bundle exec rake benchmark          # RUNS=200 for more requests per case
```

The other two admins are only in the benchmark's own bundle (`benchmark/Gemfile`), not in Wibawa's.
