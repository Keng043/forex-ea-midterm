# Forex EA Midterm — Final Backtest Summary

## Final Candidate
- EA: XAUUSD Regime EA v5.1
- Symbol: XAUUSD
- Timeframe: H1
- Model: Real Ticks (Model 4)
- Period: 2024-01-01 → 2026-09-18
- Initial Deposit: $3,000
- Leverage: 1:3000
- Risk per trade: 0.2915%

## Verified Full Backtest
| Metric | Result |
|---|---:|
| Initial Balance | $3,000.00 |
| Final Balance | $4,579.69 |
| Net Profit | **+$1,579.69** |
| Equity Drawdown | **27.22%** |
| Profit Factor | **1.16** |
| Sharpe Ratio | 2.67 |
| Total Trades | 137 |
| Winning Trades | 59 (43.07%) |
| Losing Trades | 78 (56.93%) |
| Expected Payoff | $11.53 |
| History Quality | 48% real ticks |
| Bars | 15,937 |
| Ticks | 188,065,784 |

## Assignment Checks
- Backtest period >= 2 years: **PASS**
- Net Profit > 0: **PASS**
- Equity Drawdown < 35%: **PASS (27.22%)**
- XAUUSD H1: **PASS**

## Development Path
- v3.x: fixed risk blocking, entry logic, adaptive SL/TP and break-even behavior.
- v4.0: reduced risk and stabilized long-side trend system; first profitable candidate.
- v4.1–v4.4: risk sweep; profit increased while monitoring drawdown.
- v4.6: best result in the earlier risk sweep, +$2,784.53 with 34.68% DD.
- v4.7: higher risk reduced profit and pushed DD close to the limit; rejected.
- v4.8: added D1 EMA50/EMA200 trend filter for robustness.
- v4.9: tested stricter ADX threshold.
- v5.0: tested pullback-only trend entry.
- v5.1: combined D1 trend filter + ADX rising + pullback-only BUY entry.

## Robustness Tests
The split-period tests were used to check whether the strategy depended only on one market period. v5.1 remained profitable in the first split and was approximately flat in the second split. The verified full-period run is the authoritative final result because it was executed with a uniquely named compiled EA (`XAUUSD_RegimeEA_v5_1.ex5`) to avoid stale tester binaries.

## Final Decision
**v5.1 is the final candidate for the midterm submission.**
It satisfies the explicit assignment thresholds in the verified full backtest while keeping equity drawdown materially below 35%.

## Important Limitation
MetaTrader reports 48% history quality / real ticks for this test. The result should therefore be presented as the verified MT5 Strategy Tester result, not as a guarantee of live performance.
