// ReaderModeService.swift
// Umbra — Privacy-First Browser

import Foundation

enum ReaderModeService {
    /// JavaScript that extracts article content from a web page.
    /// Returns JSON: { title, byline, content, excerpt, siteName }
    static let extractionScript = """
    (function() {
        'use strict';

        function getMetaContent(name) {
            var el = document.querySelector('meta[name="' + name + '"], meta[property="' + name + '"]');
            return el ? el.getAttribute('content') : null;
        }

        // Get title
        var title = '';
        var h1 = document.querySelector('article h1, .article-title, .post-title, h1.entry-title, h1');
        if (h1) title = h1.textContent.trim();
        if (!title) title = getMetaContent('og:title') || document.title || '';

        // Get byline
        var byline = '';
        var bylineEl = document.querySelector('[rel="author"], .author, .byline, .article-author, [itemprop="author"]');
        if (bylineEl) byline = bylineEl.textContent.trim();
        if (!byline) byline = getMetaContent('author') || '';

        // Get site name
        var siteName = getMetaContent('og:site_name') || window.location.hostname.replace('www.', '') || '';

        // Get article content
        var content = '';
        var article = document.querySelector('article, [role="article"], .article-body, .story-body, .post-content, .entry-content, .article-content, main');

        if (article) {
            // Clone to avoid modifying the page
            var clone = article.cloneNode(true);

            // Remove unwanted elements
            var unwanted = clone.querySelectorAll('script, style, nav, aside, .ad, .ads, .advertisement, .social-share, .share-buttons, .related-articles, .comments, .sidebar, iframe, .newsletter, .popup, header nav, footer');
            unwanted.forEach(function(el) { el.remove(); });

            // Get paragraphs
            var paragraphs = clone.querySelectorAll('p, h2, h3, h4, blockquote, ul, ol, figure, img');
            var parts = [];

            paragraphs.forEach(function(el) {
                if (el.tagName === 'IMG') {
                    var src = el.getAttribute('src') || el.getAttribute('data-src') || '';
                    var alt = el.getAttribute('alt') || '';
                    if (src) parts.push('<figure><img src="' + src + '" alt="' + alt + '"/></figure>');
                } else if (el.tagName === 'FIGURE') {
                    var img = el.querySelector('img');
                    var caption = el.querySelector('figcaption');
                    if (img) {
                        var imgSrc = img.getAttribute('src') || img.getAttribute('data-src') || '';
                        var capText = caption ? caption.textContent.trim() : '';
                        parts.push('<figure><img src="' + imgSrc + '"/>' + (capText ? '<figcaption>' + capText + '</figcaption>' : '') + '</figure>');
                    }
                } else {
                    var text = el.textContent.trim();
                    if (text.length > 20) {
                        parts.push('<' + el.tagName.toLowerCase() + '>' + el.innerHTML + '</' + el.tagName.toLowerCase() + '>');
                    }
                }
            });

            content = parts.join('\\n');
        }

        // Fallback: grab all paragraphs from body
        if (!content || content.length < 200) {
            var allP = document.querySelectorAll('body p');
            var fallbackParts = [];
            allP.forEach(function(p) {
                var text = p.textContent.trim();
                if (text.length > 40) {
                    fallbackParts.push('<p>' + p.innerHTML + '</p>');
                }
            });
            if (fallbackParts.length > 3) {
                content = fallbackParts.join('\\n');
            }
        }

        // Get excerpt
        var excerpt = getMetaContent('og:description') || getMetaContent('description') || '';

        return JSON.stringify({
            title: title,
            byline: byline,
            content: content,
            excerpt: excerpt,
            siteName: siteName,
            wordCount: (content || '').split(/\\s+/).length
        });
    })();
    """

    /// JavaScript that checks if a page is likely an article (has enough readable content)
    static let availabilityCheckScript = """
    (function() {
        var article = document.querySelector('article, [role="article"], .article-body, .story-body, .post-content, .entry-content, .article-content');
        if (article) {
            var text = article.textContent || '';
            return text.split(/\\s+/).length > 100;
        }
        // Fallback: count paragraphs
        var paragraphs = document.querySelectorAll('p');
        var longParas = 0;
        paragraphs.forEach(function(p) {
            if ((p.textContent || '').trim().split(/\\s+/).length > 20) longParas++;
        });
        return longParas >= 3;
    })();
    """

    /// CSS for the reader mode view
    static let readerCSS = """
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #0D1117;
            color: #E6EDF3;
            font-family: Georgia, 'Times New Roman', serif;
            line-height: 1.8;
            padding: 24px 20px 60px;
            max-width: 680px;
            margin: 0 auto;
            -webkit-text-size-adjust: 100%;
        }
        .reader-header {
            margin-bottom: 32px;
            padding-bottom: 20px;
            border-bottom: 1px solid #21262D;
        }
        .reader-site {
            font-family: -apple-system, sans-serif;
            font-size: 13px;
            color: #7C6BF0;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 12px;
        }
        .reader-title {
            font-size: 28px;
            font-weight: 700;
            line-height: 1.3;
            color: #E6EDF3;
            margin-bottom: 8px;
        }
        .reader-byline {
            font-family: -apple-system, sans-serif;
            font-size: 14px;
            color: #8B949E;
        }
        .reader-content p {
            font-size: 18px;
            margin-bottom: 20px;
        }
        .reader-content h2, .reader-content h3, .reader-content h4 {
            font-family: -apple-system, sans-serif;
            color: #E6EDF3;
            margin: 32px 0 12px;
        }
        .reader-content h2 { font-size: 22px; }
        .reader-content h3 { font-size: 19px; }
        .reader-content blockquote {
            border-left: 3px solid #7C6BF0;
            padding-left: 16px;
            margin: 20px 0;
            color: #8B949E;
            font-style: italic;
        }
        .reader-content ul, .reader-content ol {
            padding-left: 24px;
            margin-bottom: 20px;
        }
        .reader-content li {
            font-size: 18px;
            margin-bottom: 8px;
        }
        .reader-content figure {
            margin: 24px 0;
        }
        .reader-content img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
        }
        .reader-content figcaption {
            font-family: -apple-system, sans-serif;
            font-size: 13px;
            color: #8B949E;
            margin-top: 8px;
            text-align: center;
        }
        .reader-content a {
            color: #7C6BF0;
            text-decoration: none;
        }
    </style>
    """

    /// Build the full reader mode HTML from extracted article data
    static func buildReaderHTML(title: String, byline: String, siteName: String, content: String) -> String {
        return """
        <!DOCTYPE html>
        <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
        \(readerCSS)
        </head><body>
        <div class="reader-header">
            <div class="reader-site">\(siteName)</div>
            <h1 class="reader-title">\(title)</h1>
            \(byline.isEmpty ? "" : "<div class=\"reader-byline\">\(byline)</div>")
        </div>
        <div class="reader-content">\(content)</div>
        </body></html>
        """
    }
}
