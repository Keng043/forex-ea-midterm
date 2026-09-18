#property strict
#property version "3.5"
#property description "AI-Assisted XAUUSD H1 Adaptive Regime EA v3.5"
#include <Trade/Trade.mqh>
CTrade trade;

input string InpSymbol="XAUUSD";
input ENUM_TIMEFRAMES InpTimeframe=PERIOD_H1;
input double RiskPercent=0.10;
input double DailyLossLimitPercent=6.0;
input double MaxEquityDrawdownPercent=34.0;
input int MaxSpreadPoints=80;
input int MagicNumber=26091801;
input int EMAFastPeriod=50;
input int EMASlowPeriod=200;
input int ADXPeriod=14;
input int ATRPeriod=14;
input int RSIPeriod=14;
input int BBPeriod=20;
input double BBDeviation=2.0;
input double TrendADXMin=20.0;
input double RangeADXMax=19.0;
input double TrendSL_ATR=1.3;
input double TrendTP_ATR=2.3;
input double RangeSL_ATR=1.0;
input int BreakoutLookback=20;
input int SwingLookback=12;
input double MinTrendRR=1.80;
input double MaxTrendSL_ATR=2.20;
input double MinTrendSL_ATR=0.90;
input double RangeSLBufferATR=0.20;
input int CooldownBars=2;
input bool UseBreakEven=true;
input double BreakEvenAtR=1.25;
input double BreakEvenLockR=0.05;

int hFast=INVALID_HANDLE,hSlow=INVALID_HANDLE,hADX=INVALID_HANDLE,hATR=INVALID_HANDLE;
int hEntryEMA=INVALID_HANDLE;
int hRSI=INVALID_HANDLE,hBB=INVALID_HANDLE;
datetime lastBar=0;
double peakEquity=0.0,dayStartEquity=0.0;
int lossCooldown=0;
int riskDay=0;
long barsEvaluated=0, regimeTrendUp=0, regimeTrendDown=0, regimeRange=0, regimeNone=0, signalBuy=0, signalSell=0, ordersOpened=0, riskBlocked=0, spreadBlocked=0, dailyBlocked=0, ddBlocked=0;

enum Regime { NONE, TREND_UP, TREND_DOWN, RANGE };

bool Buf(int handle,int buffer,int shift,double &v)
{
   double a[];
   ArraySetAsSeries(a,true);
   if(CopyBuffer(handle,buffer,shift,1,a)!=1) return false;
   v=a[0]; return true;
}

bool Bands(int shift,double &upper,double &middle,double &lower)
{
   if(!Buf(hBB,1,shift,middle)) return false;
   if(!Buf(hBB,0,shift,upper)) return false;
   if(!Buf(hBB,2,shift,lower)) return false;
   return true;
}

Regime GetRegime(int shift)
{
   double fast,slow,adx;
   if(!Buf(hFast,0,shift,fast)||!Buf(hSlow,0,shift,slow)||!Buf(hADX,0,shift,adx))
      return NONE;
   if(adx>=TrendADXMin && fast>slow) return TREND_UP;
   if(adx>=TrendADXMin && fast<slow) return TREND_DOWN;
   if(adx<=RangeADXMax) return RANGE;
   return NONE;
}bool NewBar()
{
   datetime t=iTime(InpSymbol,InpTimeframe,0);
   if(t==0 || t==lastBar) return false;
   lastBar=t; return true;
}

bool HasPosition()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==InpSymbol &&
         (int)PositionGetInteger(POSITION_MAGIC)==MagicNumber) return true;
   }
   return false;
}

void UpdateRisk()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(peakEquity<=0 || eq>peakEquity) peakEquity=eq;
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   int today=dt.year*10000+dt.mon*100+dt.day;
   if(today!=riskDay){riskDay=today;dayStartEquity=eq;}
}

double ClosedProfitToday()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   dt.hour=0; dt.min=0; dt.sec=0;
   datetime from=StructToTime(dt);
   if(!HistorySelect(from,TimeCurrent())) return 0.0;
   double profit=0.0;
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0) continue;
      if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=InpSymbol) continue;
      if((int)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=MagicNumber) continue;
      long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
      if(type==DEAL_TYPE_BUY || type==DEAL_TYPE_SELL)
         profit+=HistoryDealGetDouble(ticket,DEAL_PROFIT)+
                 HistoryDealGetDouble(ticket,DEAL_SWAP)+
                 HistoryDealGetDouble(ticket,DEAL_COMMISSION);
   }
   return profit;
}

bool RiskOK()
{
   UpdateRisk();
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(peakEquity>0 && (peakEquity-eq)/peakEquity*100.0>=MaxEquityDrawdownPercent)
   {
      ddBlocked++;
      return false;
   }
   // Use the equity at the start of the current trading day.
   // This includes floating loss and avoids repeatedly scanning today's history.
   if(dayStartEquity>0 && (dayStartEquity-eq)/dayStartEquity*100.0>=DailyLossLimitPercent)
   {
      dailyBlocked++;
      return false;
   }
   return true;
}

bool SpreadOK()
{
   MqlTick tick;
   if(!SymbolInfoTick(InpSymbol,tick)) return false;
   double point=SymbolInfoDouble(InpSymbol,SYMBOL_POINT);
   if(point<=0) return false;
   return ((tick.ask-tick.bid)/point)<=MaxSpreadPoints;
}

double LotSize(double entry,double sl)
{
   double riskMoney=AccountInfoDouble(ACCOUNT_EQUITY)*RiskPercent/100.0;
   double tickSize=SymbolInfoDouble(InpSymbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(InpSymbol,SYMBOL_TRADE_TICK_VALUE);
   double minLot=SymbolInfoDouble(InpSymbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(InpSymbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(InpSymbol,SYMBOL_VOLUME_STEP);
   if(tickSize<=0||tickValue<=0||step<=0) return 0;
   double lossPerLot=MathAbs(entry-sl)/tickSize*tickValue;
   if(lossPerLot<=0) return 0;
   double lot=riskMoney/lossPerLot;
   lot=MathFloor(lot/step)*step;
   lot=MathMax(minLot,MathMin(maxLot,lot));
   return NormalizeDouble(lot,2);
}bool MarginOK(ENUM_ORDER_TYPE type,double volume,double price)
{
   double margin=0;
   if(!OrderCalcMargin(type,InpSymbol,volume,price,margin)) return false;
   return margin<=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

bool TrendSignal(Regime regime,int shift,bool &buy,bool &sell)
{
   buy=false;sell=false;
   double fast,rsi,adx,entryEMA,atr,pdi,mdi;
   if(!Buf(hFast,0,shift,fast)||!Buf(hRSI,0,shift,rsi)||!Buf(hADX,0,shift,adx)||
      !Buf(hADX,1,shift,pdi)||!Buf(hADX,2,shift,mdi)||
      !Buf(hEntryEMA,0,shift,entryEMA)||!Buf(hATR,0,shift,atr)) return false;
   double close=iClose(InpSymbol,InpTimeframe,shift);
   double high1=iHigh(InpSymbol,InpTimeframe,shift);
   double low1=iLow(InpSymbol,InpTimeframe,shift);
   double prevHigh=iHigh(InpSymbol,InpTimeframe,shift+1);
   double prevLow=iLow(InpSymbol,InpTimeframe,shift+1);
   if(close<=0||atr<=0) return false;

   bool pullbackBuy=(low1<=entryEMA+0.60*atr && close>entryEMA);
   bool pullbackSell=(high1>=entryEMA-0.60*atr && close<entryEMA);
   double lookbackHigh=prevHigh,lookbackLow=prevLow;
   for(int i=shift+1;i<shift+BreakoutLookback;i++)
   {
      double hh=iHigh(InpSymbol,InpTimeframe,i),ll=iLow(InpSymbol,InpTimeframe,i);
      if(hh>lookbackHigh)lookbackHigh=hh;
      if(ll<lookbackLow)lookbackLow=ll;
   }
   bool breakoutBuy=(close>lookbackHigh);
   bool breakoutSell=(close<lookbackLow);

   if(regime==TREND_UP && adx>=TrendADXMin && pdi>mdi && fast>0 && close>fast &&
      rsi>=45 && rsi<=68 && (pullbackBuy||breakoutBuy)) buy=true;
   if(regime==TREND_DOWN && adx>=TrendADXMin && mdi>pdi && fast>0 && close<fast &&
      rsi>=32 && rsi<=55 && (pullbackSell||breakoutSell)) sell=true;
   return true;
}

bool RangeSignal(int shift,bool &buy,bool &sell)
{
   buy=false;sell=false;
   double upper,middle,lower,rsi;
   if(!Bands(shift,upper,middle,lower)||!Buf(hRSI,0,shift,rsi)) return false;
   double close=iClose(InpSymbol,InpTimeframe,shift);
   if(close<=0) return false;
   if(close<=lower && rsi<=35 && close>iLow(InpSymbol,InpTimeframe,shift+1)) buy=true;
   if(close>=upper && rsi>=65 && close<iHigh(InpSymbol,InpTimeframe,shift+1)) sell=true;
   return true;
}

void OpenTrade(bool buy,bool trend)
{
   MqlTick tick;
   if(!SymbolInfoTick(InpSymbol,tick)) return;
   double atr;
   if(!Buf(hATR,0,1,atr)||atr<=0) return;
   double entry=buy?tick.ask:tick.bid;
   double slDist=(trend?TrendSL_ATR:RangeSL_ATR)*atr;
   double tp=0;
   if(trend)
   {
      double swing=buy?DBL_MAX:-DBL_MAX;
      for(int i=2;i<=SwingLookback+1;i++)
      {
         double v=buy?iLow(InpSymbol,InpTimeframe,i):iHigh(InpSymbol,InpTimeframe,i);
         if(buy)swing=MathMin(swing,v); else swing=MathMax(swing,v);
      }
      double swingDist=buy?(entry-swing+RangeSLBufferATR*atr):(swing-entry+RangeSLBufferATR*atr);
      if(swingDist>0) slDist=MathMax(MinTrendSL_ATR*atr,MathMin(MaxTrendSL_ATR*atr,swingDist));
      tp=buy?entry+MathMax(MinTrendRR*slDist,TrendTP_ATR*atr):entry-MathMax(MinTrendRR*slDist,TrendTP_ATR*atr);
   }
   else
   {
      double u,m,l;if(!Bands(1,u,m,l))return;
      double rangeHigh=-DBL_MAX,rangeLow=DBL_MAX;
      for(int i=2;i<=SwingLookback+1;i++){rangeHigh=MathMax(rangeHigh,iHigh(InpSymbol,InpTimeframe,i));rangeLow=MathMin(rangeLow,iLow(InpSymbol,InpTimeframe,i));}
      double swingDist=buy?(entry-rangeLow+RangeSLBufferATR*atr):(rangeHigh-entry+RangeSLBufferATR*atr);
      if(swingDist>0) slDist=MathMax(0.75*atr,MathMin(1.5*atr,swingDist));
      tp=m;
      if((buy&&tp<=entry+0.5*slDist)||( !buy&&tp>=entry-0.5*slDist)) tp=buy?entry+1.2*slDist:entry-1.2*slDist;
   }
   double sl=buy?entry-slDist:entry+slDist;
   int digits=(int)SymbolInfoInteger(InpSymbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,digits);tp=NormalizeDouble(tp,digits);
   double lot=LotSize(entry,sl);
   if(lot<=0)return;
   ENUM_ORDER_TYPE type=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   if(!MarginOK(type,lot,entry))return;
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(20);
   bool ok=buy?trade.Buy(lot,InpSymbol,0,sl,tp,trend?"Adaptive Trend BUY":"Adaptive Range BUY")
             :trade.Sell(lot,InpSymbol,0,sl,tp,trend?"Adaptive Trend SELL":"Adaptive Range SELL");
   if(ok) ordersOpened++; else Print("Order failed: ",trade.ResultRetcodeDescription());
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=InpSymbol) return;
   if((int)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=MagicNumber) return;
   long entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entry==DEAL_ENTRY_OUT)
   {
      double p=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+HistoryDealGetDouble(trans.deal,DEAL_SWAP)+HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
      if(p<0) lossCooldown=CooldownBars;
   }
}void ManageOpenPosition()
{
   if(!UseBreakEven || !PositionSelect(InpSymbol)) return;
   if((int)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   MqlTick tick;
   if(!SymbolInfoTick(InpSymbol,tick)) return;
   double risk=MathAbs(open-sl);
   if(risk<=0) return;
   double price=(type==POSITION_TYPE_BUY)?tick.bid:tick.ask;
   double move=(type==POSITION_TYPE_BUY)?price-open:open-price;
   if(move<BreakEvenAtR*risk) return;
   double newSL=(type==POSITION_TYPE_BUY)?open+BreakEvenLockR*risk:open-BreakEvenLockR*risk;
   int digits=(int)SymbolInfoInteger(InpSymbol,SYMBOL_DIGITS);
   newSL=NormalizeDouble(newSL,digits);
   bool improve=(type==POSITION_TYPE_BUY)?(newSL>sl):(newSL<sl || sl==0);
   if(improve) trade.PositionModify(InpSymbol,newSL,tp);
}

void CloseInvalidated()
{
   if(!PositionSelect(InpSymbol)) return;
   if((int)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) return;
   ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   Regime r=GetRegime(1);
   if((type==POSITION_TYPE_BUY&&r==TREND_DOWN)||
      (type==POSITION_TYPE_SELL&&r==TREND_UP))
      trade.PositionClose(InpSymbol);
}

void Evaluate()
{
   barsEvaluated++;
   if(!RiskOK()){riskBlocked++;return;}
   if(lossCooldown>0){lossCooldown--;return;}
   if(!SpreadOK()){spreadBlocked++;return;}
   if(HasPosition()) return;
   Regime r=GetRegime(1);
   if(r==TREND_UP) regimeTrendUp++;
   else if(r==TREND_DOWN) regimeTrendDown++;
   else if(r==RANGE) regimeRange++;
   else regimeNone++;
   if((barsEvaluated%1000)==0)
      PrintFormat("DIAG v3.5 bars=%I64d up=%I64d down=%I64d range=%I64d none=%I64d buy=%I64d sell=%I64d orders=%I64d risk=%I64d daily=%I64d dd=%I64d spread=%I64d",barsEvaluated,regimeTrendUp,regimeTrendDown,regimeRange,regimeNone,signalBuy,signalSell,ordersOpened,riskBlocked,dailyBlocked,ddBlocked,spreadBlocked);
   bool buy=false,sell=false;
   if(r==TREND_UP||r==TREND_DOWN)
   {
      if(!TrendSignal(r,1,buy,sell))return;
      if(buy){signalBuy++;OpenTrade(true,true);}
      else if(sell){signalSell++;OpenTrade(false,true);}
   }
   else if(r==RANGE)
   {
      if(!RangeSignal(1,buy,sell))return;
      if(buy){signalBuy++;OpenTrade(true,false);}
      else if(sell){signalSell++;OpenTrade(false,false);}
   }
}

int OnInit()
{
   if(!SymbolSelect(InpSymbol,true)) return INIT_FAILED;
   hFast=iMA(InpSymbol,InpTimeframe,EMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   hEntryEMA=iMA(InpSymbol,InpTimeframe,20,0,MODE_EMA,PRICE_CLOSE);
   hSlow=iMA(InpSymbol,InpTimeframe,EMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   hADX=iADX(InpSymbol,InpTimeframe,ADXPeriod);
   hATR=iATR(InpSymbol,InpTimeframe,ATRPeriod);
   hRSI=iRSI(InpSymbol,InpTimeframe,RSIPeriod,PRICE_CLOSE);
   hBB=iBands(InpSymbol,InpTimeframe,BBPeriod,0,BBDeviation,PRICE_CLOSE);
   if(hFast==INVALID_HANDLE||hEntryEMA==INVALID_HANDLE||hSlow==INVALID_HANDLE||hADX==INVALID_HANDLE||
      hATR==INVALID_HANDLE||hRSI==INVALID_HANDLE||hBB==INVALID_HANDLE)
      return INIT_FAILED;
   trade.SetExpertMagicNumber(MagicNumber);
   UpdateRisk();
   Print("XAUUSD Regime EA v3.4 initialized.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hEntryEMA!=INVALID_HANDLE)IndicatorRelease(hEntryEMA);
   if(hFast!=INVALID_HANDLE)IndicatorRelease(hFast);
   if(hSlow!=INVALID_HANDLE)IndicatorRelease(hSlow);
   if(hADX!=INVALID_HANDLE)IndicatorRelease(hADX);
   if(hATR!=INVALID_HANDLE)IndicatorRelease(hATR);
   if(hRSI!=INVALID_HANDLE)IndicatorRelease(hRSI);
   if(hBB!=INVALID_HANDLE)IndicatorRelease(hBB);
   PrintFormat("STATS v3.4 bars=%I64d up=%I64d down=%I64d range=%I64d none=%I64d buy=%I64d sell=%I64d orders=%I64d riskBlocked=%I64d daily=%I64d dd=%I64d spread=%I64d",barsEvaluated,regimeTrendUp,regimeTrendDown,regimeRange,regimeNone,signalBuy,signalSell,ordersOpened,riskBlocked,dailyBlocked,ddBlocked,spreadBlocked);
}void OnTick()
{
   UpdateRisk();
   ManageOpenPosition();
   CloseInvalidated();
   if(!NewBar()) return;
   Evaluate();
}
