import QtQuick
import org.kde.kirigami as Kirigami

// Este componente define la API que el plasmoide expone a su configuración.
Item {
    // Función que la configuración llamará para copiar al portapapeles.
    // El decorador @Slot hace que la función sea visible para el sistema de metadatos de Qt.
    function copyToClipboard(text) {
        console.log("🚀 Api.qml: Recibida solicitud para copiar al portapapeles");
        try {
            Kirigami.Clipboard.mimeData.text = text;
            console.log("✅ Api.qml: Texto copiado al portapapeles. Longitud:", text.length);
            return true;
        } catch (e) {
            console.error("❌ Api.qml: Error crítico al copiar al portapapeles:", e);
            return false;
        }
    }
}