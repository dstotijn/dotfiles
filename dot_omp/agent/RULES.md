# Browser relay

OMP uses the browser relay by default.

- Always pass `app.relay: true` and `app.target` to `browser.open` in relay mode. Without `app.target`, OMP adopts the visible tab.
- First open a dedicated Chromium tab with a unique marker URL, for example
  `open -a Chromium "https://example.com/?omp-relay=<unique-id>"`. Attach using that marker as `app.target`,
  then navigate only the attached tab.
- If the marked tab is unavailable, stop. Never retry without `app.target`.
- Call the direct helper as `tab.goto(url)`. Do not pass Puppeteer-style options.
- `tab.waitFor` expects a selector. Do not pass a timeout object or use it as a sleep.
- After a compound step fails, inspect `tab.url()` and `tab.title()`; an earlier navigation may have succeeded.
- Use `tab.observe()` to discover actions and `tab.ariaSnapshot()` to prove rendered text. Use a screenshot for visual proof.
- Close the managed tab when done to release it.
