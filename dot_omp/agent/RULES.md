# Browser relay

OMP uses the browser relay by default.

- Always pass `app.target` to `browser.open` in relay mode. Without it, OMP adopts the visible tab.
- First open a dedicated Chromium tab with a unique marker URL, for example
  `open -a Chromium "https://example.com/?omp-relay=<unique-id>"`. Attach using that marker as `app.target`,
  then navigate only the attached tab.
- If the marked tab is unavailable, stop. Never retry without `app.target`.
