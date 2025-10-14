import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string fileUrl: ""
    property string content: ""

    // Función principal de exportación
    function exportOpml() {
        console.log("📝 OpmlExporter: Componente listo");
        console.log("📝 OpmlExporter: Iniciando exportación...");

        if (!fileUrl || content.length === 0) {
            console.error("❌ OpmlExporter: fileUrl o content están vacíos.");
            return false;
        }

        try {
            console.log("🚀 OpmlExporter: Intentando escribir archivo con Kirigami.FileUtils...");
            console.log("📦 Contenido a escribir (primeros 200 caracteres):", content.substring(0, 200).replace(/\n/g, "\\n"));

            // Usar el método nativo de Kirigami para escribir el archivo.
            // Este método maneja la codificación y la escritura de forma robusta.
            var success = Kirigami.FileUtils.writeFile(fileUrl, content);
            
            console.log(success ? "✅ OpmlExporter: Kirigami.FileUtils reporta éxito." : "❌ OpmlExporter: Kirigami.FileUtils reporta fallo.");
            return success;
        } catch (e) {
            console.error("❌ OpmlExporter: Error crítico durante la exportación con FileUtils:", e);
            return false;
        }
    }
}