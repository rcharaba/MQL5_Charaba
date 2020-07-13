//+------------------------------------------------------------------+
//|                                         Buggy_Player_Charaba.mq5 |
//|                                 Copyright 2020, Rodrigo Charaba. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Rodrigo Charaba."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
//--- enums
enum eAllowedTrades
  {
   BUY,                                  // BUY Only
   SELL,                                 // SELL Only
   BOTH,                                 // BUY AND SELL
  };
//--- input parameters
input int      Lote                       = 5;
input int      InpMA_Hilo                 = 4;   // Hilo Period 
input ENUM_MA_METHOD    InpMA_ma_method   = MODE_SMA;       // MA Method 
input ushort   InpStopLoss                = 300;  // Stop Loss (in pips)
input ushort   InpTakeProfit              = 100;  // Take Profit (in pips)
input double   InpProfit                  = 1000;  // Close all if Profit >=
input int      Consecutive_Loss           = 5;
input eAllowedTrades Buy_Sell             = SELL;
input int      Consecutive_Loss_Revert    = 4;
input double   Revert_Rate                = 3;
//---
input uchar                InpStartHour            = 09;          // Start time (hour)
input uchar                InpStartMin             = 00;          // Start time (minute)
input uchar                InpEndHour              = 16;          // End time (hour)
input uchar                InpEndtMin              = 30;          // End time (hour)
//---
ulong          m_magic=15489;                // magic number
ulong          m_slippage=10;                 // slippage
double         ExtLot=0.0;
double         ExtStopLoss=0.0;
double         ExtTakeProfit=0.0;
double         m_adjusted_point;             // point value adjusted for 3 or 5 points
int            StopCount=0;
bool           m_close_all=false;
//---
MqlRates       candle[];
int            MA1_Handle;
double         MA1_Buffer[];
int            MA2_Handle;
double         MA2_Buffer[];
int            Hilo_Handle;
double         Hilo_Buffer[];
//---
long           lLastOpenBuy=0;
long           lLastOpenSell=0;
long           time_start=-1;
long           time_end=-1;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   time_start  = InpStartHour*60*60 + InpStartMin*60;
   time_end    = InpEndHour*60*60   + InpEndtMin*60;
//---
   m_symbol.Name(Symbol());                  // sets symbol name
   RefreshRates();
   m_symbol.Refresh();
   ArraySetAsSeries(candle,true);
   //ArraySetAsSeries(MA1_Buffer,true);
   //ArraySetAsSeries(MA2_Buffer,true);
   ArraySetAsSeries(Hilo_Buffer,true);
//---
  //MA1_Handle = iMA(_Symbol,_Period,InpMA_Hilo,0,InpMA_ma_method,PRICE_HIGH);
  //MA2_Handle = iMA(_Symbol,_Period,InpMA_Hilo,0,InpMA_ma_method,PRICE_LOW);
  Hilo_Handle = iCustom(_Symbol,_Period,"gann_hi_lo_activator_ssl.ex5",InpMA_Hilo,InpMA_ma_method);
//---
   m_trade.SetExpertMagicNumber(m_magic);
//---
   if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_FOK))
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_IOC))
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
//---
   m_trade.SetDeviationInPoints(m_slippage);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

   ExtLot         = Lote;
   ExtStopLoss    = InpStopLoss     * m_adjusted_point;
   ExtTakeProfit  = InpTakeProfit   * m_adjusted_point;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   CopyRates(_Symbol,_Period,0,5,candle);
   //CopyBuffer(MA1_Handle,0,0,60,MA1_Buffer);
   //CopyBuffer(MA2_Handle,0,0,60,MA2_Buffer);
   CopyBuffer(Hilo_Handle,0,0,5,Hilo_Buffer);
   bool newBar = isNewBar();
//---
   if(ProfitAllPositions()>=InpProfit)
      {
      m_close_all=true;
      return;
      }
//---
   if(m_close_all)
     {
      CloseAllPositions();
      if(!IsPositionExists())
         m_close_all=false;
      else
         return;
     }
   int count_buys = 0;
   int count_sells= 0;
   double profit  = 0.0;
   CalculatePositions(count_buys,count_sells,profit);
//---
   MqlDateTime STimeCurrent;
   TimeToStruct(TimeCurrent(),STimeCurrent);
   long time_curr=STimeCurrent.hour*60*60+STimeCurrent.min*60;
   if(time_curr<time_start || time_curr>time_end)
      return;
//---              
      if(!RefreshRates())
         return;           
               if(newBar)
                  {
                  // BUY SIGNAL
                  if(count_buys<1 && candle[0].close > Hilo_Buffer[0])
                    {
                     //---
                     Print("OPEN BUY ORDER !!!", lLastOpenBuy);
                     ClosePositions(POSITION_TYPE_SELL);
                     double sl=(InpStopLoss==0)?0.0:m_symbol.Ask()-ExtStopLoss;
                     double tp=(InpTakeProfit==0)?0.0:m_symbol.Ask()+ExtTakeProfit;
                     OpenBuy(ExtLot,sl,tp);
                     
                    }
                  // SELL SIGNAL
                  if(count_sells<1 && candle[0].close < Hilo_Buffer[0])
                    {
                     //---
                     Print("OPEN SELL ORDER !!!", lLastOpenSell);
                     ClosePositions(POSITION_TYPE_BUY);
                     double sl=(InpStopLoss==0)?0.0:m_symbol.Bid()+ExtStopLoss;
                     double tp=(InpTakeProfit==0)?0.0:m_symbol.Bid()-ExtTakeProfit;
                     OpenSell(ExtLot,sl,tp);   
                          
                    }
                 }                           
//---
  }
//+------------------------------------------------------------------+
//| Returns true if a new bar has appeared for a symbol/period pair  |
//+------------------------------------------------------------------+
bool isNewBar()
  {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0)
     {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
     }

//--- if the time differs
   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
      return(false);
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+ 
//| Checks if the specified filling mode is allowed                  | 
//+------------------------------------------------------------------+ 
bool IsFillingTypeAllowed(string symbol,int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes 
   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//--- Return true, if mode fill_type is allowed 
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+
//| Calculate positions Buy and Sell                                 |
//+------------------------------------------------------------------+
void CalculatePositions(int &count_buys,int &count_sells,double &profit)
  {
   count_buys=0;
   count_sells=0;
   profit=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            profit+=m_position.Commission()+m_position.Swap()+m_position.Profit();
            if(m_position.PositionType()==POSITION_TYPE_BUY)
               count_buys++;

            if(m_position.PositionType()==POSITION_TYPE_SELL)
               count_sells++;
           }
//---
   return;
  }
//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResult(CTrade &trade,CSymbolInfo &symbol)
  {
   Print("Code of request result: "+IntegerToString(trade.ResultRetcode()));
   Print("code of request result: "+trade.ResultRetcodeDescription());
   Print("deal ticket: "+IntegerToString(trade.ResultDeal()));
   Print("order ticket: "+IntegerToString(trade.ResultOrder()));
   Print("volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
   Print("price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits()));
   Print("current bid price: "+DoubleToString(trade.ResultBid(),symbol.Digits()));
   Print("current ask price: "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
   Print("broker comment: "+trade.ResultComment());
//int d=0;
  }
//+------------------------------------------------------------------+
//| Close positions                                                  |
//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE pos_type)
  {
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
         if(m_position.Symbol()==Symbol() && m_position.Magic()==m_magic)
            if(m_position.PositionType()==pos_type) // gets the position type
               m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(double lot,double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double volume=LotCheck(lot);
   if(volume==0.0)
      return;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),volume,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=volume)
        {
         if(m_trade.Buy(volume,NULL,m_symbol.Ask(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
            else
              {
               Print("Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
           }
         else
           {
            Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResult(m_trade,m_symbol);
           }
        }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell(double lot,double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double volume=LotCheck(lot);
   if(volume==0.0)
      return;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),volume,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=volume)
        {
         if(m_trade.Sell(volume,NULL,m_symbol.Bid(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
            else
              {
               Print("Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
           }
         else
           {
            Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResult(m_trade,m_symbol);
           }
        }
//---
  }
//+------------------------------------------------------------------+
//| Lot Check                                                        |
//+------------------------------------------------------------------+
double LotCheck(double lots)
  {
//--- calculate maximum volume
   double volume=NormalizeDouble(lots,2);
   double stepvol=m_symbol.LotsStep();
   if(stepvol>0.0)
      volume=stepvol*MathFloor(volume/stepvol);
//---
   double minvol=m_symbol.LotsMin();
   if(volume<minvol)
      volume=0.0;
//---
   double maxvol=m_symbol.LotsMax();
   if(volume>maxvol)
      volume=maxvol;
   return(volume);
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//--- get transaction type as enumeration value 
   ENUM_TRADE_TRANSACTION_TYPE type=trans.type;
//--- if transaction is result of addition of the transaction in history
   if(type==TRADE_TRANSACTION_DEAL_ADD)
     {
      long     deal_type         =-1;
      long     deal_time         =0;
      long     deal_time_msc     =0;
      long     deal_entry        =0;
      double   deal_profit       =0.0;
      double   deal_volume       =0.0;
      string   deal_symbol       ="";
      long     deal_magic        =0;
      long     deal_reason       =-1;
      if(HistoryDealSelect(trans.deal))
        {
         deal_type=HistoryDealGetInteger(trans.deal,DEAL_TYPE);
         deal_time=HistoryDealGetInteger(trans.deal,DEAL_TIME);
         deal_time_msc=HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC);
         deal_entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
         deal_profit=HistoryDealGetDouble(trans.deal,DEAL_PROFIT);
         deal_volume=HistoryDealGetDouble(trans.deal,DEAL_VOLUME);
         deal_symbol=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
         deal_magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
         deal_reason=HistoryDealGetInteger(trans.deal,DEAL_REASON);
        }
      else
         return;
      if(deal_symbol==m_symbol.Name() && deal_magic==m_magic)
         if(deal_entry==DEAL_ENTRY_OUT)
           {
            if(deal_reason==DEAL_REASON_SL){
               StopCount++;
               Print("Trigou o stop loss!! ",StopCount);
                   if(StopCount>=Consecutive_Loss_Revert){
                   ExtLot*=Revert_Rate;
                   }
                   else
                   ExtLot=Lote;
               }
            else if(deal_reason==DEAL_REASON_TP){
               StopCount=0;
               ExtLot=Lote;
               }
           }
     }
  }
//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
         m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
  }
//+------------------------------------------------------------------+
//| Is position exists                                               |
//+------------------------------------------------------------------+
bool IsPositionExists(void)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         return(true);
//---
   return(false);
  }
//+------------------------------------------------------------------+
//| Profit all positions                                             |
//+------------------------------------------------------------------+
double ProfitAllPositions()
  {
   double profit=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         profit+=m_position.Commission()+m_position.Swap()+m_position.Profit();
//---
   return(profit);
  }
//+------------------------------------------------------------------+
