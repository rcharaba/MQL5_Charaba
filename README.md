# MQL5_Charaba

My first steps with MQL5 (Trading automation).

Step 0: Learn about the basics of technical analysis, this is a mandatory step. There's a lot of information on google.

1) My first free youtube course:
    https://www.youtube.com/watch?v=H3TgD97Cy-k&list=PLV8YK-9p3TcOmgAFIjntw-GxOJoHp9xwc
    
2) Code base MQL5:
    https://www.mql5.com/en/code/mt5/experts
    
3) Some studies about revert trade strategy
    https://www.mql5.com/en/articles/5008
    
4) My first code (Buggy_Player_Charaba.mq5) is a simple trade strategy based on a "critical time of day" trade. This strategy was only tested in Brazilian index (WIN). The other strategies follow basically the same rule.  

input int      Lote                 = 5;           // lot  
input ushort   InpStopLoss          = 300;         // Stop Loss (in pips)  
input ushort   InpTakeProfit        = 100;         // Take Profit (in pips)  
input int      Hour_Aperture        = 10;          // Hour to open order  
input int      Minute_Aperture      = 02;          // Minute to open order  
input eAllowedTrades Buy_Sell       =SELL;         // Buy or Sell trade  
input double   Revert_Rate          = 3;           // If you lose, that is the ration to increment the lot (revert trade)  
input int      SL_Revert            = 300;         // Take Profit revert (in pips)  
input int      TP_Revert            = 200;         // Stop Loss revert (in pips)  

Disclaimer: This is only a study and for knowledge purposes, i'm not responsible for any consequences about this strategy in real accounts.
