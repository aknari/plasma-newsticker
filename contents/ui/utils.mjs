// Módulo de utilidades para News Ticker

// --- Sección de Procesamiento de Texto Internacional ---

function createHtml5EntityDecoder() {
    return {
        '&nbsp;': ' ',
        '&iexcl;': '¡', '&iquest;': '¿', '&hellip;': '…', '&mdash;': '—', '&ndash;': '–',
        '&Aacute;': 'Á', '&Agrave;': 'À', '&Auml;': 'Ä',
        '&Eacute;': 'É', '&Egrave;': 'È', '&Euml;': 'Ë',
        '&Iacute;': 'Í', '&Igrave;': 'Ì', '&Iuml;': 'Ï',
        '&Oacute;': 'Ó', '&Ograve;': 'Ò', '&Ouml;': 'Ö',
        '&Uacute;': 'Ú', '&Ugrave;': 'Ù', '&Uuml;': 'Ü',
        '&Ntilde;': 'Ñ', '&Ccedil;': 'Ç',
        '&aacute;': 'á', '&agrave;': 'à', '&auml;': 'ä',
        '&eacute;': 'é', '&egrave;': 'è', '&euml;': 'ë',
        '&iacute;': 'í', '&igrave;': 'ì', '&iuml;': 'ï',
        '&oacute;': 'ó', '&ograve;': 'ò', '&ouml;': 'ö',
        '&uacute;': 'ú', '&ugrave;': 'ù', '&uuml;': 'ü',
        '&ntilde;': 'ñ', '&ccedil;': 'ç', '&yacute;': 'ý',
        '&scaron;': 'š', '&Scaron;': 'Š',
        '&ccaron;': 'č', '&Ccaron;': 'Č',
        '&zcaron;': 'ž', '&Zcaron;': 'Ž',
        '&amacron;': 'ā', '&Amacron;': 'Ā',
        '&emacron;': 'ē', '&Emacron;': 'Ē',
        '&imacron;': 'ī', '&Imacron;': 'Ī',
        '&umacron;': 'ū', '&Umacron;': 'Ū',
        '&copy;': '©', '&reg;': '®', '&trade;': '™',
        '&euro;': '€', '&bull;': '•'
    };
}

function decodeHtmlEntitiesRobust(text) {
    if (!text) return '';

    var entities = createHtml5EntityDecoder();

    // Primero aplicar entidades nombradas
    for (var entity in entities) {
        text = text.replace(new RegExp(entity, 'g'), entities[entity]);
    }

    // Luego entidades numéricas decimales
    text = text.replace(/&#(\d+);/g, function(match, dec) {
        var codePoint = parseInt(dec, 10);
        if (codePoint > 0 && codePoint <= 0x10FFFF) {
            try {
                return String.fromCodePoint(codePoint);
            } catch (e) {
                console.warn("Code point decimal inválido: " + codePoint);
                return match;
            }
        }
        return match;
    });

    // Entidades hexadecimales
    text = text.replace(/&#x([0-9a-fA-F]+);/g, function(match, hex) {
        var codePoint = parseInt(hex, 16);
        if (codePoint > 0 && codePoint <= 0x10FFFF) {
            try {
                return String.fromCodePoint(codePoint);
            } catch (e) {
                console.warn("Code point hexadecimal inválido: " + hex);
                return match;
            }
        }
        return match;
    });

    // Decodificar las entidades XML básicas al final para evitar conflictos.
    text = text.replace(/&quot;/g, '"')
               .replace(/&apos;/g, "'")
               .replace(/&lt;/g, '<')
               .replace(/&gt;/g, '>')
               .replace(/&amp;/g, '&');

    return text;
}

function normalizeTextEncoding(text) {
    if (!text) return '';
    try {
        if (/Â|â/.test(text)) {
            text = text.replace(/Â([A-ZÀ-Ý])/g, '$1').replace(/â([a-zà-ý])/g, '$1');
        }
        if (typeof text.normalize === 'function') {
            text = text.normalize('NFC');
        }
        text = text.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
    } catch (e) {
        console.error("Error en normalización de encoding:", e);
    }
    return text;
}

export function decodeHtmlEntities(text) {
    if (!text) return '';
    let normalized = normalizeTextEncoding(text);
    return decodeHtmlEntitiesRobust(normalized);
}

// --- Sección de Parsing de Feeds ---

function parseItemsFromRegex(xml, itemRegex, titleRegex, linkRegex, guidRegex, pubDateRegex, feedUrl, maxItems, feedTimestamps) {
    var items = xml.match(itemRegex) || [];
    var newItems = [];

    for (var i = 0; i < Math.min(items.length, maxItems); i++) {
        var item = items[i].replace(/\s+/g, ' ').trim();
        var titleMatch = item.match(titleRegex);
        var linkMatch = item.match(linkRegex) || item.match(guidRegex);
        var pubDateMatch = item.match(pubDateRegex);

        if (titleMatch && titleMatch[1] && titleMatch[1].trim()) {
            var title = decodeHtmlEntities(titleMatch[1].trim());
            var link = (linkMatch && linkMatch[1]) ? linkMatch[1].trim() : "";
            var pubDate = (pubDateMatch && pubDateMatch[1]) ? new Date(pubDateMatch[1]).getTime() : new Date().getTime();

            var isNew = false;
            if (!feedTimestamps[feedUrl]) {
                feedTimestamps[feedUrl] = {};
                isNew = true;
            } else if (!feedTimestamps[feedUrl][title] || pubDate > feedTimestamps[feedUrl][title]) {
                isNew = true;
            }

            feedTimestamps[feedUrl] = feedTimestamps[feedUrl] || {};
            feedTimestamps[feedUrl][title] = pubDate;

            newItems.push({
                title: title,
                link: link,
                isNew: isNew,
                isLast: false
            });
        }
    }
    return newItems;
}

function parseRssStandard(xml, feedUrl, maxItems, feedTimestamps) {
    var itemRegex = /<item[^>]*>[\s\S]*?<\/item>/g;
    var titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
    var linkRegex = /<link[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/link>/i;
    var guidRegex = /<guid[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/guid>/i;
    var pubDateRegex = /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i;

    return parseItemsFromRegex(xml, itemRegex, titleRegex, linkRegex, guidRegex, pubDateRegex, feedUrl, maxItems, feedTimestamps);
}

function parseRssMultiline(xml, feedUrl, maxItems, feedTimestamps) {
    var itemRegex = /<item[^>]*>[\s\S]*?<\/item>/g;
    var titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
    var linkRegex = /<link[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/link>/i;
    var guidRegex = /<guid[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/guid>/i;
    var pubDateRegex = /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i;

    var items = xml.match(itemRegex) || [];
    var newItems = [];

    for (var i = 0; i < Math.min(items.length, maxItems); i++) {
        var item = items[i];
        var titleMatch = item.match(titleRegex);
        if (titleMatch && titleMatch[1]) {
            var cleanTitle = titleMatch[1].replace(/\s+/g, ' ').trim();
            if (cleanTitle.length > 0) {
                var title = decodeHtmlEntities(cleanTitle);
                var linkMatch = item.match(linkRegex) || item.match(guidRegex);
                var pubDateMatch = item.match(pubDateRegex);
                var link = (linkMatch && linkMatch[1]) ? linkMatch[1].trim() : "";
                var pubDate = (pubDateMatch && pubDateMatch[1]) ? new Date(pubDateMatch[1]).getTime() : new Date().getTime();

                var isNew = false;
                if (!feedTimestamps[feedUrl]) {
                    feedTimestamps[feedUrl] = {};
                    isNew = true;
                } else if (!feedTimestamps[feedUrl][title] || pubDate > feedTimestamps[feedUrl][title]) {
                    isNew = true;
                }

                feedTimestamps[feedUrl] = feedTimestamps[feedUrl] || {};
                feedTimestamps[feedUrl][title] = pubDate;

                newItems.push({ title: title, link: link, isNew: isNew, isLast: false });
            }
        }
    }
    return newItems;
}

function parseRssAlternative(xml, feedUrl, maxItems, feedTimestamps) {
    var itemRegex = /<entry[^>]*>[\s\S]*?<\/entry>/g;
    var titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
    var linkRegex = /<link[^>]*href="([^"]*)"[^>]*/i;
    var guidRegex = /<id[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/id>/i;
    var pubDateRegex = /<updated[^>]*>([\s\S]*?)<\/updated>/i;

    return parseItemsFromRegex(xml, itemRegex, titleRegex, linkRegex, guidRegex, pubDateRegex, feedUrl, maxItems, feedTimestamps);
}

function parseAtomFeeds(xml, feedUrl, maxItems, feedTimestamps) {
    var itemRegex = /<entry[^>]*>[\s\S]*?<\/entry>/g;
    var titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
    var linkRegex = /<link[^>]*href="([^"]*)"[^>]*>/i;
    var guidRegex = /<id[^>]*>([\s\S]*?)<\/id>/i;
    var pubDateRegex = /<published[^>]*>([\s\S]*?)<\/published>/i;

    return parseItemsFromRegex(xml, itemRegex, titleRegex, linkRegex, guidRegex, pubDateRegex, feedUrl, maxItems, feedTimestamps);
}

function parseMinimalXml(xml, feedUrl, maxItems) {
    var titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/gi;
    var matches = xml.match(titleRegex) || [];
    var items = [];
    var addedCount = 0;

    var channelTitleMatch = xml.match(/<channel>[\s\S]*?<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i);
    var channelTitle = channelTitleMatch ? channelTitleMatch[1].replace(/\s+/g, ' ').trim() : null;

    for (var i = 0; i < matches.length && addedCount < maxItems; i++) {
        var titleMatch = matches[i].match(/<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i);
        if (titleMatch && titleMatch[1] && titleMatch[1].trim()) {
            var cleanTitle = titleMatch[1].replace(/\s+/g, ' ').trim();

            if (cleanTitle.length > 2 && cleanTitle !== channelTitle) {
                items.push({
                    title: decodeHtmlEntities(cleanTitle),
                    link: "",
                    isNew: true,
                    isLast: false
                });
                addedCount++;
            }
        }
    }
    return items;
}

export function parseFeedWithMultipleStrategies(xml, feedUrl, maxItems, feedTimestamps) {
    var strategies = [
        (xml, url) => parseRssStandard(xml, url, maxItems, feedTimestamps),
        (xml, url) => parseRssMultiline(xml, url, maxItems, feedTimestamps),
        (xml, url) => parseRssAlternative(xml, url, maxItems, feedTimestamps),
        (xml, url) => parseAtomFeeds(xml, url, maxItems, feedTimestamps),
        (xml, url) => parseMinimalXml(xml, url, maxItems)
    ];

    for (var i = 0; i < strategies.length; i++) {
        try {
            var items = strategies[i](xml, feedUrl);
            if (items && items.length > 0) {
                return items;
            }
        } catch (e) {
            // Silently ignore failed strategies, as we will try the next one.
        }
    }

    console.warn("Todas las estrategias de parsing fallaron para el feed:", feedUrl);
    return [];
}

// --- Sección de Utilidades de Favicon ---

export function getFaviconUrlCandidates(feedUrl) {
    if (!feedUrl) {
        return [];
    }

    try {
        var domain = feedUrl.replace(/^https?:\/\//, '').split('/')[0];

        // Manejar dominios especiales conocidos
        if (domain.includes("bbci.co.uk") || domain.includes("feeds.bbci.co.uk")) {
            domain = "bbc.co.uk";
        } else if (domain.includes("elpais.com")) {
            domain = "elpais.com";
        }

        // Devolver la lista de candidatos en orden de preferencia
        return [
            "https://logo.clearbit.com/" + domain + "?size=32",
            "https://www.google.com/s2/favicons?domain=" + domain + "&sz=32",
            "https://favicon.yandex.net/favicon/" + domain,
            "https://" + domain + "/favicon.ico"
        ];
    } catch (e) {
        console.error("Error generando candidatos de favicon para:", feedUrl, e);
        return [];
    }
}