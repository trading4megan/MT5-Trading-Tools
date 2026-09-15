# MT5 Trading Tools

A small static site for two MetaTrader 5 Expert Advisors:

- **Position Calculator** — opens a single trade at a risk % and stop-loss you define, then locks itself so it can't fire twice.
- **Risk Monitor** — a read-only dashboard listing every open position, with risk/reward measured from entry price and a portfolio totals row.

## File structure

```
mt5-trading-tools/
├── index.html                     # homepage, links to both tool pages
├── position-calculator.html       # Position Calculator page
├── risk-monitor.html              # Risk Monitor page
├── assets/
│   └── style.css                  # shared stylesheet
├── downloads/
│   ├── RiskRR_AutoTrade_EA.mq5    # Position Calculator source
│   └── OpenTrades_RiskMonitor.mq5 # Risk Monitor source
└── README.md
```

## Publish it on GitHub Pages

1. Create a new **public** repository on GitHub (e.g. `mt5-trading-tools`) — don't initialize it with a README, since you already have one here.
2. From this folder, push everything to it:
   ```bash
   cd mt5-trading-tools
   git init
   git add .
   git commit -m "Initial site"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git push -u origin main
   ```
3. On GitHub, go to the repo's **Settings → Pages**.
4. Under **Build and deployment**, set **Source** to "Deploy from a branch", pick branch **main** and folder **/ (root)**, then **Save**.
5. Wait a minute or two, then your site will be live at:
   ```
   https://<your-username>.github.io/<your-repo>/
   ```

No build step is needed — it's plain HTML/CSS, so whatever you push is exactly what's served.

## Updating an EA file

If you revise either `.mq5` file, just replace it in `downloads/` (keeping the same filename) and push again — the download buttons on each page link directly to those paths.
