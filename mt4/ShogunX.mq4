#property strict

// MT4 WebRequest ONLY allows http port 80 and https port 443 — no :3000 in URLs.
// Run API with: make upd (maps host port 80 -> container 3000).
// Whitelist in MT4: http://127.0.0.1  (or http://YOUR_MAC_IP if MT4 is in a VM).
input string ApiHost         = "127.0.0.1";
input int    ApiPort         = 80;    // must be 80 (http) or 443 (https)
input int    IntervalSeconds = 3;
input double SlOffset        = 0.0030;
input double TpOffset        = 0.0060;
input bool   VerboseLog      = true;

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
   string reqHeaders = "Content-Type: application/json\r\n";
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

   g_apiBase = ApiBase();
   g_signalsUrl = SignalsUrl();

   Log("EA started on " + Symbol());
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
   double bid = Bid;

   string payload = StringFormat(
      "{\"symbol\":\"%s\",\"entry\":%.5f,\"sl\":%.5f,\"tp\":%.5f}",
      Symbol(),
      bid,
      bid - SlOffset,
      bid + TpOffset
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
