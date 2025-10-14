import QtQuick
import QtQuick.Dialogs

Item {
    property string fileUrl: ""
    property string content: ""

    function writeFile() {
        try {
            console.log("📝 FileWriter: Intentando escribir archivo:", fileUrl);
            console.log("📝 FileWriter: Longitud del contenido:", content.length);

            // Usar XMLHttpRequest con configuración especial para KDE
            var xhr = new XMLHttpRequest();

            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    console.log("📝 FileWriter: Estado final:", xhr.status, xhr.statusText);
                    if (xhr.status === 200 || xhr.status === 0) {
                        console.log("📝 FileWriter: Archivo escrito exitosamente");
                        return true;
                    } else {
                        console.error("📝 FileWriter: Error escribiendo archivo:", xhr.status);
                        return false;
                    }
                }
            };

            // Configuración especial para KDE Plasma
            xhr.open("PUT", fileUrl, false);  // Usar false para operación síncrona
            xhr.setRequestHeader("Content-Type", "application/xml; charset=UTF-8");
            xhr.setRequestHeader("Cache-Control", "no-cache");

            console.log("📝 FileWriter: Enviando contenido...");
            xhr.send(content);

            return true;

        } catch (error) {
            console.error("📝 FileWriter: Error crítico:", error);
            return false;
        }
    }

    Component.onCompleted: {
        console.log("📝 FileWriter: Componente creado");
    }

    Component.onDestruction: {
        console.log("📝 FileWriter: Componente destruido");
    }
}