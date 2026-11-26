# Benchmark: the index page

How long Wibawa, ActiveAdmin and Administrate take to build the same index page, and how much they send.

**In short:** Wibawa builds the page fastest of the three, by roughly 15 to 25% in undisturbed runs, and allocates the fewest objects. Its HTML is still the largest before compression. After compression it is smaller than Administrate's at 500 rows and larger than ActiveAdmin's at both sizes.

## Results

One table of 1,000 orders, an index page of 50 and of 500 rows. Measured on 26 November 2026 on an Apple M4 Pro, macOS 27.2, Ruby 3.4.3, Rails 8.1.4.1, SQLite in memory; 100 requests per case after 10 to warm up.

| Rows | Admin | Median | 95th percentile | Objects allocated | SQL queries | HTML | HTML, gzipped |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | Wibawa 0.1.0 | 12.9 ms | 28.8 ms | 58,213 | 3 | 145 KB | 9 KB |
| 50 | ActiveAdmin 3.5.2 | 16.3 ms | 23.8 ms | 88,636 | 3 | 80 KB | 4 KB |
| 50 | Administrate 1.0.0 | 16.3 ms | 21.2 ms | 67,356 | 3 | 114 KB | 9 KB |
| 500 | Wibawa 0.1.0 | 96.5 ms | 117.0 ms | 505,910 | 3 | 1,227 KB | 35 KB |
| 500 | ActiveAdmin 3.5.2 | 134.4 ms | 151.2 ms | 793,147 | 3 | 745 KB | 24 KB |
| 500 | Administrate 1.0.0 | 116.1 ms | 137.7 ms | 598,643 | 3 | 1,091 KB | 67 KB |

## Reading them

- **Time.** Of three runs, two were undisturbed and Wibawa's median was the lowest in both: 12 to 13 ms against 15 to 16 ms at 50 rows, and 96 ms against 116 to 138 ms at 500. In the third run something else was using the machine (the other two took twice as long at 50 rows); Wibawa was still first at 50 and level with Administrate at 500. Wibawa's slowest requests at 50 rows (the 95th percentile) remain a little slower than the others'; the cause is not known.
- **Objects allocated.** Wibawa allocates the fewest: about a seventh fewer than Administrate and a third fewer than ActiveAdmin. This is the claim the README makes for the index table: one component for the whole table, not one per cell.
- **SQL.** Three queries each: the rows, the customers they belong to, and the count.
- **HTML size.** Wibawa's page is the largest as written, about 2.7 KB a row: nearly twice ActiveAdmin's and a quarter more than Administrate's. Compressed, which is how a server sends it, it is the same as Administrate's at 50 rows and about half of it at 500, and about half as much again as ActiveAdmin's at 500. A browser has to parse the uncompressed page either way.

## Before the rows were slimmed

The first run of this benchmark found Wibawa level with the others on time and far behind on size: 252 KB at 50 rows and 2,304 KB at 500 (14 KB and 84 KB compressed), with 15.4 ms and 123.7 ms medians. A row was 4.6 KB, more than half of it `class` attributes, and its three action buttons were 2.9 KB.

Three changes to the row followed, none of them visible:

- what every row repeats (its hover and selection style, the pinned first cell, the action buttons) has one short class each in the stylesheet, where it used to spell out the utilities;
- each row icon is drawn once on the page and pointed at from the rows;
- the delete buttons of all rows submit one shared form, where each row used to hold a form and a CSRF token of its own.

That took the page down by about 42% (58% compressed at 500 rows), allocations by about 17%, and the median time by about a fifth. About 450 bytes a row are still indentation, which compression removes.

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
