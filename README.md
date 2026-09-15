# MT5 Trading Tools

Two free MetaTrader 5 Expert Advisors for forex trading.

## Position Calculator

Opens a single trade sized to a risk percentage you define, then locks itself so it can never open a second trade.

- Set direction, stop-loss price, risk %, and risk:reward ratio — lot size and take-profit are calculated automatically.
- Lot size is rounded to your broker's actual minimum, maximum, and step.
- Checks free margin and validates the stop-loss is on the correct side of price before sending anything.
- A persistent lock (survives removing the EA or restarting MT5 entirely) stops it from ever firing a second trade.
- If AutoTrading or Algo Trading permissions are off when you attach it, it keeps watching and fires automatically the moment they're switched on.

File: [`Position Calculator #.#.mq5`](https://github.com/trading4megan/MT5-Trading-Tools/blob/main/Position%20Calulator%203.5.mq5)

## Risk Monitor

A read-only dashboard that lists every open position on your account and what each one risks or stands to gain.

- Lists every open trade account-wide, across all symbols — not just the current chart.
- Risk $ and Reward $ are measured from each trade's entry price to its SL/TP, so the numbers stay fixed and don't drift as price moves.
- Flags any trade missing a stop-loss or take-profit instead of silently showing zero.
- Shows a totals row: combined risk, reward, and floating P/L across everything open.
- Never sends, modifies, or closes an order — display only.

File: [`Open Trades Tracker.mq5`](https://github.com/trading4megan/MT5-Trading-Tools/blob/main/Open%20Trades%20Tracker.mq5)

## Install (either tool)

1. Download the `.mq5` file.
2. In MT5, open **MetaEditor** (`F4`), then **File → Open** and browse to your `MQL5/Experts` folder (or use MT5's **File → Open Data Folder** to get there).
3. Place the file in that folder, open it in MetaEditor, and compile with `F7`.
4. In MT5, refresh the **Navigator** panel and find it under Expert Advisors.
5. Drag it onto a chart and configure the inputs (Position Calculator only — Risk Monitor needs no setup).

## Before running live

Test on a demo account first. Lot-size and risk-money calculations rely on each symbol's broker-reported tick value, which is accurate for the vast majority of FX pairs but can be slightly off for some indices, metals, or CFDs with non-standard contract specs.


Note: use at you own risk
not for financial advise

