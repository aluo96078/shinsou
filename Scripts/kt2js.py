#!/usr/bin/env python3
"""
kt2js.py — Kotlin-to-JavaScript transpiler for Mihon extensions.

Converts Android Mihon extension Kotlin source files (ParsedHttpSource subclasses)
into JavaScript plugins compatible with the iOS Mihon JS runtime.

Supports themes: Madara, MangaThemesia, WPMangaReader, FMReader, Mangabox, etc.

Usage:
    # Transpile a single extension
    python3 kt2js.py path/to/MySource.kt -o output/

    # Transpile an entire multisrc theme directory
    python3 kt2js.py path/to/extensions/multisrc/src/main/java/eu/kanade/tachiyomi/multisrc/madara/ \
                      --sources path/to/extensions/src/en/mysource/src/ \
                      -o output/

    # Batch: scan for all extensions using a theme
    python3 kt2js.py --scan path/to/tachiyomi-extensions/ --theme madara -o output/
"""

import re
import os
import sys
import json
import hashlib
import argparse
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class ParsedSource:
    """Extracted data from a Kotlin source file."""
    class_name: str = ""
    name: str = ""
    base_url: str = ""
    lang: str = "en"
    version_id: int = 1
    supports_latest: bool = True
    theme: str = ""

    # Overrides (selector strings, URL patterns, etc.)
    overrides: dict = field(default_factory=dict)
    # Full method bodies (for complex logic)
    methods: dict = field(default_factory=dict)
    # Custom headers
    headers: dict = field(default_factory=dict)
    # Date format
    date_format: str = ""
    date_locale: str = ""


def extract_string_value(line: str) -> str:
    """Extract a string literal value from a Kotlin line."""
    # Match "value" or """value"""
    m = re.search(r'"""(.*?)"""', line, re.DOTALL)
    if m:
        return m.group(1).strip()
    m = re.search(r'"((?:[^"\\]|\\.)*)"', line)
    if m:
        return m.group(1)
    return ""


def extract_bool_value(line: str) -> bool:
    """Extract a boolean value from a Kotlin line."""
    return "true" in line.lower()


def extract_int_value(line: str) -> int:
    """Extract an integer value from a Kotlin line."""
    m = re.search(r'=\s*(\d+)', line)
    return int(m.group(1)) if m else 1


def compute_source_id(name: str, lang: str, version_id: int) -> int:
    """Compute source ID matching Android's HttpSource.generateId()."""
    # MD5 of "$name (lowercase)/$lang/$versionId"
    key = f"{name.lower()}/{lang}/{version_id}"
    md5 = hashlib.md5(key.encode()).hexdigest()
    # Take first 16 hex chars as a signed 64-bit integer
    val = int(md5[:16], 16)
    # Convert to signed int64
    if val >= 2**63:
        val -= 2**64
    return val


def parse_kotlin_source(filepath: str) -> Optional[ParsedSource]:
    """Parse a Kotlin extension source file and extract relevant data."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    src = ParsedSource()

    # Extract class declaration
    m = re.search(r'class\s+(\w+)\s*(?:\(([^)]*)\))?\s*:\s*(\w+)\s*\(', content)
    if not m:
        # Try: class Foo : Bar()
        m = re.search(r'class\s+(\w+)\s*:\s*(\w+)\s*\(', content)
        if not m:
            return None
        src.class_name = m.group(1)
        src.theme = m.group(2)
    else:
        src.class_name = m.group(1)
        src.theme = m.group(3)

    # Extract constructor args for factory-generated sources
    # e.g. class MySource(override val lang: String, ...) : Madara("name", "url", "lang")
    constructor_args = re.search(
        r'class\s+\w+\s*(?:\([^)]*\))?\s*:\s*\w+\s*\(([^)]*)\)',
        content
    )
    if constructor_args:
        args = constructor_args.group(1)
        # Try to extract name, baseUrl, lang from constructor call
        str_args = re.findall(r'"((?:[^"\\]|\\.)*)"', args)
        if len(str_args) >= 2:
            src.name = str_args[0]
            src.base_url = str_args[1]
            if len(str_args) >= 3:
                src.lang = str_args[2]

    # Override: name
    m = re.search(r'override\s+val\s+name\s*[:=]\s*(?:String\s*=\s*)?(.+)', content)
    if m:
        src.name = extract_string_value(m.group(1)) or src.name

    # Override: baseUrl
    m = re.search(r'override\s+val\s+baseUrl\s*[:=]\s*(?:String\s*=\s*)?(.+)', content)
    if m:
        src.base_url = extract_string_value(m.group(1)) or src.base_url

    # Override: lang
    m = re.search(r'override\s+val\s+lang\s*[:=]\s*(?:String\s*=\s*)?(.+)', content)
    if m:
        src.lang = extract_string_value(m.group(1)) or src.lang

    # Override: versionId
    m = re.search(r'override\s+val\s+versionId\s*[:=]\s*(?:Int\s*=\s*)?(.+)', content)
    if m:
        src.version_id = extract_int_value(m.group(1))

    # Override: supportsLatest
    m = re.search(r'override\s+val\s+supportsLatest\s*[:=]\s*(?:Boolean\s*=\s*)?(.+)', content)
    if m:
        src.supports_latest = extract_bool_value(m.group(1))

    # If name still empty, derive from class name
    if not src.name:
        src.name = re.sub(r'([A-Z])', r' \1', src.class_name).strip()

    # Extract all overrides — simple property overrides (string/bool/int)
    for m in re.finditer(
        r'override\s+(?:val|fun)\s+(\w+)\s*(?:\([^)]*\))?\s*[:=]\s*(?:\w+\s*=\s*)?(.+)',
        content
    ):
        key = m.group(1)
        val_str = m.group(2).strip()
        # Skip if already handled
        if key in ("name", "baseUrl", "lang", "versionId", "supportsLatest"):
            continue
        # Try to extract string value
        sv = extract_string_value(val_str)
        if sv:
            src.overrides[key] = sv
        elif val_str.rstrip().endswith("null"):
            src.overrides[key] = None

    # Extract simple fun overrides that return a string
    for m in re.finditer(
        r'override\s+fun\s+(\w+)\s*\([^)]*\)\s*[:=]\s*(?:\w+\s*=\s*)?(.+)',
        content
    ):
        key = m.group(1)
        val = extract_string_value(m.group(2))
        if val:
            src.overrides[key] = val

    # Extract headersBuilder
    headers_block = re.search(
        r'override\s+fun\s+headersBuilder\s*\(\).*?\{(.*?)\}',
        content, re.DOTALL
    )
    if headers_block:
        for hm in re.finditer(r'\.add\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)', headers_block.group(1)):
            src.headers[hm.group(1)] = hm.group(2)

    # Extract dateFormat
    m = re.search(r'dateFormat\s*=\s*SimpleDateFormat\(\s*"([^"]+)"', content)
    if m:
        src.date_format = m.group(1)

    return src


def generate_madara_js(src: ParsedSource) -> str:
    """Generate a JS plugin for a Madara-theme source."""
    # Madara defaults
    popular_url = src.overrides.get("popularMangaUrlDirectory", "/manga/")
    manga_subdir = src.overrides.get("mangaSubString", "manga")

    use_new_chapter_endpoint = "true" if src.overrides.get("useNewChapterEndpoint") else "false"
    use_loading_pages = "true" if src.overrides.get("useLoadMoreRequest") else "true"

    js = f"""// Auto-generated from {src.class_name}.kt (Madara theme)
// Source: {src.name} | Lang: {src.lang} | Base: {src.base_url}

var source = {{
    supportsLatest: {str(src.supports_latest).lower()},
    baseUrl: "{src.base_url}",
    headers: {json.dumps(src.headers) if src.headers else '{}'},

    // === Popular Manga ===
    getPopularManga: function(page) {{
        var url = baseUrl + "{popular_url or '/manga/'}" + "?m_orderby=views&page=" + page;
        var html = bridge.httpGet(url);
        if (!html) return {{ mangas: [], hasNextPage: false }};
        var doc = Jsoup.parse(html, baseUrl);
        return this._parseMangaList(doc);
    }},

    // === Latest Updates ===
    getLatestUpdates: function(page) {{
        var url = baseUrl + "{popular_url or '/manga/'}" + "?m_orderby=latest&page=" + page;
        var html = bridge.httpGet(url);
        if (!html) return {{ mangas: [], hasNextPage: false }};
        var doc = Jsoup.parse(html, baseUrl);
        return this._parseMangaList(doc);
    }},

    // === Search ===
    getSearchManga: function(page, query) {{
        var url = baseUrl + "/?s=" + encodeURIComponent(query) + "&post_type=wp-manga&paged=" + page;
        var html = bridge.httpGet(url);
        if (!html) return {{ mangas: [], hasNextPage: false }};
        var doc = Jsoup.parse(html, baseUrl);
        return this._parseMangaList(doc);
    }},

    // === Manga Details ===
    getMangaDetails: function(manga) {{
        var url = baseUrl + manga.url;
        var html = bridge.httpGet(url);
        if (!html) return manga;
        var doc = Jsoup.parse(html, baseUrl);

        var result = SManga.create();
        result.url = manga.url;

        var titleEl = doc.selectFirst("div.post-title h1, div.post-title h3");
        if (titleEl) result.title = titleEl.text().trim();

        var authorEl = doc.selectFirst("div.author-content a, span.author-content a");
        if (authorEl) result.author = authorEl.text().trim();

        var artistEl = doc.selectFirst("div.artist-content a, span.artist-content a");
        if (artistEl) result.artist = artistEl.text().trim();

        var descEl = doc.selectFirst("div.description-summary div.summary__content, div.summary__content");
        if (descEl) result.description = descEl.text().trim();

        var genres = doc.select("div.genres-content a").eachText();
        if (genres.length > 0) result.genre = genres;

        var statusEl = doc.selectFirst("div.post-content_item:contains(Status) div.summary-content, div.post-status div.summary-content");
        if (statusEl) {{
            var statusText = statusEl.text().trim().toLowerCase();
            if (statusText.indexOf("ongoing") >= 0) result.status = SManga.ONGOING;
            else if (statusText.indexOf("completed") >= 0) result.status = SManga.COMPLETED;
            else if (statusText.indexOf("hiatus") >= 0) result.status = SManga.ON_HIATUS;
            else if (statusText.indexOf("cancelled") >= 0 || statusText.indexOf("canceled") >= 0) result.status = SManga.CANCELLED;
        }}

        var thumbEl = doc.selectFirst("div.summary_image img");
        if (thumbEl) {{
            result.thumbnailUrl = thumbEl.attr("data-src") || thumbEl.attr("src");
            if (result.thumbnailUrl && result.thumbnailUrl.indexOf("http") !== 0) {{
                result.thumbnailUrl = baseUrl + result.thumbnailUrl;
            }}
        }}

        result.initialized = true;
        bridge.domReleaseAll();
        return result;
    }},

    // === Chapter List ===
    getChapterList: function(manga) {{
        var url = baseUrl + manga.url;
        var html = bridge.httpGet(url);
        if (!html) return [];
        var doc = Jsoup.parse(html, baseUrl);

        var chapters = [];
        var chapterEls = doc.select("li.wp-manga-chapter, ul.version-chap li");

        chapterEls.forEach(function(el) {{
            var ch = SChapter.create();
            var aEl = el.selectFirst("a");
            if (aEl) {{
                ch.name = aEl.text().trim();
                var href = aEl.attr("href");
                setUrlWithoutDomain(ch, href);
            }}

            var dateEl = el.selectFirst("span.chapter-release-date, span.chapter-release-date i");
            if (dateEl) {{
                // Basic date parsing — can be enhanced
                ch.dateUpload = Date.parse(dateEl.text().trim()) || 0;
            }}

            if (ch.url && ch.name) chapters.push(ch);
        }});

        bridge.domReleaseAll();
        return chapters;
    }},

    // === Page List ===
    getPageList: function(chapter) {{
        var url = baseUrl + chapter.url;
        var html = bridge.httpGet(url);
        if (!html) return [];
        var doc = Jsoup.parse(html, baseUrl);

        var pages = [];
        var imgEls = doc.select("div.page-break img, div.reading-content img");

        imgEls.forEach(function(el, i) {{
            var imgUrl = el.attr("data-src") || el.attr("src");
            if (imgUrl) {{
                imgUrl = imgUrl.trim();
                if (imgUrl.indexOf("http") !== 0 && imgUrl.indexOf("//") === 0) {{
                    imgUrl = "https:" + imgUrl;
                }}
                pages.push({{ index: i, url: "", imageUrl: imgUrl }});
            }}
        }});

        bridge.domReleaseAll();
        return pages;
    }},

    // === Internal helpers ===
    _parseMangaList: function(doc) {{
        var mangas = [];
        var elements = doc.select("div.page-item-detail, div.c-tabs-item__content");

        elements.forEach(function(el) {{
            var manga = SManga.create();
            var titleEl = el.selectFirst("div.post-title h3 a, div.post-title h5 a, div.post-title a");
            if (titleEl) {{
                manga.title = titleEl.text().trim();
                var href = titleEl.attr("href");
                setUrlWithoutDomain(manga, href);
            }}

            var imgEl = el.selectFirst("img");
            if (imgEl) {{
                manga.thumbnailUrl = imgEl.attr("data-src") || imgEl.attr("src");
                if (manga.thumbnailUrl && manga.thumbnailUrl.indexOf("http") !== 0) {{
                    manga.thumbnailUrl = baseUrl + manga.thumbnailUrl;
                }}
            }}

            if (manga.url && manga.title) mangas.push(manga);
        }});

        var hasNext = doc.select("div.nav-previous a, a.nextpostslink, a.last").size() > 0;
        bridge.domReleaseAll();
        return {{ mangas: mangas, hasNextPage: hasNext }};
    }}
}};
"""
    return js


def generate_mangathemesia_js(src: ParsedSource) -> str:
    """Generate a JS plugin for a MangaThemesia-theme source."""
    manga_url_dir = src.overrides.get("mangaUrlDirectory", "/manga/")
    series_selector = src.overrides.get("seriesDescriptionSelector",
                                        "div.entry-content[itemprop=description] p, div.entry-content p")
    series_author = src.overrides.get("seriesAuthorSelector",
                                      "span:contains(Author) i, div.tsinfo div:contains(Author) i")
    series_status = src.overrides.get("seriesStatusSelector",
                                      "span:contains(Status) i, div.tsinfo div:contains(Status) i")

    js = f"""// Auto-generated from {src.class_name}.kt (MangaThemesia theme)
// Source: {src.name} | Lang: {src.lang} | Base: {src.base_url}

var source = {{
    supportsLatest: {str(src.supports_latest).lower()},
    baseUrl: "{src.base_url}",
    headers: {json.dumps(src.headers) if src.headers else '{}'},

    getPopularManga: function(page) {{
        var url = baseUrl + "{manga_url_dir}" + "?order=popular&page=" + page;
        var html = bridge.httpGet(url);
        if (!html) return {{ mangas: [], hasNextPage: false }};
        var doc = Jsoup.parse(html, baseUrl);
        return this._parseMangaList(doc);
    }},

    getLatestUpdates: function(page) {{
        var url = baseUrl + "{manga_url_dir}" + "?order=update&page=" + page;
        var html = bridge.httpGet(url);
        if (!html) return {{ mangas: [], hasNextPage: false }};
        var doc = Jsoup.parse(html, baseUrl);
        return this._parseMangaList(doc);
    }},

    getSearchManga: function(page, query) {{
        var url = baseUrl + "/?s=" + encodeURIComponent(query) + "&page=" + page;
        var html = bridge.httpGet(url);
        if (!html) return {{ mangas: [], hasNextPage: false }};
        var doc = Jsoup.parse(html, baseUrl);
        return this._parseMangaList(doc);
    }},

    getMangaDetails: function(manga) {{
        var url = baseUrl + manga.url;
        var html = bridge.httpGet(url);
        if (!html) return manga;
        var doc = Jsoup.parse(html, baseUrl);

        var result = SManga.create();
        result.url = manga.url;

        var titleEl = doc.selectFirst("h1.entry-title");
        if (titleEl) result.title = titleEl.text().trim();

        var authorEl = doc.selectFirst("{series_author}");
        if (authorEl) result.author = authorEl.text().trim();

        var descEl = doc.selectFirst("{series_selector}");
        if (descEl) result.description = descEl.text().trim();

        var genres = doc.select("span.mgen a, div.wd-full span.mgen a").eachText();
        if (genres.length > 0) result.genre = genres;

        var statusEl = doc.selectFirst("{series_status}");
        if (statusEl) {{
            var statusText = statusEl.text().trim().toLowerCase();
            if (statusText.indexOf("ongoing") >= 0) result.status = SManga.ONGOING;
            else if (statusText.indexOf("completed") >= 0) result.status = SManga.COMPLETED;
            else if (statusText.indexOf("hiatus") >= 0) result.status = SManga.ON_HIATUS;
        }}

        var thumbEl = doc.selectFirst("div.thumb img, img.attachment-");
        if (thumbEl) {{
            result.thumbnailUrl = thumbEl.attr("data-src") || thumbEl.attr("src");
        }}

        result.initialized = true;
        bridge.domReleaseAll();
        return result;
    }},

    getChapterList: function(manga) {{
        var url = baseUrl + manga.url;
        var html = bridge.httpGet(url);
        if (!html) return [];
        var doc = Jsoup.parse(html, baseUrl);

        var chapters = [];
        var chapterEls = doc.select("div#chapterlist ul li, ul.clstyle li");

        chapterEls.forEach(function(el) {{
            var ch = SChapter.create();
            var aEl = el.selectFirst("a");
            if (aEl) {{
                var numEl = aEl.selectFirst("span.chapternum");
                ch.name = numEl ? numEl.text().trim() : aEl.text().trim();
                var href = aEl.attr("href");
                setUrlWithoutDomain(ch, href);
            }}

            var dateEl = el.selectFirst("span.chapterdate");
            if (dateEl) {{
                ch.dateUpload = Date.parse(dateEl.text().trim()) || 0;
            }}

            if (ch.url && ch.name) chapters.push(ch);
        }});

        bridge.domReleaseAll();
        return chapters;
    }},

    getPageList: function(chapter) {{
        var url = baseUrl + chapter.url;
        var html = bridge.httpGet(url);
        if (!html) return [];
        var doc = Jsoup.parse(html, baseUrl);

        var pages = [];
        var imgEls = doc.select("div#readerarea img, img.ts-main-image");

        imgEls.forEach(function(el, i) {{
            var imgUrl = el.attr("data-src") || el.attr("src");
            if (imgUrl) {{
                imgUrl = imgUrl.trim();
                if (imgUrl.indexOf("http") !== 0 && imgUrl.indexOf("//") === 0) {{
                    imgUrl = "https:" + imgUrl;
                }}
                pages.push({{ index: i, url: "", imageUrl: imgUrl }});
            }}
        }});

        bridge.domReleaseAll();
        return pages;
    }},

    _parseMangaList: function(doc) {{
        var mangas = [];
        var elements = doc.select("div.bs div.bsx, div.listupd div.bs div.bsx, div.listupd div.utao");

        elements.forEach(function(el) {{
            var manga = SManga.create();
            var aEl = el.selectFirst("a");
            if (aEl) {{
                manga.title = aEl.attr("title") || aEl.text().trim();
                var href = aEl.attr("href");
                setUrlWithoutDomain(manga, href);
            }}

            var imgEl = el.selectFirst("img.ts-post-image, img.wp-post-image, img");
            if (imgEl) {{
                manga.thumbnailUrl = imgEl.attr("data-src") || imgEl.attr("src");
            }}

            if (manga.url && manga.title) mangas.push(manga);
        }});

        var hasNext = doc.select("a.next.page-numbers, div.hpage a.r").size() > 0;
        bridge.domReleaseAll();
        return {{ mangas: mangas, hasNextPage: hasNext }};
    }}
}};
"""
    return js


def generate_generic_js(src: ParsedSource) -> str:
    """Generate a generic JS plugin from extracted overrides."""
    # Build selector overrides map
    selectors = {}
    for key in ("popularMangaSelector", "searchMangaSelector", "latestUpdatesSelector",
                "popularMangaNextPageSelector", "searchMangaNextPageSelector",
                "latestUpdatesNextPageSelector", "chapterListSelector",
                "mangaDetailsParse", "pageListParse", "imageUrlParse"):
        if key in src.overrides:
            selectors[key] = src.overrides[key]

    js = f"""// Auto-generated from {src.class_name}.kt ({src.theme} theme)
// Source: {src.name} | Lang: {src.lang} | Base: {src.base_url}
// NOTE: This is a generic transpilation. Some methods may need manual adjustment.

var source = {{
    supportsLatest: {str(src.supports_latest).lower()},
    baseUrl: "{src.base_url}",
    headers: {json.dumps(src.headers) if src.headers else '{}'},

    getPopularManga: function(page) {{
        var url = baseUrl + "/manga/?page=" + page;
        var html = bridge.httpGet(url);
        if (!html) return {{ mangas: [], hasNextPage: false }};
        var doc = Jsoup.parse(html, baseUrl);
        // TODO: implement popularMangaSelector/FromElement for {src.theme}
        return {{ mangas: [], hasNextPage: false }};
    }},

    getLatestUpdates: function(page) {{
        return this.getPopularManga(page);
    }},

    getSearchManga: function(page, query) {{
        var url = baseUrl + "/search?q=" + encodeURIComponent(query) + "&page=" + page;
        var html = bridge.httpGet(url);
        if (!html) return {{ mangas: [], hasNextPage: false }};
        var doc = Jsoup.parse(html, baseUrl);
        return {{ mangas: [], hasNextPage: false }};
    }},

    getMangaDetails: function(manga) {{
        var url = baseUrl + manga.url;
        var html = bridge.httpGet(url);
        if (!html) return manga;
        var doc = Jsoup.parse(html, baseUrl);
        manga.initialized = true;
        bridge.domReleaseAll();
        return manga;
    }},

    getChapterList: function(manga) {{
        var url = baseUrl + manga.url;
        var html = bridge.httpGet(url);
        if (!html) return [];
        var doc = Jsoup.parse(html, baseUrl);
        bridge.domReleaseAll();
        return [];
    }},

    getPageList: function(chapter) {{
        var url = baseUrl + chapter.url;
        var html = bridge.httpGet(url);
        if (!html) return [];
        var doc = Jsoup.parse(html, baseUrl);
        bridge.domReleaseAll();
        return [];
    }}
}};
"""
    return js


# Theme → generator mapping
THEME_GENERATORS = {
    "Madara": generate_madara_js,
    "MadaraTheme": generate_madara_js,
    "MangaThemesia": generate_mangathemesia_js,
    "MangaThemesiaTheme": generate_mangathemesia_js,
}


def generate_manifest(src: ParsedSource) -> dict:
    """Generate a plugin manifest JSON."""
    source_id = compute_source_id(src.name, src.lang, src.version_id)
    filename = re.sub(r'[^a-zA-Z0-9]', '_', src.class_name).lower()

    return {
        "id": f"{src.lang}.{filename}",
        "name": src.name,
        "version": f"1.{src.version_id}.0",
        "lang": src.lang,
        "nsfw": False,
        "script": f"{filename}.js",
        "signature": "",
        "sources": [
            {
                "name": src.name,
                "lang": src.lang,
                "id": source_id,
                "baseUrl": src.base_url
            }
        ]
    }


def transpile_file(filepath: str, output_dir: str) -> Optional[str]:
    """Transpile a single Kotlin file to JS. Returns output path or None."""
    src = parse_kotlin_source(filepath)
    if not src:
        print(f"  [SKIP] Could not parse: {filepath}")
        return None

    if not src.base_url:
        print(f"  [SKIP] No baseUrl found in: {filepath}")
        return None

    # Select generator based on theme
    generator = THEME_GENERATORS.get(src.theme)
    if not generator:
        print(f"  [WARN] Unknown theme '{src.theme}' for {src.class_name}, using generic template")
        generator = generate_generic_js

    js_code = generator(src)
    manifest = generate_manifest(src)

    # Write output
    os.makedirs(output_dir, exist_ok=True)
    filename = manifest["script"]
    js_path = os.path.join(output_dir, filename)
    manifest_path = os.path.join(output_dir, filename.replace(".js", ".json"))

    with open(js_path, "w", encoding="utf-8") as f:
        f.write(js_code)

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"  [OK] {src.name} ({src.lang}) → {js_path}")
    return js_path


def scan_extensions_dir(base_dir: str, theme_filter: str = None) -> list:
    """Scan a tachiyomi-extensions directory for source files."""
    results = []
    base_path = Path(base_dir)

    # Look for src/ directories containing Kotlin files
    for kt_file in base_path.rglob("*.kt"):
        # Skip test files, build files
        if "test" in str(kt_file).lower() or "build" in str(kt_file):
            continue

        with open(kt_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Check if it extends a known theme
        if theme_filter:
            if theme_filter.lower() not in content.lower():
                continue

        # Check if it's a source class (extends ParsedHttpSource or a known theme)
        if re.search(r'class\s+\w+.*:\s*(ParsedHttpSource|Madara|MangaThemesia|HttpSource)', content):
            results.append(str(kt_file))

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Transpile Android Mihon extensions (Kotlin) to iOS JS plugins"
    )
    parser.add_argument("input", nargs="?", help="Input .kt file or directory")
    parser.add_argument("-o", "--output", default="./output", help="Output directory")
    parser.add_argument("--scan", help="Scan extensions directory for sources")
    parser.add_argument("--theme", help="Filter by theme name when scanning")
    parser.add_argument("--dry-run", action="store_true", help="Parse only, don't generate")

    args = parser.parse_args()

    if args.scan:
        print(f"Scanning {args.scan} for extensions...")
        files = scan_extensions_dir(args.scan, args.theme)
        print(f"Found {len(files)} source files")
        for f in files:
            if not args.dry_run:
                transpile_file(f, args.output)
            else:
                src = parse_kotlin_source(f)
                if src:
                    print(f"  {src.class_name} ({src.theme}) — {src.name} [{src.lang}] @ {src.base_url}")
    elif args.input:
        if os.path.isdir(args.input):
            for kt_file in Path(args.input).rglob("*.kt"):
                transpile_file(str(kt_file), args.output)
        else:
            transpile_file(args.input, args.output)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
