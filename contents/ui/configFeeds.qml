import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root

    // Se declaran TODAS las propiedades del kcfg para que ConfigModel las inyecte.
    property int cfg_scrollSpeed
    property bool cfg_showIcons
    property color cfg_textColor
    property int cfg_fontSize
    property string cfg_fontFamily
    property int cfg_maxItems
    property int cfg_updateInterval
    property bool cfg_transparentBackground
    property bool cfg_blinkNewItems
    property bool cfg_showTooltips
    property var cfg_feedList
    property bool cfg_expanding
    property int cfg_length

    property int cfg_scrollSpeedDefault
    property bool cfg_showIconsDefault
    property color cfg_textColorDefault
    property int cfg_fontSizeDefault
    property string cfg_fontFamilyDefault
    property int cfg_maxItemsDefault
    property int cfg_updateIntervalDefault
    property bool cfg_transparentBackgroundDefault
    property bool cfg_blinkNewItemsDefault
    property bool cfg_showTooltipsDefault
    property var cfg_feedListDefault
    property bool cfg_expandingDefault
    property int cfg_lengthDefault

    // Función para normalizar una URL para comparación
    function normalizeUrl(url) {
        if (!url) return "";
        return url.trim()
                  .toLowerCase()
                  .replace(/^https?:\/\//, '') // Eliminar http:// o https://
                  .replace(/^www\./, '')       // Eliminar www.
                  .replace(/\/$/, '');         // Eliminar barra final
    }


    function generateOpml() {
        let opml = '<?xml version="1.0" encoding="UTF-8"?>\n';
        opml += '<opml version="2.0">\n';
        opml += '  <head>\n';
        opml += '    <title>News Ticker Feeds</title>\n';
        opml += '  </head>\n';
        opml += '  <body>\n';

        cfg_feedList.forEach(feedUrl => {
            if (feedUrl) {
                // Escapar caracteres especiales en la URL para XML
                const escapedUrl = feedUrl.replace(/&/g, '&amp;')
                                          .replace(/</g, '&lt;')
                                          .replace(/>/g, '&gt;')
                                          .replace(/"/g, '&quot;')
                                          .replace(/'/g, '&apos;');
                opml += `    <outline type="rss" xmlUrl="${escapedUrl}" />\n`;
            }
        });

        opml += '  </body>\n';
        opml += '</opml>\n';
        return opml;
    }

    function importOpml(opmlContent) {
        const urlRegex = /xmlUrl="([^"]+)"/g;
        let match;
        const newFeeds = [];
        const currentFeeds = new Set(cfg_feedList || []);

        while ((match = urlRegex.exec(opmlContent)) !== null) {
            // Decodificar entidades XML básicas
            const url = match[1].replace(/&amp;/g, '&')
                                .replace(/&lt;/g, '<')
                                .replace(/&gt;/g, '>')
                                .replace(/&quot;/g, '"')
                                .replace(/&apos;/g, "'");
            if (!currentFeeds.has(url)) {
                newFeeds.push(url);
            }
        }

        if (newFeeds.length > 0) {
            cfg_feedList = (cfg_feedList || []).concat(newFeeds);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18n("RSS Feeds")
            font.bold: true
        }

        ListView {
            id: feedListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: cfg_feedList
            delegate: QQC2.ItemDelegate {
                width: parent.width
                text: modelData
                
                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Kirigami.Units.largeSpacing

                    QQC2.Button {
                        icon.name: "go-up"
                        enabled: index > 0
                        onClicked: {
                            // La forma correcta de acceder a la lista desde el delegate
                            let temp = feedListView.model.slice();
                            const item = temp.splice(index, 1)[0]; // 2. Mover elemento en la copia
                            temp.splice(index - 1, 0, item);
                            cfg_feedList = temp; // 3. Reasignar para notificar al ConfigModel y a la vista
                        }
                    }
                    QQC2.Button {
                        icon.name: "go-down"
                        enabled: index < feedListView.count - 1
                        onClicked: {
                            let temp = feedListView.model.slice();
                            const item = temp.splice(index, 1)[0];
                            temp.splice(index + 1, 0, item);
                            cfg_feedList = temp;
                        }
                    }
                    QQC2.Button {
                        icon.name: "list-remove"
                        onClicked: {
                            let temp = feedListView.model.slice();
                            temp.splice(index, 1);
                            cfg_feedList = temp;
                        }
                    }
                }
            }
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true

            QQC2.TextField {
                id: newFeedInput
                placeholderText: i18n("Add new feed URL")
                Layout.fillWidth: true
            }

            QQC2.Button {
                text: i18n("Add")
                enabled: newFeedInput.text.length > 0
                onClicked: {
                    const newUrl = newFeedInput.text.trim();
                    if (newUrl.length === 0) return;

                    const normalizedNewUrl = normalizeUrl(newUrl);
                    const existingNormalizedUrls = (cfg_feedList || []).map(normalizeUrl);

                    if (existingNormalizedUrls.includes(normalizedNewUrl)) {
                        // La URL ya existe, limpiar y no hacer nada
                        newFeedInput.text = "";
                        return;
                    }

                    // Añadir la nueva URL
                    cfg_feedList = (cfg_feedList || []).concat([newUrl]);
                    newFeedInput.text = "";
                }
            }

            QQC2.Button {
                text: i18n("Import OPML...")
                onClicked: {
                    opmlDialog.isImport = true
                    opmlDialog.title = i18n("Import Feeds from OPML")
                    opmlDialog.opmlContent = ""
                    opmlDialog.open()
                }
            }

            QQC2.Button {
                text: i18n("Export OPML...")
                enabled: cfg_feedList.length > 0
                onClicked: {
                    opmlDialog.isImport = false
                    opmlDialog.title = i18n("Export Feeds to OPML")
                    opmlDialog.opmlContent = generateOpml()
                    opmlDialog.open()
                }
            }
        }
    }

    OpmlDialog {
        id: opmlDialog
        onOpmlAccepted: (content) => importOpml(content)
    }
}
