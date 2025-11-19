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

export function sanitizeText(text) {
    if (!text) return '';
    // Elimina caracteres fuera de los rangos comunes (Basic Latin, Latin-1 Supplement, y General Punctuation)
    // Esto debería eliminar caracteres extraños como los del script tibetano (script 17)
    return text.replace(/[^\u0020-\u007E\u00A0-\u00FF\u2000-\u206F]/g, '');
}

// --- Funciones de Truncamiento Inteligente ---

function smartTruncate(fullText, maxLength) {
    if (!fullText) {
        return "";
    }
    if (fullText.length <= maxLength) {
        // Si el texto no se trunca, asegurarse de que termina con un punto.
        const trimmedText = fullText.trim();
        if (trimmedText.endsWith('.') || trimmedText.endsWith('…') || trimmedText.endsWith('?') || trimmedText.endsWith('!')) {
            return trimmedText;
        }
        return trimmedText + '.';
    }

    // 1. Encontrar el primer espacio DESPUÉS del límite para no cortar palabras.
    let cutIndex = fullText.indexOf(' ', maxLength);

    // Si no hay espacios después, significa que estamos en la última palabra.
    // Buscamos hacia atrás para respetar la palabra actual.
    if (cutIndex === -1) {
        cutIndex = fullText.lastIndexOf(' ');
    }

    // Si no hay ningún espacio en todo el texto, cortamos a la fuerza.
    if (cutIndex === -1) {
        return fullText.substring(0, maxLength) + "…";
    }

    // 2. Truncar el texto hasta el final de la palabra encontrada.
    let truncatedText = fullText.substring(0, cutIndex);

    // 3. Determinar si el texto truncado ya es el texto completo.
    // Usamos trim() para ignorar espacios finales.
    if (truncatedText.trim().length >= fullText.trim().length) {
        // Si el texto truncado es igual o más largo que el original (por los espacios),
        // significa que hemos incluido todo. Terminamos con un punto.
        return fullText.trim() + ".";
    } else {
        // Si todavía falta texto, usamos puntos suspensivos.
        return truncatedText + "…";
    }
}

export function truncateTitleForTooltip(text) {
    if (!text) return "";
    const maxLength = 35;
    return smartTruncate(text, maxLength);
}

export function formatDescriptionForTooltip(htmlText) {
    if (!htmlText) return "";

    let decoded = decodeHtmlEntities(htmlText);
    let plainText = decoded.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
    
    const maxLength = 300;
    return smartTruncate(plainText, maxLength);
}

// --- Sección de Parsing de Feeds ---

function parseItemsFromRegex(xml, itemRegex, titleRegex, linkRegex, guidRegex, pubDateRegex, descriptionRegex, feedUrl, maxItems, feedTimestamps) {
    // Usamos una nueva instancia de la RegExp para evitar problemas con el estado de 'lastIndex' en búsquedas globales.
    var items = xml.match(new RegExp(itemRegex)) || [];
    var newItems = [];

    for (var i = 0; i < Math.min(items.length, maxItems); i++) {
        var item = items[i].replace(/\s+/g, ' ').trim();
        var titleMatch = item.match(new RegExp(titleRegex));
        var linkMatch = item.match(linkRegex) || item.match(guidRegex);
        var pubDateMatch = item.match(pubDateRegex);
        var descriptionMatch = descriptionRegex ? item.match(new RegExp(descriptionRegex)) : null;

        if (titleMatch && titleMatch[1] && titleMatch[1].trim()) {
            var title = decodeHtmlEntities(titleMatch[1].trim());
            var link = (linkMatch && linkMatch[1]) ? linkMatch[1].trim() : "";
            var pubDate = (pubDateMatch && pubDateMatch[1]) ? new Date(pubDateMatch[1]).getTime() : new Date().getTime();
            var description = (descriptionMatch && descriptionMatch[1]) ? descriptionMatch[1].trim() : "";
            var summary = formatDescriptionForTooltip(description);

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
                summary: summary,
                description: description,
                isNew: isNew,
                isLast: false
            });
        }
    }
    return newItems;
}

function parseRssStandard(xml, feedUrl, maxItems, feedTimestamps) {
    // Definimos las regex aquí para que se recreen en cada llamada.
    const itemRegex = /<item[^>]*>[\s\S]*?<\/item>/g;
    const titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
    const linkRegex = /<link[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/link>/i;
    const guidRegex = /<guid[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/guid>/i;
    const pubDateRegex = /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i;
    // Captura <content:encoded> o <description>.
    const descriptionRegex = /<(?:content:encoded|description)[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/(?:content:encoded|description)>/i;

    return parseItemsFromRegex(xml, itemRegex, titleRegex, linkRegex, guidRegex, pubDateRegex, descriptionRegex, feedUrl, maxItems, feedTimestamps);
}

function parseRssMultiline(xml, feedUrl, maxItems, feedTimestamps) {
    const itemRegex = /<item[^>]*>[\s\S]*?<\/item>/g;
    const titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
    const linkRegex = /<link[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/link>/i;
    const guidRegex = /<guid[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/guid>/i;
    const pubDateRegex = /<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i;
    const descriptionRegex = /<(?:content:encoded|description)[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/(?:content:encoded|description)>/i;

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
                var descriptionMatch = item.match(descriptionRegex);
                var description = (descriptionMatch && descriptionMatch[1]) ? descriptionMatch[1].trim() : "";
                var summary = formatDescriptionForTooltip(description);

                var isNew = false;
                if (!feedTimestamps[feedUrl]) {
                    feedTimestamps[feedUrl] = {};
                    isNew = true;
                } else if (!feedTimestamps[feedUrl][title] || pubDate > feedTimestamps[feedUrl][title]) {
                    isNew = true;
                }

                feedTimestamps[feedUrl] = feedTimestamps[feedUrl] || {};
                feedTimestamps[feedUrl][title] = pubDate;

                newItems.push({ title: title, link: link, description: description, summary: summary, isNew: isNew, isLast: false });
            }
        }
    }
    return newItems;
}

function parseRssAlternative(xml, feedUrl, maxItems, feedTimestamps) {
    const itemRegex = /<entry[^>]*>[\s\S]*?<\/entry>/g;
    const titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
    const linkRegex = /<link[^>]*href="([^"]*)"[^>]*/i;
    const guidRegex = /<id[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/id>/i;
    const pubDateRegex = /<updated[^>]*>([\s\S]*?)<\/updated>/i;
    const descriptionRegex = /<summary[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/summary>/i;

    return parseItemsFromRegex(xml, itemRegex, titleRegex, linkRegex, guidRegex, pubDateRegex, descriptionRegex, feedUrl, maxItems, feedTimestamps);
}

function parseAtomFeeds(xml, feedUrl, maxItems, feedTimestamps) {
    const itemRegex = /<entry[^>]*>[\s\S]*?<\/entry>/g;
    const titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
    const linkRegex = /<link[^>]*href="([^"]*)"[^>]*>/i;
    const guidRegex = /<id[^>]*>([\s\S]*?)<\/id>/i;
    const pubDateRegex = /<published[^>]*>([\s\S]*?)<\/published>/i;
    const descriptionRegex = /<summary[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/summary>/i;

    return parseItemsFromRegex(xml, itemRegex, titleRegex, linkRegex, guidRegex, pubDateRegex, descriptionRegex, feedUrl, maxItems, feedTimestamps);
}

function parseMinimalXml(xml, feedUrl, maxItems) {
    const titleRegex = /<title[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/gi;
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
                    summary: "", // No hay resumen en este modo
                    description: "", // No hay descripción en este modo
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

export function getFaviconUrlCandidates(feedUrl, size = 32) { // Aceptamos un parámetro de tamaño
    if (!feedUrl || !size) {
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
            "https://logo.clearbit.com/" + domain + "?size=" + size,
            "https://www.google.com/s2/favicons?domain=" + domain + "&sz=" + size,
            "https://favicon.yandex.net/favicon/" + domain,
            "https://" + domain + "/favicon.ico"
        ];
    } catch (e) {
        console.error("Error generando candidatos de favicon para:", feedUrl, e);
        return [];
    }
}