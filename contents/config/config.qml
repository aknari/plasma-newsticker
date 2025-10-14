import QtQuick
// Usamos el import correcto para el modelo de configuración de Plasma
import org.kde.plasma.configuration 2.0

// ConfigModel es el contenedor principal que describe la estructura
// de la ventana de configuración a Plasma.
ConfigModel {
    // Cada ConfigCategory se convertirá en una pestaña en la interfaz.
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-configure"
        source: "../ui/configGeneral.qml"
    }

    ConfigCategory {
        name: i18n("Feeds")
        icon: "network-server"
        source: "../ui/configFeeds.qml"
    }
}