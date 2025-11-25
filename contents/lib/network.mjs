// Módulo para gestionar todas las operaciones de red

// Realiza una petición GET simple y devuelve el texto de la respuesta
function fetchText(url, attempt = 1) {
    return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    resolve(xhr.responseText);
                } else {
                    // Si falla con error 0 (network) o 5xx, intentamos una vez más
                    if ((xhr.status === 0 || xhr.status >= 500) && attempt < 2) {
                        console.warn(`[Network] Fallo en intento ${attempt} para ${url}. Reintentando...`);
                        setTimeout(() => {
                            fetchText(url, attempt + 1).then(resolve).catch(reject);
                        }, 1000);
                    } else {
                        reject(`HTTP Error: ${xhr.status} for ${url}`);
                    }
                }
            }
        };
        xhr.onerror = function() {
            if (attempt < 2) {
                console.warn(`[Network] Error de red en intento ${attempt} para ${url}. Reintentando...`);
                setTimeout(() => {
                    fetchText(url, attempt + 1).then(resolve).catch(reject);
                }, 1000);
            } else {
                reject(`Network Error for ${url}`);
            }
        };
        
        // Cache busting para evitar problemas con conexiones estancadas (HTTP/2 GOAWAY)
        const separator = url.includes('?') ? '&' : '?';
        const cacheBuster = separator + '_t=' + new Date().getTime();
        
        xhr.open("GET", url + cacheBuster);
        xhr.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36");
        xhr.setRequestHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        xhr.setRequestHeader("Pragma", "no-cache");
        xhr.setRequestHeader("Expires", "0");
        // Intentar cerrar la conexión para evitar HTTP/2 persistente problemático si es posible
        xhr.setRequestHeader("Connection", "close"); 
        xhr.send();
    });
}

// Función simple para cargar el feed inicial
export function fetchFeed(feedUrl) {
     return fetchText(feedUrl).catch(error => {
         console.error("Error cargando feed:", error);
         return null;
     });
}
