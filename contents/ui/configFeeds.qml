import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root

    // Declaramos la propiedad de configuración que esta pestaña necesita.
    // El ConfigModel inyectará aquí la lista de feeds.
    property var cfg_feedList: []

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
                            let temp = cfg_feedList.slice() // Crear una copia
                            temp.splice(index - 1, 0, temp.splice(index, 1)[0])
                            cfg_feedList = temp // Asignar la nueva copia
                        }
                    }
                    QQC2.Button {
                        icon.name: "go-down"
                        enabled: index < feedListView.count - 1
                        onClicked: {
                            let temp = cfg_feedList.slice() // Crear una copia
                            temp.splice(index + 1, 0, temp.splice(index, 1)[0])
                            cfg_feedList = temp // Asignar la nueva copia
                        }
                    }
                    QQC2.Button {
                        icon.name: "list-remove"
                        onClicked: {
                            let temp = cfg_feedList.slice() // Crear una copia
                            temp.splice(index, 1)
                            cfg_feedList = temp // Asignar la nueva copia
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
                    // Crear un nuevo array concatenando el antiguo con el nuevo elemento
                    cfg_feedList = cfg_feedList.concat([newFeedInput.text])
                    newFeedInput.text = ""
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
