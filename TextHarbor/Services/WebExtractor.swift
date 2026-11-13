import Foundation
import WebKit

@MainActor
final class WebExtractor: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var isLoading = false
    @Published var title = ""
    @Published var message = "貼上網址後開啟網頁，再按「擷取網頁文字」。"
    let webView: WKWebView
    override init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
    }
    func open(_ input: String) {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") { value = "https://" + value }
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else {
            message = "網址格式不正確."
            return
        }
        webView.load(URLRequest(url: url))
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        message = "網頁載入中…"
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        title = webView.title ?? "網頁文字"
        message = "網頁已載入，可以開始擷取。"
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        message = "載入失敗：\(error.localizedDescription)"
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        message = "連線失敗：\(error.localizedDescription)"
    }
    func extract(completion: @escaping (Result<String, Error>) -> Void) {
        let script = """
        (() => {
          const root = document.querySelector('article, main, [role="main"]') || document.body;
          if (!root) return '';
          return (root.innerText || root.textContent || '').trim();
        })();
        """
        webView.evaluateJavaScript(script) { value, error in
            if let error { completion(.failure(error)); return }
            let text = (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            completion(text.isEmpty ? .failure(ExtractionError.noText) : .success(text))
        }
    }
}
