//+------------------------------------------------------------------+
//| Open Trades Risk Monitor                                          |
//|                                                                    |
//| Sits on the chart and lists every open position across the whole  |
//| account (any symbol), showing lot size, risk $ (to SL), potential |
//| reward $ (to TP), R:R, and floating P/L - plus a totals row.      |
//| This EA never places or modifies trades - display only.          |
//+------------------------------------------------------------------+
#property strict
#property description "Read-only dashboard: lists all open positions with risk / reward / R:R / floating P&L."

//--- Panel layout constants
#define PANEL_X       12     // distance of panel's right edge from chart's right edge
#define PANEL_Y       18     // distance of panel's top edge from chart's top edge
#define PANEL_WIDTH   470
#define ROW_HEIGHT    18
#define TITLE_Y       26
#define HEADER_Y      52
#define ROWS_START_Y  72

//--- Column offsets, measured from the panel's LEFT edge
#define COL_SYMBOL   14
#define COL_TYPE     95
#define COL_LOT      145
#define COL_RISK     195
#define COL_REWARD   275
#define COL_RR       355
#define COL_PL       405

//--- Colors
color c_bg      = C'20,24,34';
color c_border  = C'70,80,100';
color c_title   = C'220,225,235';
color c_header  = C'150,160,175';
color c_value   = C'225,228,235';
color c_profit  = C'90,220,140';
color c_loss    = C'255,110,110';
color c_warn    = C'255,180,80';

string g_prefix = "RiskMonitor_";
int    g_lastRowCount = 0;

//+------------------------------------------------------------------+
//| Helper: place a label using CORNER_RIGHT_UPPER, where x is       |
//| measured from the PANEL'S left edge (see macro comment above).   |
//+------------------------------------------------------------------+
void SetLabel(string name,int colOffset,int y,string text,color clr,int size=9,string font="Segoe UI")
{
   int xdist = PANEL_X + PANEL_WIDTH - colOffset;
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,xdist);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void EnsureBackground(int heightPx)
{
   string bg = g_prefix+"bg";
   if(ObjectFind(0,bg) < 0)
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,PANEL_X);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,PANEL_Y);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,PANEL_WIDTH);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,heightPx);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,c_bg);
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,c_border);
   ObjectSetInteger(0,bg,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,bg,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
}

void DeleteRow(int i)
{
   ObjectDelete(0,g_prefix+"r"+IntegerToString(i)+"_sym");
   ObjectDelete(0,g_prefix+"r"+IntegerToString(i)+"_type");
   ObjectDelete(0,g_prefix+"r"+IntegerToString(i)+"_lot");
   ObjectDelete(0,g_prefix+"r"+IntegerToString(i)+"_risk");
   ObjectDelete(0,g_prefix+"r"+IntegerToString(i)+"_reward");
   ObjectDelete(0,g_prefix+"r"+IntegerToString(i)+"_rr");
   ObjectDelete(0,g_prefix+"r"+IntegerToString(i)+"_pl");
}

//+------------------------------------------------------------------+
//| Money-value formatter with a leading +/- sign                    |
//+------------------------------------------------------------------+
string FmtMoney(double v)
{
   return (v>=0 ? "+" : "") + DoubleToString(v,2);
}

//+------------------------------------------------------------------+
//| Main refresh: pulls every open position, renders the table       |
//+------------------------------------------------------------------+
void RefreshPanel()
{
   int total = PositionsTotal();

   if(total == 0)
   {
      EnsureBackground(ROWS_START_Y + 10);
      SetLabel(g_prefix+"title",COL_SYMBOL,TITLE_Y,"OPEN TRADES",c_title,10);
      SetLabel(g_prefix+"empty",COL_SYMBOL,HEADER_Y,"No open trades",c_header,9);
      // clean up any leftover header/rows/totals from a previous non-empty state
      ObjectDelete(0,g_prefix+"h_sym"); ObjectDelete(0,g_prefix+"h_type");
      ObjectDelete(0,g_prefix+"h_lot"); ObjectDelete(0,g_prefix+"h_risk");
      ObjectDelete(0,g_prefix+"h_reward"); ObjectDelete(0,g_prefix+"h_rr");
      ObjectDelete(0,g_prefix+"h_pl");
      ObjectDelete(0,g_prefix+"tot_lbl"); ObjectDelete(0,g_prefix+"tot_risk");
      ObjectDelete(0,g_prefix+"tot_reward"); ObjectDelete(0,g_prefix+"tot_pl");
      for(int i=0;i<g_lastRowCount;i++) DeleteRow(i);
      g_lastRowCount = 0;
      ChartRedraw(0);
      return;
   }

   ObjectDelete(0,g_prefix+"empty");

   SetLabel(g_prefix+"title",COL_SYMBOL,TITLE_Y,"OPEN TRADES",c_title,10);
   SetLabel(g_prefix+"h_sym",COL_SYMBOL,HEADER_Y,"Symbol",c_header,8);
   SetLabel(g_prefix+"h_type",COL_TYPE,HEADER_Y,"Type",c_header,8);
   SetLabel(g_prefix+"h_lot",COL_LOT,HEADER_Y,"Lot",c_header,8);
   SetLabel(g_prefix+"h_risk",COL_RISK,HEADER_Y,"Risk $",c_header,8);
   SetLabel(g_prefix+"h_reward",COL_REWARD,HEADER_Y,"Reward $",c_header,8);
   SetLabel(g_prefix+"h_rr",COL_RR,HEADER_Y,"R:R",c_header,8);
   SetLabel(g_prefix+"h_pl",COL_PL,HEADER_Y,"P/L",c_header,8);

   double totalRisk = 0, totalReward = 0, totalPL = 0;

   for(int i=0; i<total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      string sym      = PositionGetString(POSITION_SYMBOL);
      long   posType  = PositionGetInteger(POSITION_TYPE);
      double volume   = PositionGetDouble(POSITION_VOLUME);
      double sl       = PositionGetDouble(POSITION_SL);
      double tp       = PositionGetDouble(POSITION_TP);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double profit   = PositionGetDouble(POSITION_PROFIT);

      double tick_value = SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
      double tick_size  = SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
      int    digits     = (int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
      if(tick_size <= 0) tick_size = SymbolInfoDouble(sym,SYMBOL_POINT);

      bool   hasSL = (sl > 0);
      bool   hasTP = (tp > 0);
      // Committed risk/reward: measured from ENTRY price, not the live price,
      // so these stay fixed unless you actually move the SL/TP.
      double riskMoney   = hasSL ? (MathAbs(openPrice-sl)/tick_size*tick_value*volume) : 0;
      double rewardMoney = hasTP ? (MathAbs(tp-openPrice)/tick_size*tick_value*volume) : 0;

      if(hasSL) totalRisk   += riskMoney;
      if(hasTP) totalReward += rewardMoney;
      totalPL += profit;

      int y = ROWS_START_Y + i*ROW_HEIGHT;
      string ri = IntegerToString(i);

      SetLabel(g_prefix+"r"+ri+"_sym",COL_SYMBOL,y,sym,c_value,9);
      SetLabel(g_prefix+"r"+ri+"_type",COL_TYPE,y,
               (posType==POSITION_TYPE_BUY ? "Buy" : "Sell"),
               (posType==POSITION_TYPE_BUY ? c_profit : c_loss),9);
      SetLabel(g_prefix+"r"+ri+"_lot",COL_LOT,y,DoubleToString(volume,2),c_value,9);
      SetLabel(g_prefix+"r"+ri+"_risk",COL_RISK,y,
               hasSL ? DoubleToString(riskMoney,2) : "No SL",
               hasSL ? c_value : c_warn,9);
      SetLabel(g_prefix+"r"+ri+"_reward",COL_REWARD,y,
               hasTP ? DoubleToString(rewardMoney,2) : "No TP",
               hasTP ? c_value : c_warn,9);
      SetLabel(g_prefix+"r"+ri+"_rr",COL_RR,y,
               (hasSL && hasTP && riskMoney>0) ? DoubleToString(rewardMoney/riskMoney,2) : "-",
               c_value,9);
      SetLabel(g_prefix+"r"+ri+"_pl",COL_PL,y,FmtMoney(profit),
               (profit>=0 ? c_profit : c_loss),9);
   }

   // clean up rows left over from a previous, larger position count
   for(int i=total; i<g_lastRowCount; i++) DeleteRow(i);
   g_lastRowCount = total;

   int totalsY = ROWS_START_Y + total*ROW_HEIGHT + 8;
   SetLabel(g_prefix+"tot_lbl",COL_SYMBOL,totalsY,"TOTAL",c_title,9);
   SetLabel(g_prefix+"tot_risk",COL_RISK,totalsY,DoubleToString(totalRisk,2),c_warn,9);
   SetLabel(g_prefix+"tot_reward",COL_REWARD,totalsY,DoubleToString(totalReward,2),c_profit,9);
   SetLabel(g_prefix+"tot_pl",COL_PL,totalsY,FmtMoney(totalPL),
            (totalPL>=0 ? c_profit : c_loss),9);

   EnsureBackground(totalsY + 26);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(1); // refresh at least once a second even on quiet symbols
   RefreshPanel();
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   RefreshPanel();
}

void OnTimer()
{
   RefreshPanel();
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0,g_prefix);
   ChartRedraw(0);
}
