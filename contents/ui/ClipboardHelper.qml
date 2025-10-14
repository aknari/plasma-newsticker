import QtQuick
import org.kde.kirigami as Kirigami

pragma Singleton

// Este es un componente Singleton para acceder al portapapeles de forma global.
// Se debe registrar en el fichero qmldir.
QtObject {
    // La función para copiar texto. Ahora es accesible globalmente.
    function copy(text) {
        console.log("🚀 ClipboardHelper: Recibida solicitud para copiar al portapapeles.");
        try {
            Kirigami.Clipboard.mimeData.text = text;
            console.log("✅ ClipboardHelper: Texto copiado exitosamente. Longitud:", text.length);
            return true;
        } catch (e) {
            console.error("❌ ClipboardHelper: Error crítico al copiar:", e);
            return false;
        }
    }
}