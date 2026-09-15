//+------------------------------------------------------------------+
//| Risk/RR Auto Trade EA - Pre-trade Risk Check                     |
//|                                                                    |
//| Enter Direction / StopLossPrice / RiskPercent / RR, attach to a   |
//| chart, and it opens ONE trade. A persistent flag (MT5              |
//| GlobalVariable) prevents it from ever opening a second trade,      |
//| even if you remove & re-add the EA, or close & reopen MT5.         |
//+------------------------------------------------------------------+
#property strict
#property description "Opens a single trade on attach based on Direction/SL/Risk/RR inputs."
#include <Trade\Trade.mqh>

CTrade m_trade;

//--- Direction shows as a dropdown (Long/Short) in the Inputs tab
enum DirectionType
  {
   LONG,    // Long
   SHORT    // Short
  };

//===================== TRADE SETUP =====================
input group "===== TRADE SETUP ====="
input bool          ResetArmFlag     = false;      // Set TRUE once to allow a NEW trade, then set back to FALSE
input DirectionType TradeDirection   = LONG;      // Direction
input double        RiskPercent      = 0.25;      // % of account to risk
input double        StopLossPrice    = 0;         // Absolute SL price
input double        RR               = 2;         // Risk:Reward
input double        MaxRiskPercent   = 1.0;        // Max risk allowed before confirmation popup
input long          MagicNumber      = 20260914;   // Unique ID for this EA's trades

//===================== spacer =====================
input group " "

//===================== READ BEFORE USE =====================
input group "===== READ BEFORE USE ====="
input string Note1_ = "This EA opens ONE trade automatically the moment it is attached.";
input string Note2_ = "Requires: toolbar AutoTrading button ON + this EA's 'Allow Algo Trading' checked (Common tab).";
input string Note3_ = "Set StopLossPrice as an ABSOLUTE price, matching the Direction above.";
input string Note4_ = "After a trade fires it LOCKS (survives removing the EA / restarting MT5).";
input string Note5_ = "To take a new trade: set ResetArmFlag = true, re-attach, then set it back to false.";
input string Note6_ = "Use a different MagicNumber per instance if you run this on multiple charts.";

//--- Internal variables
double LotSize    = 0;
double TPPrice    = 0;
double RiskAmount = 0;
string g_flagName;              // persistent "already traded" flag, unique per symbol+magic
bool   g_permissionRetryPending = false;  // true if we still owe an attempt once permissions turn on

//+------------------------------------------------------------------+
//| Persistent flag helpers                                          |
//| MT5 GlobalVariables are stored by the terminal, not the EA, so   |
//| they survive removing the EA, restarting MT5, even rebooting.    |
//+------------------------------------------------------------------+
bool AlreadyArmed()
{
   return (GlobalVariableCheck(g_flagName) && GlobalVariableGet(g_flagName) == 1.0);
}

void SetArmed()
{
   GlobalVariableSet(g_flagName, 1.0);
}

//+------------------------------------------------------------------+
//| Belt-and-braces: is there already a live position for this       |
//| symbol + magic number, regardless of what the flag says?         |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Checks all 3 independent "can this EA actually trade" switches:  |
//|  1) Toolbar AutoTrading button (terminal-wide)                   |
//|  2) This EA's "Allow Algo Trading" checkbox (Common tab)         |
//|  3) The account itself permitting automated trading              |
//| None of these are visually linked in MT5, so we surface them     |
//| ourselves rather than let a trade silently fail to fire.         |
//+------------------------------------------------------------------+
bool IsAlgoTradingAllowed(string &reason)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      reason = "AutoTrading button (toolbar) is OFF";
      return false;
   }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      reason = "'Allow Algo Trading' unchecked for this EA (Common tab)";
      return false;
   }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      reason = "This account does not permit automated trading";
      return false;
   }
   reason = "";
   return true;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk % and SL, normalized to what    |
//| the broker actually allows (min/max/step).                       |
//+------------------------------------------------------------------+
double CalculateLot(double sl_price)
{
   double tick_value      = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tick_size       = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   double entry_price = (TradeDirection==LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double sl_distance = MathAbs(entry_price - sl_price);
   if(sl_distance <= 0) sl_distance = tick_size;

   RiskAmount = account_balance * (RiskPercent/100.0);
   double raw_lot = RiskAmount / (sl_distance / tick_size * tick_value);

   double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = 0.01;

   double norm_lot = MathFloor(raw_lot/lotStep) * lotStep;
   if(norm_lot < minLot) norm_lot = minLot;
   if(norm_lot > maxLot) norm_lot = maxLot;

   int digits = 2;
   if(lotStep < 0.01)      digits = 3;
   else if(lotStep < 0.1)  digits = 2;
   else                    digits = 1;

   LotSize = NormalizeDouble(norm_lot, digits);
   return LotSize;
}

//+------------------------------------------------------------------+
//| Calculate TP based on SL and R:R                                 |
//+------------------------------------------------------------------+
double CalculateTP(double sl_price)
{
   double entry_price = (TradeDirection==LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol,SYMBOL_BID);

   TPPrice = (TradeDirection==LONG) ? entry_price + RR*MathAbs(entry_price - sl_price)
                                     : entry_price - RR*MathAbs(entry_price - sl_price);
   return TPPrice;
}

//+------------------------------------------------------------------+
//| Sanity-check inputs before doing anything else                   |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   if(StopLossPrice <= 0)
   {
      Print("Error: Set a valid StopLossPrice");
      return false;
   }
   if(RiskPercent <= 0)
   {
      Print("Error: Set RiskPercent > 0");
      return false;
   }
   if(RR <= 0)
   {
      Print("Error: Set RR > 0");
      return false;
   }

   double entry_price = (TradeDirection==LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(TradeDirection==LONG && StopLossPrice >= entry_price)
   {
      Print("Error: For a LONG trade, StopLossPrice must be BELOW the current Ask (",entry_price,")");
      return false;
   }
   if(TradeDirection==SHORT && StopLossPrice <= entry_price)
   {
      Print("Error: For a SHORT trade, StopLossPrice must be ABOVE the current Bid (",entry_price,")");
      return false;
   }

   long stopsLevelPoints = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevelPoints > 0)
   {
      double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      double minDistance = stopsLevelPoints * point;
      if(MathAbs(entry_price - StopLossPrice) < minDistance)
      {
         Print("Error: StopLossPrice is closer than the broker's minimum stop distance (",
               DoubleToString(minDistance,_Digits),")");
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Pre-trade risk check (manual confirmation above MaxRiskPercent)  |
//+------------------------------------------------------------------+
bool CheckRisk()
{
   if(RiskPercent > MaxRiskPercent)
   {
      int response = MessageBox("WARNING: Your risk is " + DoubleToString(RiskPercent,2) +
                                 "% of account. Continue?", "High Risk", MB_YESNO|MB_ICONWARNING);
      return (response == IDYES);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Margin check                                                      |
//+------------------------------------------------------------------+
bool CheckMargin(double lot)
{
   ENUM_ORDER_TYPE orderType = (TradeDirection==LONG) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = (TradeDirection==LONG) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double marginRequired = 0;
   if(!OrderCalcMargin(orderType,_Symbol,lot,price,marginRequired))
   {
      Print("Warning: could not calculate required margin, proceeding cautiously.");
      return true;
   }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(marginRequired > freeMargin)
   {
      Print("Error: Insufficient margin. Required=",marginRequired," Free=",freeMargin);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Open trade function                                              |
//| Returns true only when a genuine "permission blocked" situation  |
//| was hit, so the caller knows whether to retry later.              |
//+------------------------------------------------------------------+
bool OpenTrade()
{
   if(AlreadyArmed())
   {
      Print("Trade already taken previously (flag=",g_flagName,"). Not opening another. ",
            "Set ResetArmFlag=true to intentionally re-arm.");
      return false;
   }

   if(HasOpenPosition())
   {
      Print("A position already exists for this symbol/magic. Not opening another.");
      SetArmed();
      return false;
   }

   string reason;
   if(!IsAlgoTradingAllowed(reason))
   {
      Print("Cannot trade yet - ", reason, ". Will retry automatically once fixed.");
      return true; // permission-blocked: caller should retry later
   }

   if(!ValidateInputs())
      return false;

   double lot = CalculateLot(StopLossPrice);
   double tp  = CalculateTP(StopLossPrice);

   if(!CheckMargin(lot))
      return false;

   if(!CheckRisk())
   {
      Print("Trade cancelled due to high risk.");
      return false;
   }

   m_trade.SetExpertMagicNumber(MagicNumber);

   bool success;
   if(TradeDirection==LONG)
      success = m_trade.Buy(lot,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_ASK),StopLossPrice,tp);
   else
      success = m_trade.Sell(lot,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_BID),StopLossPrice,tp);

   if(success)
   {
      Print("Trade opened: ",(TradeDirection==LONG?"Buy":"Sell")," Lot=",lot," SL=",StopLossPrice," TP=",tp);
      SetArmed();
   }
   else
   {
      Print("Trade failed: ", GetLastError());
   }
   return false;
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_flagName = "EA_ArmDone_" + _Symbol + "_" + IntegerToString(MagicNumber);

   if(ResetArmFlag)
   {
      if(GlobalVariableCheck(g_flagName))
         GlobalVariableDel(g_flagName);
      Print("ResetArmFlag was TRUE: cleared the lock for ",g_flagName,
            ". Remember to set ResetArmFlag back to FALSE.");
   }

   g_permissionRetryPending = OpenTrade(); // true only if blocked purely by trading permissions
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//| If the only thing that stopped us trading on attach was the      |
//| AutoTrading / Algo Trading permission, keep watching and fire     |
//| automatically the moment it's switched on - no need to remove     |
//| and re-attach the EA.                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_permissionRetryPending && !AlreadyArmed() && !HasOpenPosition())
   {
      string reason;
      if(IsAlgoTradingAllowed(reason))
      {
         OpenTrade();
         g_permissionRetryPending = false; // only ever auto-retry once
      }
   }
}

//+------------------------------------------------------------------+
//| Deinit                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
