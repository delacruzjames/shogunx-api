#property strict

// MT4 WebRequest ONLY allows http port 80 and https port 443 — no :3000 in URLs.
// Run API with: make upd (maps host port 80 -> container 3000).
// Whitelist in MT4: http://127.0.0.1  (or http://YOUR_MAC_IP if MT4 is in a VM).
input string ApiHost                = "127.0.0.1";
input int    ApiPort                = 80;    // must be 80 (http) or 443 (https)
input int    IntervalSeconds        = 14400;  // 4 hours (4 * 60 * 60)
input int    RsiPeriod              = 14;
input int    EmaFastPeriod          = 50;
input int    EmaSlowPeriod          = 200;
input int    SupportResistanceBars  = 20;
input double LotSize                = 0.01;
input int    Slippage               = 3;
input int    MagicNumber            = 20260603;
input int    OrderPollSeconds       = 5;     // poll for trigger/close; 0 = disable
input bool   VerboseLog             = true;

string g_signalsUrl         = "";
string g_orderUpdatesUrl    = "";
string g_positionUpdatesUrl = "";
string g_executionUrl       = "";
string g_apiBase            = "";
datetime g_lastOrderPoll = 0;

void Log(string message)
{
   if(!VerboseLog)
      return;
   Print("[ShogunX] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " ", message);
}

string ApiBase()
{
   if(ApiPort == 80)
      return StringFormat("http://%s", ApiHost);
   if(ApiPort == 443)
      return StringFormat("https://%s", ApiHost);
   return StringFormat("http://%s:%d", ApiHost, ApiPort);
}

string SignalsUrl()
{
   return ApiBase() + "/api/v1/signals";
}

string OrderUpdatesUrl()
{
   return ApiBase() + "/api/v1/order_updates";
}

string PositionUpdatesUrl()
{
   return ApiBase() + "/api/v1/position_updates";
}

string ExecutionUrl()
{
   return ApiBase() + "/api/v1/execution";
}

string ChartTimeframe()
{
   switch(Period())
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return IntegerToString((int)Period());
   }
}

double RecentLow(int bars)
{
   double lowest = iLow(Symbol(), Period(), 0);
   int i;

   for(i = 1; i < bars; i++)
   {
      double value = iLow(Symbol(), Period(), i);
      if(value < lowest)
         lowest = value;
   }

   return lowest;
}

double RecentHigh(int bars)
{
   double highest = iHigh(Symbol(), Period(), 0);
   int i;

   for(i = 1; i < bars; i++)
   {
      double value = iHigh(Symbol(), Period(), i);
      if(value > highest)
         highest = value;
   }

   return highest;
}

double RecentLowOnPeriod(int period, int bars)
{
   double lowest = iLow(Symbol(), period, 0);
   int i;

   for(i = 1; i < bars; i++)
   {
      double value = iLow(Symbol(), period, i);
      if(value < lowest)
         lowest = value;
   }

   return lowest;
}

double RecentHighOnPeriod(int period, int bars)
{
   double highest = iHigh(Symbol(), period, 0);
   int i;

   for(i = 1; i < bars; i++)
   {
      double value = iHigh(Symbol(), period, i);
      if(value > highest)
         highest = value;
   }

   return highest;
}

string TimeframeMetricsJson(int period)
{
   double price = iClose(Symbol(), period, 0);
   double rsi = iRSI(Symbol(), period, RsiPeriod, PRICE_CLOSE, 0);
   double ema50 = iMA(Symbol(), period, EmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema200 = iMA(Symbol(), period, EmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double support = RecentLowOnPeriod(period, SupportResistanceBars);
   double resistance = RecentHighOnPeriod(period, SupportResistanceBars);

   return StringConcatenate(
      "\"price\":", PriceJson(price),
      ",\"rsi\":", PriceJson(rsi),
      ",\"ema50\":", PriceJson(ema50),
      ",\"ema200\":", PriceJson(ema200),
      ",\"support\":", PriceJson(support),
      ",\"resistance\":", PriceJson(resistance)
   );
}

string PriceJson(double value)
{
   return DoubleToString(value, Digits);
}

bool WebGet(string url, string &body, int &httpCode)
{
   char data[];
   char result[];
   string response_headers;

   ResetLastError();
   httpCode = WebRequest("GET", url, NULL, NULL, 5000, data, 0, result, response_headers);

   if(httpCode == -1)
      return false;

   body = CharArrayToString(result);
   return true;
}

bool WebPostJson(string url, const string payload, string &body, int &httpCode)
{
   char post[];
   int len = StringToCharArray(payload, post);
   if(len > 0)
      ArrayResize(post, len - 1);

   char result[];
   string reqHeaders = "Content-Type: application/json\r\nAccept: application/json\r\n";
   string response_headers;

   ResetLastError();
   httpCode = WebRequest("POST", url, reqHeaders, 5000, post, result, response_headers);

   if(httpCode == -1)
      return false;

   body = CharArrayToString(result);
   return true;
}

void LogWebRequestError(int err)
{
   string hint = "";

   if(err == 4060 || err == 5200)
   {
      hint = " MT4 WebRequest needs port 80 (use ApiPort=80, make upd)."
             + " Whitelist: " + ApiBase()
             + " (no :3000). Restart MT4 after adding URL.";
   }
   else if(err == 4014)
      hint = " Enable 'Allow WebRequest for listed URL' in Expert Advisors options.";

   Log("WebRequest FAILED. Error=" + IntegerToString(err) + hint);
}

bool TestApiReachable()
{
   string healthUrl = g_apiBase + "/up";
   string body;
   int httpCode;

   Log("Health check GET " + healthUrl);

   if(!WebGet(healthUrl, body, httpCode))
   {
      LogWebRequestError(GetLastError());
      return false;
   }

   Log("Health check HTTP " + IntegerToString(httpCode) + " body=" + StringSubstr(body, 0, 80));
   return httpCode == 200;
}

// --- JSON helpers (flat Rails responses) ---

// Match only real JSON object keys (avoids "stop_action":true matching "action":true).
int JsonKeyPos(string json, string key)
{
   string patterns[4];
   patterns[0] = "{\"" + key + "\":\"";
   patterns[1] = "{\"" + key + "\": \"";
   patterns[2] = ",\"" + key + "\":\"";
   patterns[3] = ",\"" + key + "\": \"";

   int i;
   for(i = 0; i < 4; i++)
   {
      int pos = StringFind(json, patterns[i]);
      if(pos >= 0)
         return pos + StringLen(patterns[i]);
   }

   patterns[0] = "{\"" + key + "\":";
   patterns[1] = "{\"" + key + "\": ";
   patterns[2] = ",\"" + key + "\":";
   patterns[3] = ",\"" + key + "\": ";

   for(i = 0; i < 4; i++)
   {
      int pos = StringFind(json, patterns[i]);
      if(pos >= 0)
         return pos + StringLen(patterns[i]);
   }

   return -1;
}

string JsonExtractString(string json, string key)
{
   int start = JsonKeyPos(json, key);
   if(start < 0)
      return "";

   ushort first = StringGetCharacter(json, start);
   if(first == '"')
   {
      start++;
      int end = StringFind(json, "\"", start);
      if(end < 0)
         return "";
      return StringSubstr(json, start, end - start);
   }

   int end = start;
   int len = StringLen(json);
   while(end < len)
   {
      ushort c = StringGetCharacter(json, end);
      if(c == ',' || c == '}' || c == ']' || c == ' ')
         break;
      end++;
   }
   return StringSubstr(json, start, end - start);
}

double JsonExtractNumber(string json, string key)
{
   string raw = JsonExtractString(json, key);
   if(StringLen(raw) == 0)
      return 0.0;
   return StringToDouble(raw);
}

int JsonExtractInt(string json, string key)
{
   return (int)JsonExtractNumber(json, key);
}

string OrderComment(int orderId)
{
   return "ShogunX#" + IntegerToString(orderId);
}

string ExecutedGlobalKey(int orderId)
{
   return "ShogunX_ord_" + IntegerToString(orderId);
}

bool OrderAlreadyExecuted(int orderId)
{
   if(orderId <= 0)
      return true;

   if(GlobalVariableCheck(ExecutedGlobalKey(orderId)))
      return true;

   int total = OrdersTotal();
   int i;
   for(i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(StringFind(OrderComment(), OrderComment(orderId)) >= 0)
         return true;
   }

   return false;
}

void MarkOrderExecuted(int orderId)
{
   GlobalVariableSet(ExecutedGlobalKey(orderId), (double)TimeCurrent());
}

string TriggeredGlobalKey(int orderId)
{
   return "ShogunX_trig_" + IntegerToString(orderId);
}

string OpenGlobalKey(int orderId)
{
   return "ShogunX_open_" + IntegerToString(orderId);
}

string ClosedGlobalKey(int orderId)
{
   return "ShogunX_cls_" + IntegerToString(orderId);
}

bool TriggeredAlreadyReported(int orderId)
{
   return GlobalVariableCheck(TriggeredGlobalKey(orderId));
}

bool OpenAlreadyReported(int orderId)
{
   return GlobalVariableCheck(OpenGlobalKey(orderId));
}

bool ClosedAlreadyReported(int orderId)
{
   return GlobalVariableCheck(ClosedGlobalKey(orderId));
}

void MarkTriggeredReported(int orderId)
{
   GlobalVariableSet(TriggeredGlobalKey(orderId), (double)TimeCurrent());
}

void MarkOpenReported(int orderId)
{
   GlobalVariableSet(OpenGlobalKey(orderId), (double)TimeCurrent());
}

void MarkClosedReported(int orderId)
{
   GlobalVariableSet(ClosedGlobalKey(orderId), (double)TimeCurrent());
}

int ParseOrderIdFromComment(string comment)
{
   string prefix = "ShogunX#";
   int pos = StringFind(comment, prefix);
   if(pos < 0)
      return 0;

   return (int)StringToInteger(StringSubstr(comment, pos + StringLen(prefix)));
}

bool IsMarketOrderType(int orderType)
{
   return orderType == OP_BUY || orderType == OP_SELL;
}

bool IsPendingOrderType(int orderType)
{
   return orderType == OP_BUYLIMIT || orderType == OP_SELLLIMIT
       || orderType == OP_BUYSTOP || orderType == OP_SELLSTOP;
}

double OrderNetProfit()
{
   return OrderProfit() + OrderSwap() + OrderCommission();
}

bool NormalizeTradeSymbol(string symbolFromApi, string &tradeSymbol)
{
   if(StringLen(symbolFromApi) == 0)
   {
      tradeSymbol = Symbol();
      return true;
   }

   tradeSymbol = symbolFromApi;
   if(SymbolSelect(tradeSymbol, true))
      return true;

   Log("Symbol not available in Market Watch: " + tradeSymbol + " — using chart symbol " + Symbol());
   tradeSymbol = Symbol();
   return true;
}

bool PostJsonPayload(string url, string payload, string logLabel, int orderId)
{
   string body;
   int httpCode;

   Log(logLabel + " POST " + url);
   Log("Payload: " + payload);

   if(!WebPostJson(url, payload, body, httpCode))
   {
      LogWebRequestError(GetLastError());
      return false;
   }

   Log(logLabel + " HTTP " + IntegerToString(httpCode) + " response=" + body);

   if(httpCode < 200 || httpCode >= 300)
   {
      Log(logLabel + " failed for order_id=" + IntegerToString(orderId));
      return false;
   }

   return true;
}

bool PostOrderStatusUpdate(int orderId, int ticket, string status)
{
   string payload = StringFormat(
      "{\"order_id\":%d,\"ticket\":%d,\"status\":\"%s\"}",
      orderId,
      ticket,
      status
   );
   return PostJsonPayload(g_orderUpdatesUrl, payload, "Order update", orderId);
}

bool PostPositionOpenUpdate(int orderId, int ticket, double entryPrice)
{
   string payload = StringFormat(
      "{\"order_id\":%d,\"ticket\":%d,\"status\":\"open\",\"entry_price\":%s}",
      orderId,
      ticket,
      PriceJson(entryPrice)
   );
   return PostJsonPayload(g_positionUpdatesUrl, payload, "Position update (open)", orderId);
}

bool PostPositionClosedUpdate(int orderId, int ticket, double profitLoss)
{
   string payload = StringFormat(
      "{\"order_id\":%d,\"ticket\":%d,\"status\":\"closed\",\"profit_loss\":%s}",
      orderId,
      ticket,
      PriceJson(profitLoss)
   );
   return PostJsonPayload(g_positionUpdatesUrl, payload, "Position update (closed)", orderId);
}

void CheckTriggeredOrder(int orderId, int ticket, int orderType)
{
   if(!IsMarketOrderType(orderType))
      return;

   if(TriggeredAlreadyReported(orderId))
      return;

   Log("Pending order triggered order_id=" + IntegerToString(orderId)
       + " ticket=" + IntegerToString(ticket));

   if(PostOrderStatusUpdate(orderId, ticket, "triggered"))
      MarkTriggeredReported(orderId);
}

void CheckOpenPosition(int orderId, int ticket, int orderType)
{
   if(!IsMarketOrderType(orderType))
      return;

   if(!TriggeredAlreadyReported(orderId))
      return;

   if(OpenAlreadyReported(orderId))
      return;

   double entryPrice = OrderOpenPrice();

   Log("Position open order_id=" + IntegerToString(orderId)
       + " ticket=" + IntegerToString(ticket)
       + " entry_price=" + PriceJson(entryPrice));

   if(PostPositionOpenUpdate(orderId, ticket, entryPrice))
      MarkOpenReported(orderId);
}

void CheckClosedOrder(int orderId, int ticket)
{
   if(ClosedAlreadyReported(orderId))
      return;

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
      return;

   if(OrderCloseTime() <= 0)
      return;

   double profitLoss = OrderNetProfit();

   Log("Trade closed order_id=" + IntegerToString(orderId)
       + " ticket=" + IntegerToString(ticket)
       + " profit_loss=" + PriceJson(profitLoss));

   if(PostPositionClosedUpdate(orderId, ticket, profitLoss))
      MarkClosedReported(orderId);
}

void PollShogunXOrderLifecycle()
{
   int i;
   int total;

   total = OrdersTotal();
   for(i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      int orderId = ParseOrderIdFromComment(OrderComment());
      if(orderId <= 0)
         continue;

      int ticket = OrderTicket();
      int orderType = OrderType();

      if(IsPendingOrderType(orderType))
         continue;

      CheckTriggeredOrder(orderId, ticket, orderType);
      CheckOpenPosition(orderId, ticket, orderType);
   }

   total = OrdersHistoryTotal();
   for(i = total - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      int orderId = ParseOrderIdFromComment(OrderComment());
      if(orderId <= 0)
         continue;

      CheckClosedOrder(orderId, OrderTicket());
   }
}

int SendPendingOrder(string tradeSymbol, int cmd, double lots, double price, double sl, double tp, string comment, int orderId)
{
   ResetLastError();
   int ticket = OrderSend(tradeSymbol, cmd, lots, price, Slippage, sl, tp, comment, MagicNumber, 0, clrNONE);

   if(ticket < 0)
   {
      Log("OrderSend failed cmd=" + IntegerToString(cmd)
          + " symbol=" + tradeSymbol
          + " price=" + DoubleToString(price, Digits)
          + " err=" + IntegerToString(GetLastError()));
      return -1;
   }

   Log("OrderSend OK ticket=" + IntegerToString(ticket)
       + " cmd=" + IntegerToString(cmd)
       + " symbol=" + tradeSymbol
       + " price=" + DoubleToString(price, Digits)
       + " sl=" + DoubleToString(sl, Digits)
       + " tp=" + DoubleToString(tp, Digits)
       + " comment=" + comment);

   if(!PostOrderStatusUpdate(orderId, ticket, "placed"))
      Log("WARNING: MT4 order placed but Rails order_updates callback failed for order_id="
          + IntegerToString(orderId));

   return ticket;
}

bool PlaceBuyLimit(string tradeSymbol, double lots, double entryPrice, double stopLoss, double takeProfit, int orderId)
{
   Log("PlaceBuyLimit order_id=" + IntegerToString(orderId)
       + " entry=" + DoubleToString(entryPrice, Digits));
   return SendPendingOrder(tradeSymbol, OP_BUYLIMIT, lots, entryPrice, stopLoss, takeProfit, OrderComment(orderId), orderId) >= 0;
}

bool PlaceSellLimit(string tradeSymbol, double lots, double entryPrice, double stopLoss, double takeProfit, int orderId)
{
   Log("PlaceSellLimit order_id=" + IntegerToString(orderId)
       + " entry=" + DoubleToString(entryPrice, Digits));
   return SendPendingOrder(tradeSymbol, OP_SELLLIMIT, lots, entryPrice, stopLoss, takeProfit, OrderComment(orderId), orderId) >= 0;
}

bool PlaceBuyStop(string tradeSymbol, double lots, double entryPrice, double stopLoss, double takeProfit, int orderId)
{
   Log("PlaceBuyStop order_id=" + IntegerToString(orderId)
       + " entry=" + DoubleToString(entryPrice, Digits));
   return SendPendingOrder(tradeSymbol, OP_BUYSTOP, lots, entryPrice, stopLoss, takeProfit, OrderComment(orderId), orderId) >= 0;
}

bool PlaceSellStop(string tradeSymbol, double lots, double entryPrice, double stopLoss, double takeProfit, int orderId)
{
   Log("PlaceSellStop order_id=" + IntegerToString(orderId)
       + " entry=" + DoubleToString(entryPrice, Digits));
   return SendPendingOrder(tradeSymbol, OP_SELLSTOP, lots, entryPrice, stopLoss, takeProfit, OrderComment(orderId), orderId) >= 0;
}

bool ActionMatches(string action, string expected)
{
   return StringCompare(action, expected, false) == 0;
}

bool IsKnownTradeAction(string action)
{
   return ActionMatches(action, "HOLD")
      || ActionMatches(action, "BUY_LIMIT")
      || ActionMatches(action, "SELL_LIMIT")
      || ActionMatches(action, "BUY_STOP")
      || ActionMatches(action, "SELL_STOP");
}

string ResolveActionFromBody(string body, string action)
{
   if(IsKnownTradeAction(action))
      return action;

   string knownActions[5];
   knownActions[0] = "BUY_LIMIT";
   knownActions[1] = "SELL_LIMIT";
   knownActions[2] = "BUY_STOP";
   knownActions[3] = "SELL_STOP";
   knownActions[4] = "HOLD";

   int i;
   for(i = 0; i < 5; i++)
   {
      string pattern = "\"action\":\"" + knownActions[i] + "\"";
      if(StringFind(body, pattern) >= 0)
      {
         Log("Resolved action from body pattern: " + knownActions[i]
             + " (parsed=\"" + action + "\")");
         return knownActions[i];
      }
   }

   return action;
}

void ProcessExecutionResponse(string body)
{
   string action = JsonExtractString(body, "action");
   StringTrimLeft(action);
   StringTrimRight(action);
   action = ResolveActionFromBody(body, action);

   if(StringLen(action) == 0)
   {
      Log("Response missing action — no trade placed.");
      return;
   }

   if(ActionMatches(action, "HOLD"))
   {
      string reason = JsonExtractString(body, "reason");
      Log("HOLD — no trade placed. reason=" + reason);
      return;
   }

   int orderId = JsonExtractInt(body, "order_id");
   if(OrderAlreadyExecuted(orderId))
   {
      Log("Skipping duplicate execution for order_id=" + IntegerToString(orderId));
      return;
   }

   string symbolFromApi = JsonExtractString(body, "symbol");
   string tradeSymbol;
   NormalizeTradeSymbol(symbolFromApi, tradeSymbol);

   double entryPrice = JsonExtractNumber(body, "entry_price");
   double stopLoss = JsonExtractNumber(body, "stop_loss");
   double takeProfit = JsonExtractNumber(body, "take_profit");

   if(entryPrice <= 0.0)
   {
      Log("Invalid entry_price for order_id=" + IntegerToString(orderId));
      return;
   }

   bool placed = false;

   if(ActionMatches(action, "BUY_LIMIT"))
      placed = PlaceBuyLimit(tradeSymbol, LotSize, entryPrice, stopLoss, takeProfit, orderId);
   else if(ActionMatches(action, "SELL_LIMIT"))
      placed = PlaceSellLimit(tradeSymbol, LotSize, entryPrice, stopLoss, takeProfit, orderId);
   else if(ActionMatches(action, "BUY_STOP"))
      placed = PlaceBuyStop(tradeSymbol, LotSize, entryPrice, stopLoss, takeProfit, orderId);
   else if(ActionMatches(action, "SELL_STOP"))
      placed = PlaceSellStop(tradeSymbol, LotSize, entryPrice, stopLoss, takeProfit, orderId);
   else
   {
      Log("Unsupported action: [" + action + "] len=" + IntegerToString(StringLen(action))
          + " — recompile ShogunX.mq4 in MetaEditor (F7) and re-attach EA");
      return;
   }

   if(placed)
      MarkOrderExecuted(orderId);
}

void SendSignal()
{
   string payload = StringConcatenate(
      "{\"symbol\":\"", Symbol(),
      "\",\"timeframe\":\"H4\",\"timeframes\":{\"D1\":{", TimeframeMetricsJson(PERIOD_D1),
      "},\"H4\":{", TimeframeMetricsJson(PERIOD_H4),
      "},\"H1\":{", TimeframeMetricsJson(PERIOD_H1),
      "}}}"
   );

   string body;
   int httpCode;

   Log("Calling API -> " + g_signalsUrl);
   Log("Payload: " + payload);

   if(!WebPostJson(g_signalsUrl, payload, body, httpCode))
   {
      LogWebRequestError(GetLastError());
      return;
   }

   Log("HTTP " + IntegerToString(httpCode) + " OK. Response: " + body);

   if(httpCode >= 200 && httpCode < 300)
      ProcessExecutionResponse(body);
   else
      Log("Non-success HTTP code — skipping execution.");
}

void PollPendingExecution()
{
   string body;
   int httpCode;

   Log("Polling pending execution -> " + g_executionUrl);

   if(!WebGet(g_executionUrl, body, httpCode))
   {
      LogWebRequestError(GetLastError());
      return;
   }

   Log("Execution poll HTTP " + IntegerToString(httpCode) + " body=" + body);

   if(httpCode >= 200 && httpCode < 300)
      ProcessExecutionResponse(body);
}

int OnInit()
{
   if(IntervalSeconds < 1)
   {
      Print("[ShogunX] IntervalSeconds must be >= 1");
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(ApiPort != 80 && ApiPort != 443)
   {
      Print("[ShogunX] ApiPort must be 80 or 443 for WebRequest. Use make upd (port 80).");
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(SupportResistanceBars < 2)
   {
      Print("[ShogunX] SupportResistanceBars must be >= 2");
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(LotSize <= 0.0)
   {
      Print("[ShogunX] LotSize must be > 0");
      return(INIT_PARAMETERS_INCORRECT);
   }

   g_apiBase = ApiBase();
   g_signalsUrl = SignalsUrl();
   g_orderUpdatesUrl = OrderUpdatesUrl();
   g_positionUpdatesUrl = PositionUpdatesUrl();
   g_executionUrl = ExecutionUrl();

   Log("EA started on " + Symbol() + " " + ChartTimeframe()
       + " — snapshot every " + IntegerToString(IntervalSeconds) + "s ("
       + DoubleToString(IntervalSeconds / 3600.0, 2) + "h)");
   Log("Whitelist in MT4 (no port): " + g_apiBase);
   Log("Signals URL: " + g_signalsUrl);
   Log("Execution URL: " + g_executionUrl);
   Log("Order updates URL: " + g_orderUpdatesUrl);
   Log("Position updates URL: " + g_positionUpdatesUrl);
   Log("LotSize=" + DoubleToString(LotSize, 2) + " MagicNumber=" + IntegerToString(MagicNumber));
   Log("OrderPollSeconds=" + IntegerToString(OrderPollSeconds));

   if(!TestApiReachable())
   {
      MessageBox(
         "Cannot reach ShogunX API.\n\n"
         "MT4 cannot use port 3000 — only 80/443.\n\n"
         "1) On Mac: make upd  (exposes port 80)\n"
         "2) Tools -> Options -> Expert Advisors\n"
         "   Add: " + g_apiBase + "\n"
         "3) Restart MT4, ApiPort=80, re-attach EA\n"
         "4) VM? Set ApiHost to Mac IP (make mt4-host)",
         "ShogunX WebRequest",
         MB_ICONWARNING
      );
   }

   EventSetTimer(IntervalSeconds);
   SendSignal();
   PollPendingExecution();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Log("EA stopped.");
}

void OnTimer()
{
   SendSignal();
   PollPendingExecution();
}

void OnTick()
{
   if(OrderPollSeconds <= 0)
      return;

   if(g_lastOrderPoll > 0 && (TimeCurrent() - g_lastOrderPoll) < OrderPollSeconds)
      return;

   g_lastOrderPoll = TimeCurrent();
   PollPendingExecution();
   PollShogunXOrderLifecycle();
}
