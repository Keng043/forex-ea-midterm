# AI-Assisted Forex Expert Advisor — Backtest Summary

## Project
- Platform: MetaTrader 5
- EA: XAUUSD Regime EA
- Primary symbol: XAUUSD
- Timeframe: H1
- Test period: 2024-01-01 → 2026-09-18
- Model: Real Ticks (Model 4)
- Initial deposit: USD 3,000
- Latest test leverage: 1:3000

## Development / Test History

### Baseline
- Initial adaptive regime EA using EMA50/EMA200, ADX14, ATR14, RSI14 and Bollinger Bands.
- Trend-following and range/mean-reversion branches.
- Risk control included position limit, daily loss control and maximum drawdown control.
- Result: Net Profit **-$470.48**; final balance **$2,529.52**.

### v1.2
- Added/adjusted diagnostics and risk controls while investigating why trade evaluation was heavily blocked.
- Diagnostics showed many evaluations blocked by risk logic.
- Result: final balance **$2,416.26**; Net Profit **-$583.74**.

### v2.0
- Reworked entry/risk behavior and adaptive stop/target logic.
- Added breakout/pullback conditions and structure-based SL/TP.
- Result: final balance **$2,307.65**; Net Profit **-$692.35**; 48 trades; Profit Factor **0.83**.

### v3.0
- Adaptive trend SL based on recent swing structure plus ATR buffer.
- Adaptive trend TP with minimum risk/reward requirement.
- Adaptive range SL and Bollinger middle-band target.
- Risk-based position sizing and trade cooldown.
- Separate diagnostic counters for regime/signal/risk behavior.
- No separately verified final report was retained for v3.0.

### v3.1
- Reduced risk per trade from 0.35% to 0.25%.
- Tightened daily loss control.
- Adjusted trend/range thresholds and SL/TP parameters.
- Added break-even management.
- Result: final balance **$2,389.93**; Net Profit **-$610.07**; Equity DD **31.41%**; 64 trades; PF **0.87**.

### v3.2
- Added +DI/-DI confirmation for trend direction.
- Tightened RSI entry ranges.
- Increased minimum trend RR and adjusted break-even timing.
- Result: final balance **$2,160.59**; Net Profit **-$839.41**; Equity DD **31.83%**; 25 trades; PF **0.54**.

### v3.3
- Focused on the excessive risk-blocking behavior.
- Risk per trade reduced to 0.10% and daily loss limit relaxed to 6%.
- Added separate daily/DD diagnostics.
- No separately verified report was retained for v3.3.

### v3.4
- Reworked Daily Risk Blocking to compare current equity with equity at the start of the trading day.
- This also accounts for floating loss rather than relying only on today's closed-history result.
- Result: Net Profit **-$830.11**; Final Balance **$2,169.89**; Equity DD **31.53%**; 25 trades; PF **0.55**.
- The risk-control change alone did not solve the strategy performance problem.

### v3.5 — Latest Test
- Relaxed trend ADX threshold: 22 → 20.
- Increased pullback tolerance: 0.35 ATR → 0.60 ATR.
- Broadened trend RSI entry ranges.
- Kept +DI/-DI direction confirmation.
- Result: Net Profit **+$379.62**; Final Balance **$3,379.62**; Equity DD **30.84%**; PF **1.08**; 65 trades; Win Rate **56.92%**.

## Latest Backtest Result
- Total Net Profit: **+$379.62**
- Final Balance: **$3,379.62**
- Equity Drawdown: **30.84% ($1,507.35)**
- Profit Factor: **1.08**
- Total Trades: **65**
- Winning Trades: **37 (56.92%)**
- Losing Trades: **28 (43.08%)**
- Average winning trade: **$143.44**
- Average losing trade: **-$175.99**
- Max consecutive losses: **3**
- History Quality: **48%**

## Assignment Checks
- Backtest duration at least 2 years: **PASS**
- Net Profit > 0: **PASS**
- Equity Drawdown < 35%: **PASS**
- Note: History Quality is 48%, so the latest result should be presented with that limitation clearly stated.

## Final Project Files
- `XAUUSD_RegimeEA.mq5` — current EA source
- `XAUUSD_RegimeEA.ex5` — compiled EA
- `STRATEGY_SPEC.md` — strategy specification
- `tester_final.ini` — retained final tester configuration
- `BACKTEST_SUMMARY.md` — this summary

Old test configuration files and version backup source files were removed after the finalization step to keep the project clean.
