// Módulo de utilidades para News Ticker

// --- Sección de Procesamiento de Texto Internacional ---

export function isRtl(text) {
    if (!text) return false;
    // Rangos de caracteres RTL: Hebreo, Árabe, Siríaco, Thaana, etc.
    const rtlChars = /[\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC]/;
    return rtlChars.test(text);
}

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
    text = text.replace(/&#(\d+);/g, function (match, dec) {
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
    text = text.replace(/&#x([0-9a-fA-F]+);/g, function (match, hex) {
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
            // Use link as unique identifier (more stable than title)
            var uniqueId = link || title; // Fallback to title if no link

            if (!feedTimestamps[feedUrl]) {
                feedTimestamps[feedUrl] = {};
                isNew = true;
            } else if (!feedTimestamps[feedUrl][uniqueId]) {
                // We've never seen this link before
                isNew = true;
            }
            // If we've seen this link before, it's not new (even if pubDate changed)

            feedTimestamps[feedUrl] = feedTimestamps[feedUrl] || {};
            feedTimestamps[feedUrl][uniqueId] = pubDate;

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
                // Use link as unique identifier (more stable than title)
                var uniqueId = link || title; // Fallback to title if no link

                if (!feedTimestamps[feedUrl]) {
                    feedTimestamps[feedUrl] = {};
                    isNew = true;
                } else if (!feedTimestamps[feedUrl][uniqueId]) {
                    // We've never seen this link before
                    isNew = true;
                }
                // If we've seen this link before, it's not new (even if pubDate changed)

                feedTimestamps[feedUrl] = feedTimestamps[feedUrl] || {};
                feedTimestamps[feedUrl][uniqueId] = pubDate;

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

// Nueva función para buscar el mejor favicon usando la API de Teamtailor
export function fetchFaviconFromTeamtailor(domain, targetSize) {
    return new Promise((resolve) => {
        if (!domain || !targetSize) {
            resolve(null);
            return;
        }

        const apiUrl = `https://favicons.teamtailor-cdn.com/allicons.json?url=${domain}`;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl);
        xhr.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36");

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        const data = JSON.parse(xhr.responseText);
                        if (data && data.icons && data.icons.length > 0) {
                            let bestIcon = null;
                            let minSizeDiff = Infinity;

                            for (const icon of data.icons) {
                                if (icon.url && icon.sizes) {
                                    const sizeStr = icon.sizes.split('x')[0];
                                    const size = parseInt(sizeStr, 10);
                                    if (!isNaN(size)) {
                                        const diff = Math.abs(size - targetSize);
                                        if (diff < minSizeDiff) {
                                            minSizeDiff = diff;
                                            bestIcon = icon;
                                        }
                                        // Si encontramos el tamaño exacto, lo usamos
                                        if (diff === 0) break;
                                    }
                                }
                            }

                            if (bestIcon) {
                                resolve(bestIcon.url);
                            } else {
                                // Si ninguno tiene tamaño, cogemos el primero
                                resolve(data.icons[0].url);
                            }

                        } else {
                            resolve(null);
                        }
                    } catch (e) {
                        console.error("Error parseando JSON de Teamtailor:", e);
                        resolve(null);
                    }
                } else {
                    resolve(null);
                }
            }
        };

        // Timeout de 5 segundos para la API de favicons
        xhr.timeout = 5000;
        xhr.ontimeout = function () {
            console.warn("[Favicon] Timeout alcanzado para la API de Teamtailor.");
            resolve(null);
        };

        xhr.onerror = function () {
            console.error("Error de red con la API de Teamtailor");
            resolve(null);
        };
        xhr.send();
    });
}


export function normalizeDomain(originalDomain) {
    const ignoredSubdomains = ['feeds', 'rss', 'news', 'api', 'feed', 'atom'];
    const parts = originalDomain.split('.');

    if (parts.length > 2) {
        const subdomain = parts[0];
        if (ignoredSubdomains.includes(subdomain)) {
            const rootDomain = parts.slice(1).join('.');
            // Devolver el dominio raíz y la versión con 'www' como candidatos
            return [rootDomain, 'www.' + rootDomain];
        }
    }

    // Si no hay subdominio o no está en la lista, devolver solo el original
    return [originalDomain];
}

export function getFaviconUrlCandidates(domain, size = 32) {
    if (!domain || !size) {
        return [];
    }
    // Devolver la lista de candidatos en orden de preferencia
    return [
        "https://www.google.com/s2/favicons?domain=" + domain + "&sz=" + size,
        "https://favicon.yandex.net/favicon/" + domain,
        "https://" + domain + "/favicon.ico"
    ];
}