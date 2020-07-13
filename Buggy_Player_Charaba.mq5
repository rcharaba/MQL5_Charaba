//+------------------------------------------------------------------+
//|                                         Buggy_Player_Charaba.mq5 |
//|                                 Copyright 2020, Rodrigo Charaba. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Rodrigo Charaba"
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
CPositionInfo  m_position;           // trade position object
CTrade         m_trade;              // trading object
CSymbolInfo    m_symbol;             // symbol info object
//--- enums
enum eAllowedTrades
  {
   BUY,                             // BUY Only
   SELL,                            // SELL Only
  };
//--- input parameters
input int      Lote                 = 5;
input ushort   InpStopLoss          = 300;         // Stop Loss (in pips)
input ushort   InpTakeProfit        = 100;         // Take Profit (in pips)
input int      Hour_Aperture        = 10;
input int      Minute_Aperture      = 02;
input eAllowedTrades Buy_Sell       =SELL;
input double   Revert_Rate          = 3;
input int      SL_Revert            = 300;
input int      TP_Revert            = 200;
//---
ulong          m_magic              =15489;        // magic number
ulong          m_slippage           =5;            // slippage
bool           stop_trigg           =false;
bool           stop_1x              =false;
double         ExtLot               =0.0;
double         ExtStopLoss          =0.0;
double         ExtTakeProfit        =0.0;
double         m_adjusted_point;                   // point value adjusted for 3 or 5 points

MqlRates candle[];                                 // access candle data
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   m_symbol.Name(Symbol());                  // sets symbol name
   RefreshRates();
   m_symbol.Refresh();
   ArraySetAsSeries(candle,true);
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
   bool newBar = isNewBar();
//---
   if(CalculateAllPositions()==0)
     {
      if(!RefreshRates())
         return;
         if(stop_trigg)
         {
            if(!stop_1x)
               {
               if(Buy_Sell==SELL)
                     {  
                      Print("Revert Buy order");
                      ExtLot*=Revert_Rate;
                      double sl=(InpStopLoss==0)?0.0:m_symbol.Ask()-SL_Revert;
                      double tp=(InpTakeProfit==0)?0.0:m_symbol.Ask()+TP_Revert;
                      OpenBuy(ExtLot,sl,tp);
                     }
               else if(Buy_Sell==BUY)
                     {  
                      Print("Revert Sell order");
                      ExtLot*=Revert_Rate;
                      double sl=(InpStopLoss==0)?0.0:m_symbol.Bid()+SL_Revert;
                      double tp=(InpTakeProfit==0)?0.0:m_symbol.Bid()-TP_Revert;
                      OpenSell(ExtLot,sl,tp);
                     }
                 stop_1x=true;
                 }
            stop_trigg = false;
         }            
         int total, Hour_Int, Minute_Int, Sec_Int;
         MqlDateTime str1;
         TimeToStruct(TimeCurrent(),str1);
         total = OrdersTotal(); 
         Hour_Int = str1.hour;
         Minute_Int = str1.min;
         Sec_Int = str1.sec;
         if(Hour_Int == Hour_Aperture && Minute_Int == Minute_Aperture && Sec_Int == 00 && newBar)
         {Print("Time Condition is satisfied");
            if(total<1)
            {Print("There are no orders open");
            stop_trigg = false;
            stop_1x= false;
                  if(Buy_Sell==BUY)
                  { 
                     ClosePositions(POSITION_TYPE_SELL);
                     Print("Open Buy order");
                     double sl=(InpStopLoss==0)?0.0:m_symbol.Ask()-ExtStopLoss;
                     double tp=(InpTakeProfit==0)?0.0:m_symbol.Ask()+ExtTakeProfit;
                     OpenBuy(ExtLot,sl,tp);
                  }
                  else if(Buy_Sell==SELL)
                  {  
                     ClosePositions(POSITION_TYPE_BUY);
                     Print("Open Sell order");
                     double sl=(InpStopLoss==0)?0.0:m_symbol.Bid()+ExtStopLoss;
                     double tp=(InpTakeProfit==0)?0.0:m_symbol.Bid()-ExtTakeProfit;
                     OpenSell(ExtLot,sl,tp);
                  }
            } 
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
//| Calculate all positions Buy and Sell                             |
//+------------------------------------------------------------------+
int CalculateAllPositions()
  {
   int totlal=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
            totlal++;
//---
   return(totlal);
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
              }
            else
              {
               Print("Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
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
              }
            else
              {
               Print("Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
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
      long     deal_entry        =0;
      double   deal_profit       =0.0;
      double   deal_volume       =0.0;
      string   deal_symbol       ="";
      long     deal_magic        =0;
      long     deal_reason       =-1;
      if(HistoryDealSelect(trans.deal))
        {
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
            if(deal_reason==DEAL_REASON_SL)
               Print("Stop Loss was Triggered!!");
               stop_trigg = true;
            if(deal_reason==DEAL_REASON_TP)
               stop_trigg = false;
               ExtLot=Lote;
           }
     }
  }
//+------------------------------------------------------------------+
