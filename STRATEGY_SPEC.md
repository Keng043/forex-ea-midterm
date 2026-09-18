# AI-Assisted Forex Expert Advisor — Midterm Strategy Spec

## 1. เป้าหมาย
สร้าง EA สำหรับ MetaTrader 5 ตามโจทย์ Midterm โดยเน้น XAUUSD (ทอง) บน H1
และออกแบบให้รองรับ EURUSD เป็นตัวเลือกสำรองเมื่อโบรกเกอร์ไม่มี XAUUSD

ข้อกำหนดจากโจทย์:
- ใช้ MQL5 หรือ Python + MetaTrader 5
- Backtest อย่างน้อย 2 ปี
- ต้องรายงาน Net Profit และ Equity Drawdown
- Equity Drawdown ต้องต่ำกว่า 35%
- ต้องสามารถรันโค้ดในชั้นเรียนได้

## 2. แนวคิดหลัก
ใช้ Market Regime Detection ก่อนเลือกกลยุทธ์:
- TRENDING -> Trend Following
- RANGING -> Mean Reversion

Timeframe หลัก: H1
Instrument หลัก: XAUUSD
Instrument สำรอง: EURUSD

## 3. Indicators
- EMA 50
- EMA 200
- ADX 14
- ATR 14
- RSI 14
- Bollinger Bands 20, 2.0

## 4. Regime Detection
ถือว่าเป็น TRENDING เมื่อ:
- ADX(14) >= 25
- EMA50 > EMA200 = bullish trend
- EMA50 < EMA200 = bearish trend

ถือว่าเป็น RANGING เมื่อ:
- ADX(14) <= 20
- หลีกเลี่ยงช่วง ADX 20-25 เพื่อไม่เทรดในช่วงเปลี่ยน regime

ถ้าเงื่อนไขไม่ชัดเจน -> NO TRADE

## 5. Strategy A — Trend Following
ใช้เมื่อเป็น TRENDING

BUY:
- EMA50 > EMA200
- ADX >= 25
- ราคาปิดอยู่เหนือ EMA50
- RSI อยู่ในช่วง 50-70
- รอแท่ง H1 ปิดยืนยันสัญญาณ

SELL:
- EMA50 < EMA200
- ADX >= 25
- ราคาปิดอยู่ต่ำกว่า EMA50
- RSI อยู่ในช่วง 30-50
- รอแท่ง H1 ปิดยืนยันสัญญาณ

Stop Loss:
- 1.5 x ATR(14)

Take Profit:
- 2.0 x ATR(14)

## 6. Strategy B — Mean Reversion
ใช้เมื่อเป็น RANGING

BUY:
- ADX <= 20
- ราคาปิดแตะหรือต่ำกว่า Bollinger Lower Band
- RSI <= 35
- รอแท่ง H1 ปิดก่อนเปิดออเดอร์

SELL:
- ADX <= 20
- ราคาปิดแตะหรือสูงกว่า Bollinger Upper Band
- RSI >= 65
- รอแท่ง H1 ปิดก่อนเปิดออเดอร์

Stop Loss:
- 1.2 x ATR(14)

Take Profit:
- เป้าหมายหลักที่ Bollinger Middle Band
- ไม่บังคับให้ถือจนถึง TP หากมีสัญญาณ regime เปลี่ยน

## 7. Risk Management
- Risk ต่อ trade เริ่มต้น: 0.5% ของ Equity
- คำนวณ lot จากระยะ Stop Loss และมูลค่าต่อ point
- เปิดพร้อมกันสูงสุด 1 position ต่อ symbol
- ไม่ใช้ Martingale
- ไม่เพิ่ม lot เพื่อแก้ขาดทุน
- หยุดเปิด trade ใหม่เมื่อ daily loss ถึง 2%
- หยุดระบบเมื่อ equity drawdown จากจุดสูงสุดถึง 30%
- ก่อนส่งคำสั่งต้องตรวจ spread และ margin

## 8. Trade Filters
ไม่เปิดออเดอร์เมื่อ:
- spread สูงเกินค่าที่กำหนด
- ไม่มีแท่ง H1 ใหม่
- มี position ของ symbol อยู่แล้ว
- ATR ต่ำผิดปกติ
- ถึง daily loss limit
- ถึง maximum equity drawdown limit

## 9. Exit เพิ่มเติม
ปิด position เมื่อ:
- ถึง Stop Loss
- ถึง Take Profit
- regime เปลี่ยนและ invalidates สัญญาณเดิม
- ระบบ risk protection สั่งหยุด

## 10. Backtest Plan
Backtest อย่างน้อย 2 ปีตามโจทย์
และเก็บ:
- Net Profit
- Equity Drawdown
- Profit Factor
- Total Trades
- Win Rate
- Average Trade
- Max Consecutive Losses

ต้องทดสอบอย่างน้อย:
1. XAUUSD H1
2. EURUSD H1 หากข้อมูล/โบรกเกอร์รองรับ

ห้ามสรุปว่ากลยุทธ์ผ่านเกณฑ์จนกว่าจะได้ผล Backtest จริง

## 11. Implementation Order
1. ตรวจ MT5 และ symbol ที่มีจริง
2. สร้าง EA skeleton
3. ทำ indicator/regime detection
4. ทำ Trend Following
5. ทำ Mean Reversion
6. ทำ position sizing/risk management
7. ทำ entry/exit และ trade filters
8. Compile
9. Backtest 2+ ปี
10. วิเคราะห์ผลและปรับพารามิเตอร์อย่างมีเหตุผล
11. เตรียมไฟล์สำหรับรันในห้องเรียน

## 12. หมายเหตุ
ค่าพารามิเตอร์ทั้งหมดเป็น initial specification สำหรับเริ่มพัฒนา
ยังไม่มีการรับประกัน Net Profit หรือ Drawdown จนกว่าจะทดสอบกับข้อมูลจริง
และต้องไม่ overfit ผล Backtest เพียงเพื่อให้ผ่านเกณฑ์
