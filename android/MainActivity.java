package tz.altra.pharmacy;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import java.io.IOException;
import java.util.Collections;

public final class MainActivity extends Activity {
    private static final String HOST = "appassets.androidplatform.net";

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(0xff123e32);
        getWindow().setNavigationBarColor(0xff123e32);
        WebView view = new WebView(this);
        view.getSettings().setJavaScriptEnabled(true);
        view.getSettings().setDomStorageEnabled(true);
        view.getSettings().setAllowFileAccess(false);
        view.getSettings().setAllowContentAccess(false);
        view.setWebChromeClient(new WebChromeClient());
        view.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView webView, WebResourceRequest request) {
                return !isLocal(request);
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView webView, WebResourceRequest request) {
                if (!isLocal(request)) return missing();
                String path = request.getUrl().getPath();
                if (path == null || path.contains("..")) return missing();
                if (path.equals("/")) path = "/index.html";
                String mime = path.endsWith(".js") ? "text/javascript" : path.endsWith(".css") ? "text/css" :
                    path.endsWith(".png") ? "image/png" : path.endsWith(".ttf") ? "font/ttf" : "text/html";
                try {
                    return new WebResourceResponse(mime, mime.startsWith("text/") ? "UTF-8" : null,
                        getAssets().open("site" + path));
                } catch (IOException ignored) {
                    return missing();
                }
            }
        });
        setContentView(view);
        view.loadUrl("https://" + HOST + "/");
    }

    private static boolean isLocal(WebResourceRequest request) {
        return "https".equals(request.getUrl().getScheme()) && HOST.equals(request.getUrl().getHost());
    }

    private static WebResourceResponse missing() {
        return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", Collections.emptyMap(), null);
    }
}
