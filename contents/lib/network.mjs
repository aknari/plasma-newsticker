// Módulo para gestionar todas las operaciones de red

// Realiza una petición GET simple y devuelve el texto de la respuesta
function fetchText(url) {
    return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    resolve(xhr.responseText);
                } else {
                    reject(`HTTP Error: ${xhr.status} for ${url}`);
                }
            }
        };
        xhr.onerror = function() {
            reject(`Network Error for ${url}`);
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36");
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
