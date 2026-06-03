#property strict

input string RailsUrl       = "http://127.0.0.1:3000/api/v1/signals";
input int    IntervalSeconds = 5;   // min seconds between API calls (MT4: lower = faster)
input double SlOffset        = 0.0030;
input double TpOffset        = 0.0060;

datetime lastRun = 0;

void OnTick()
{
   if(TimeCurrent() - lastRun < IntervalSeconds)
      return;

   lastRun = TimeCurrent();

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

   char post[];
   int len = StringToCharArray(payload, post);
   if(len > 0)
      ArrayResize(post, len - 1);

   char result[];
   string headers = "Content-Type: application/json\r\n";
   string response_headers;

   ResetLastError();

   int res = WebRequest(
      "POST",
      RailsUrl,
      headers,
      5000,
      post,
      result,
      response_headers
   );

   if(res == -1)
   {
      Print("WebRequest failed. Error=", GetLastError());
      return;
   }

   string response = CharArrayToString(result);

   Print("HTTP Status: ", res);
   Print("Rails Response: ", response);
}
