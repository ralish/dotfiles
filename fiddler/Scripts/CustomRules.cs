using Fiddler;

using System;
using System.Collections.Generic;
using System.Windows.Forms;

[module: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1062:ValidateArgumentsOfPublicMethods")]
[module: System.Diagnostics.CodeAnalysis.SuppressMessage("Globalization", "CA1304:SpecifyCultureInfo")]
[module: System.Diagnostics.CodeAnalysis.SuppressMessage("Globalization", "CA1305:SpecifyIFormatProvider")]
[module: System.Diagnostics.CodeAnalysis.SuppressMessage("Globalization", "CA1310:SpecifyStringComparison")]
[module: System.Diagnostics.CodeAnalysis.SuppressMessage("Usage", "CA1801:ReviewUnusedParameters")]
[module: System.Diagnostics.CodeAnalysis.SuppressMessage("Usage", "CA2211:NonConstantFieldsShouldNotBeVisible")]
[module: System.Diagnostics.CodeAnalysis.SuppressMessage("CodeQuality", "IDE0051:RemoveUnusedMembers")]
[module: System.Diagnostics.CodeAnalysis.SuppressMessage("Style", "IDE0060:RemoveUnusedParametersAndValues")]

namespace Fiddler
{
    public static class Handlers
    {
        #region Actions

        static string actBoldUri;

        [BindPref("fiddlerscript.ephemeral.bpMethod")]
        public static string actBpMethod;

        [BindPref("fiddlerscript.ephemeral.bpRequestURI")]
        public static string actBpRequestUri;

        [BindPref("fiddlerscript.ephemeral.bpResponseURI")]
        public static string actBpResponseUri;

        static int actBpStatus = -1;

        static string actHostReplace;
        static string actHostReplaceWith;

        static string actUrlReplaceToken;
        static string actUrlReplaceTokenWith;

        // Called by QuickExec box in Fiddler or ExecAction.exe utility
        public static bool OnExecAction(string[] args)
        {
            string execAction = args[0].ToLower();
            FiddlerApplication.UI.SetStatusText("ExecAction: " + execAction);

            switch (execAction)
            {
                case "bold":
                    if (args.Length < 2)
                    {
                        actBoldUri = null;
                        FiddlerApplication.UI.SetStatusText("Bolding cleared.");
                        return false;
                    }

                    actBoldUri = args[1];
                    FiddlerApplication.UI.SetStatusText("Bolding requests for: " + actBoldUri);
                    return true;
                case "bp":
                    string msg;
                    msg = "bpu = Breakpoint on request to URI\n";
                    msg += "bpm = Breakpoint on request method\n";
                    msg += "bps = Breakpoint on response status\n";
                    msg += "bpa = Breakpoint on response from URI";
                    MessageBox.Show(msg);
                    return true;
                case "bpa":
                    if (args.Length < 2)
                    {
                        actBpResponseUri = null;
                        FiddlerApplication.UI.SetStatusText("Response URI breakpoint cleared.");
                        return false;
                    }

                    actBpResponseUri = args[1];
                    FiddlerApplication.UI.SetStatusText("Response URI breakpoint set for: " + actBpResponseUri);
                    return true;
                case "bpm":
                    if (args.Length < 2)
                    {
                        actBpMethod = null;
                        FiddlerApplication.UI.SetStatusText("Request method breakpoint cleared.");
                        return false;
                    }

                    actBpMethod = args[1].ToUpper();
                    FiddlerApplication.UI.SetStatusText("Request method breakpoint set for: " + actBpMethod);
                    return true;
                case "bps":
                    if (args.Length < 2)
                    {
                        actBpStatus = -1;
                        FiddlerApplication.UI.SetStatusText("Response status breakpoint cleared.");
                        return false;
                    }

                    actBpStatus = int.Parse(args[1]);
                    FiddlerApplication.UI.SetStatusText("Response status breakpoint set for: " + actBpStatus);
                    return true;
                case "bpu":
                    if (args.Length < 2)
                    {
                        actBpRequestUri = null;
                        FiddlerApplication.UI.SetStatusText("Request URI breakpoint cleared.");
                        return false;
                    }

                    actBpRequestUri = args[1];
                    FiddlerApplication.UI.SetStatusText("Request URI breakpoint set for: " + actBpRequestUri);
                    return true;
                case "clear":
                    FiddlerApplication.UI.actRemoveAllSessions();
                    return true;
                case "go":
                    FiddlerApplication.UI.actResumeAllSessions();
                    return true;
                case "help":
                    Utilities.LaunchHyperlink("https://docs.telerik.com/fiddler/knowledgebase/quickexec");
                    return true;
                case "hide":
                    FiddlerApplication.UI.actMinimizeToTray();
                    return true;
                case "keepct":
                    if (args.Length < 2)
                    {
                        FiddlerApplication.UI.SetStatusText("Specify the Content-Type of sessions to retain.");
                        return false;
                    }

                    FiddlerApplication.UI.actSelectSessionsWithResponseHeaderValue("Content-Type", args[1]);
                    FiddlerApplication.UI.actRemoveUnselectedSessions();
                    FiddlerApplication.UI.lvSessions.SelectedItems.Clear();
                    FiddlerApplication.UI.SetStatusText("Removed all sessions without Content-Type: " + args[1]);
                    return true;
                case "log":
                    if (args.Length < 2)
                    {
                        FiddlerApplication.UI.SetStatusText("Specify string to save to the application log.");
                        return false;
                    }

                    FiddlerApplication.Log.LogString(args[1]);
                    return true;
                case "nuke":
                    FiddlerApplication.UI.actClearWinINETCache();
                    FiddlerApplication.UI.actClearWinINETCookies();
                    return true;
                case "quit":
                    FiddlerApplication.UI.actExit();
                    return true;
                case "rphost":
                    if (args.Length < 3)
                    {
                        actHostReplace = null;
                        FiddlerApplication.UI.SetStatusText("Host replacement cleared.");
                        return false;
                    }

                    actHostReplace = args[1].ToLower();
                    actHostReplaceWith = args[2];
                    FiddlerApplication.UI.SetStatusText("Rewriting requests to host [" + actHostReplaceWith + "] with replacement host [" + actHostReplace + "]");
                    return true;
                case "rpurl":
                    if (args.Length < 3)
                    {
                        actUrlReplaceToken = null;
                        FiddlerApplication.UI.SetStatusText("URL replacement cleared.");
                        return false;
                    }

                    actUrlReplaceToken = args[1];
                    actUrlReplaceTokenWith = args[2].Replace(" ", "%20");
                    FiddlerApplication.UI.SetStatusText("Rewriting requests with URL token [" + actUrlReplaceToken + "] with replacement token [" + actUrlReplaceTokenWith + "]");
                    return true;
                case "save":
                    FiddlerApplication.UI.actSelectAll();
                    FiddlerApplication.UI.actSaveSessionsToZip(CONFIG.GetPath("Captures") + "dump.saz");
                    FiddlerApplication.UI.actRemoveAllSessions();
                    FiddlerApplication.UI.SetStatusText("Saved all sessions to: " + CONFIG.GetPath("Captures") + "dump.saz");
                    return true;
                case "screenshot":
                    FiddlerApplication.UI.actCaptureScreenshot(false);
                    return true;
                case "show":
                    FiddlerApplication.UI.actRestoreWindow();
                    return true;
                case "start":
                    FiddlerApplication.UI.actAttachProxy();
                    return true;
                case "stop":
                    FiddlerApplication.UI.actDetachProxy();
                    return true;
                case "trimsess":
                    if (args.Length < 2)
                    {
                        FiddlerApplication.UI.SetStatusText("Specify number of sessions to trim the session list to.");
                        return false;
                    }

                    FiddlerApplication.UI.TrimSessionList(int.Parse(args[1]));
                    return true;
                default:
                    FiddlerApplication.UI.SetStatusText("ExecAction not found: " + execAction);
                    return false;
            }
        }

        #endregion

        #region Application events

        // After compiling
        public static void Main()
        {
            FiddlerApplication.UI.SetStatusText("CustomRules.cs loaded at: " + DateTime.Now.ToShortTimeString());
        }

        // After startup
        public static void OnBoot()
        {
        }

        // Before shutdown
        public static bool OnBeforeShutdown()
        {
            return true;
        }

        // During shutdown
        public static void OnShutdown()
        {
        }

        // After attaching as system proxy
        public static void OnAttach()
        {
        }

        // After detaching as system proxy
        public static void OnDetach()
        {
        }

        #endregion

        #region Context actions

        [ContextAction("Decode Selected Sessions")]
        public static void DecodeSessions(Session[] sessions)
        {
            for (int i = 0; i < sessions.Length; i++)
            {
                sessions[i].utilDecodeRequest();
                sessions[i].utilDecodeResponse();
            }

            FiddlerApplication.UI.actUpdateInspector(true, true);
        }

        #endregion

        #region Network events

        /*
            After request headers have been read from the client. Usually this
            is too early in the request handling to do anything useful as the
            request body is not yet available.

            As the request body has not yet been read from the client note that
            the requestBodyBytes property is not available in this function.
        */
        public static void OnPeekAtRequestHeaders(Session session)
        {
            // Only display traffic from specific processes
            /*
            List<string> processes = new List<string> {
            };

            session["ui-hide"] = "true";
            for (int i = 0; i < processes.Count; i++) {
                string process = processes[i].ToLower() + ":";
                if (session["x-ProcessInfo"].ToLower().StartsWith(process)) {
                    session["ui-hide"] = null;
                    break;
                }
            }
            */
        }

        // Before sending the client request to the server
        public static void OnBeforeRequest(Session session)
        {
            // Perform host replacement
            if (null != actHostReplace && session.host.ToLower() == actHostReplace)
            {
                session["x-overridehost"] = actHostReplaceWith;
            }

            // Perform URL token replacement
            if (null != actUrlReplaceToken && session.url.IndexOf(actUrlReplaceToken) > -1)
            {
                session.url = session.url.Replace(actUrlReplaceToken, actUrlReplaceTokenWith);
            }

            // Break on matching request URI
            if (null != actBpRequestUri && session.uriContains(actBpRequestUri))
            {
                session["x-breakrequest"] = "uri";
            }

            // Break on matching request method
            if (null != actBpMethod && session.HTTPMethodIs(actBpMethod))
            {
                session["x-breakrequest"] = "method";
            }

            // Bold the session on matching URI
            if (null != actBoldUri && session.uriContains(actBoldUri))
            {
                session["ui-bold"] = "true";
            }

            // Automatically Authenticate
            if (ruleAutoAuth)
            {
                // A setting of "(default)" will result in Fiddler responding
                // with the credentials of the user under which is is running.
                //
                // To use different credentials set X-AutoAuth to:
                // domain\\username:password
                session["X-AutoAuth"] = "(default)";
            }

            // User-Agent
            if (null != ruleUserAgent)
            {
                session.oRequest["User-Agent"] = ruleUserAgent;
            }

            // Simulate Modem Speeds
            if (ruleSimulateModem)
            {
                // Delay uploads by 300ms per KB
                session["request-trickle-delay"] = "300";
                // Delay downloads by 150ms per KB
                session["response-trickle-delay"] = "150";
            }

            // Disable Caching
            if (ruleDisableCaching)
            {
                session.oRequest.headers.Remove("If-None-Match");
                session.oRequest.headers.Remove("If-Modified-Since");
                session.oRequest["Pragma"] = "no-cache";
            }

            // Cache Always Fresh
            if (ruleCacheAlwaysFresh && (session.oRequest.headers.Exists("If-Modified-Since") || session.oRequest.headers.Exists("If-None-Match")))
            {
                session.utilCreateResponseAndBypassServer();
                session.responseCode = 304;
                session["ui-backcolor"] = "Lavender";
            }
        }

        /*
            Before returning the response headers to a client and reading the
            response body from the server.

            If a session has response streaming enabled, the OnBeforeResponse
            function is called *after* the response was returned to the client.
            If disabling response streaming is desired, this function is the
            place to do it (bBufferResponse = true). This may be required if
            the response headers suggest tampering with the response body may
            be necessary.

            As the response body has not yet been read from the server note
            that the responseBodyBytes property is not available.
        */
        public static void OnPeekAtResponseHeaders(Session session)
        {
            // Handle unauthenticated response status directly in Fiddler. This
            // is necessary when the server utilises a Channel Binding Token.
            if (session.isHTTPS &&
                session.responseCode == 401 &&
                // Only permit auto-auth for local apps
                session.LocalProcessID > 0 &&
                // Only permit auto-auth to trusted sites
                (Utilities.isPlainHostName(session.hostname) || session.host.EndsWith("example.com")))
            {
                // To use custom credentials set X-AutoAuth to:
                // domain\\username:password
                session["X-AutoAuth"] = "(default)";
                session["ui-backcolor"] = "pink";
            }

            // Disable Caching
            if (ruleDisableCaching)
            {
                session.oResponse.headers.Remove("Expires");
                session.oResponse["Cache-Control"] = "no-cache";
            }

            // Break on matching response code
            if (actBpStatus > 0 && session.responseCode == actBpStatus)
            {
                session.bBufferResponse = true;
                session["x-breakresponse"] = "status";
            }

            // Break on matching response URI
            if (null != actBpResponseUri && session.uriContains(actBpResponseUri))
            {
                session.bBufferResponse = true;
                session["x-breakresponse"] = "uri";
            }
        }

        // Before returning server response to the client (excluding errors)
        public static void OnBeforeResponse(Session session)
        {
            if (ruleHide304s && session.responseCode == 304)
            {
                session["ui-hide"] = "true";
            }
        }

        // Before returning an error to the client (e.g. DNS failure)
        static void OnReturningError(Session session)
        {
        }

        // After processing a session (runs unconditionally)
        static void OnDone(Session session)
        {
        }

        #endregion

        #region Rules

        [RulesOption("Hide 304s")]
        [BindPref("fiddlerscript.rules.Hide304s")]
        public static bool ruleHide304s = false;

        [RulesOption("&Automatically Authenticate")]
        [BindPref("fiddlerscript.rules.AutoAuth")]
        public static bool ruleAutoAuth = false;

        [RulesString("&User-Agents", true)]
        [BindPref("fiddlerscript.ephemeral.UserAgentString")]
        [RulesStringValue(0, "Netscape &3", "Mozilla/3.0 (Win95; I)")]
        [RulesStringValue(1, "WinPhone8.1", "Mozilla/5.0 (Mobile; Windows Phone 8.1; Android 4.0; ARM; Trident/7.0; Touch; rv:11.0; IEMobile/11.0; NOKIA; Lumia 520) like iPhone OS 7_0_3 Mac OS X AppleWebKit/537 (KHTML, like Gecko) Mobile Safari/537")]
        [RulesStringValue(2, "&Safari5 (Win7)", "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.21.1 (KHTML, like Gecko) Version/5.0.5 Safari/533.21.1")]
        [RulesStringValue(3, "Safari9 (Mac)", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11) AppleWebKit/601.1.56 (KHTML, like Gecko) Version/9.0 Safari/601.1.56")]
        [RulesStringValue(4, "iPad", "Mozilla/5.0 (iPad; CPU OS 8_3 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12F5027d Safari/600.1.4")]
        [RulesStringValue(5, "iPhone6", "Mozilla/5.0 (iPhone; CPU iPhone OS 8_3 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12F70 Safari/600.1.4")]
        [RulesStringValue(6, "IE &6 (XPSP2)", "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)")]
        [RulesStringValue(7, "IE &7 (Vista)", "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; SLCC1)")]
        [RulesStringValue(8, "IE 8 (Win2k3 x64)", "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.2; WOW64; Trident/4.0)")]
        [RulesStringValue(9, "IE &8 (Win7)", "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)")]
        [RulesStringValue(10, "IE 9 (Win7)", "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)")]
        [RulesStringValue(11, "IE 10 (Win8)", "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)")]
        [RulesStringValue(12, "IE 11 (Surface2)", "Mozilla/5.0 (Windows NT 6.3; ARM; Trident/7.0; Touch; rv:11.0) like Gecko")]
        [RulesStringValue(13, "IE 11 (Win8.1)", "Mozilla/5.0 (Windows NT 6.3; WOW64; Trident/7.0; rv:11.0) like Gecko")]
        [RulesStringValue(14, "Edge (Win10)", "Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2486.0 Safari/537.36 Edge/13.11082")]
        [RulesStringValue(15, "&Opera", "Opera/9.80 (Windows NT 6.2; WOW64) Presto/2.12.388 Version/12.17")]
        [RulesStringValue(16, "&Firefox 3.6", "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2.7) Gecko/20100625 Firefox/3.6.7")]
        [RulesStringValue(17, "&Firefox 43", "Mozilla/5.0 (Windows NT 6.3; WOW64; rv:43.0) Gecko/20100101 Firefox/43.0")]
        [RulesStringValue(18, "&Firefox Phone", "Mozilla/5.0 (Mobile; rv:18.0) Gecko/18.0 Firefox/18.0")]
        [RulesStringValue(19, "&Firefox (Mac)", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:24.0) Gecko/20100101 Firefox/24.0")]
        [RulesStringValue(20, "Chrome (Win)", "Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.48 Safari/537.36")]
        [RulesStringValue(21, "Chrome (Android)", "Mozilla/5.0 (Linux; Android 5.1.1; Nexus 5 Build/LMY48B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.78 Mobile Safari/537.36")]
        [RulesStringValue(22, "ChromeBook", "Mozilla/5.0 (X11; CrOS x86_64 6680.52.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.74 Safari/537.36")]
        [RulesStringValue(23, "GoogleBot Crawler", "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")]
        [RulesStringValue(24, "Kindle Fire (Silk)", "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_3; en-us; Silk/1.0.22.79_10013310) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16 Silk-Accelerated=true")]
        [RulesStringValue(25, "&Custom...", "%CUSTOM%")]
        public static string ruleUserAgent = null;

        [RulesOption("Simulate &Modem Speeds", "Per&formance")]
        public static bool ruleSimulateModem = false;

        [RulesOption("&Disable Caching", "Per&formance")]
        public static bool ruleDisableCaching = false;

        [RulesOption("Cache Always &Fresh", "Per&formance")]
        public static bool ruleCacheAlwaysFresh = false;

        #endregion

        #region Tools

        [ToolsAction("Reload Script")]
        public static void ReloadScript()
        {
            FiddlerObject.ReloadScript();
        }

        #endregion
    }
}