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
input bool   VerboseLog             = true;

string g_signalsUrl = "";
string g_apiBase    = "";

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
      default:         return IntegerToString(Period());
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

   g_apiBase = ApiBase();
   g_signalsUrl = SignalsUrl();

   Log("EA started on " + Symbol() + " " + ChartTimeframe()
       + " — snapshot every " + IntegerToString(IntervalSeconds) + "s ("
       + DoubleToString(IntervalSeconds / 3600.0, 2) + "h)");
   Log("Whitelist in MT4 (no port): " + g_apiBase);
   Log("Signals URL: " + g_signalsUrl);

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
}

void SendSignal()
{
   double price = Bid;
   double rsi = iRSI(Symbol(), Period(), RsiPeriod, PRICE_CLOSE, 0);
   double ema50 = iMA(Symbol(), Period(), EmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema200 = iMA(Symbol(), Period(), EmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double support = RecentLow(SupportResistanceBars);
   double resistance = RecentHigh(SupportResistanceBars);

   string payload = StringFormat(
      "{\"symbol\":\"%s\",\"timeframe\":\"%s\",\"price\":%s,\"rsi\":%s,\"ema50\":%s,\"ema200\":%s,\"support\":%s,\"resistance\":%s}",
      Symbol(),
      ChartTimeframe(),
      PriceJson(price),
      PriceJson(rsi),
      PriceJson(ema50),
      PriceJson(ema200),
      PriceJson(support),
      PriceJson(resistance)
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
}
