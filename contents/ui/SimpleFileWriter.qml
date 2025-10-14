import QtQuick

Item {
    property string fileUrl: ""
    property string content: ""

    function writeFile() {
        console.log("📝 SimpleFileWriter: Intentando escribir archivo:", fileUrl);
        console.log("📝 SimpleFileWriter: Longitud del contenido:", content.length);

        // Probar múltiples métodos hasta que uno funcione
        return writeFileWithXHR() || writeFileWithAlternativeMethod();
    }

    function writeFileWithXHR() {
        try {
            console.log("📝 SimpleFileWriter: Probando método XMLHttpRequest...");

            var xhr = new XMLHttpRequest();

            // Configuración optimizada para KDE Plasma
            xhr.open("PUT", fileUrl, false);
            xhr.setRequestHeader("Content-Type", "application/xml; charset=UTF-8");
            xhr.setRequestHeader("Cache-Control", "no-cache");
            xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest");

            // Configurar timeout
            xhr.timeout = 3000;

            console.log("📝 SimpleFileWriter: Enviando contenido...");
            xhr.send(content);

            // Verificar múltiples condiciones de éxito
            if (xhr.status === 200 || xhr.status === 201 || xhr.status === 0) {
                console.log("📝 SimpleFileWriter: Archivo escrito exitosamente con XMLHttpRequest");
                return true;
            } else {
                console.log("📝 SimpleFileWriter: XMLHttpRequest falló con status:", xhr.status);
                return false;
            }

        } catch (xhrError) {
            console.log("📝 SimpleFileWriter: Error en XMLHttpRequest:", xhrError);
            return false;
        }
    }

    function writeFileWithAlternativeMethod() {
        try {
            console.log("📝 SimpleFileWriter: Probando método alternativo...");

            // Crear un componente temporal para escritura diferida
            var delayedWriter = Qt.createQmlObject(`
                import QtQuick;
                Item {
                    property string fileUrl: "";
                    property string content: "";
                    property bool success: false;

                    Component.onCompleted: {
                        var xhr = new XMLHttpRequest();
                        xhr.open("PUT", fileUrl, false);
                        xhr.setRequestHeader("Content-Type", "application/xml; charset=UTF-8");
                        xhr.send(content);

                        if (xhr.status === 200 || xhr.status === 0) {
                            success = true;
                        }

                        destroy();
                    }
                }
            `, parent, "DelayedWriter");

            delayedWriter.fileUrl = fileUrl;
            delayedWriter.content = content;

            // Esperar un poco para que se complete la operación
            var waitTimer = Qt.createQmlObject(`
                import QtQuick;
                Timer {
                    interval: 100;
                    repeat: false;
                    onTriggered: destroy();
                }
            `, parent);

            waitTimer.start();

            // Verificar resultado después de un breve delay
            if (delayedWriter.success) {
                console.log("📝 SimpleFileWriter: Método alternativo exitoso");
                return true;
            } else {
                console.log("📝 SimpleFileWriter: Método alternativo también falló");
                return false;
            }

        } catch (error) {
            console.error("📝 SimpleFileWriter: Error en método alternativo:", error);
            return false;
        }
    }

    Component.onCompleted: {
        console.log("📝 SimpleFileWriter: Componente creado");
    }

    Component.onDestruction: {
        console.log("📝 SimpleFileWriter: Componente destruido");
    }
}