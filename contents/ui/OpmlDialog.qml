import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Dialog {
    id: root

    property alias opmlContent: opmlTextArea.text
    property bool isImport: false

    signal opmlAccepted(string content)

    modal: true
    standardButtons: QQC2.Dialog.Cancel

    contentItem: Item {
        implicitWidth: Kirigami.Units.gridUnit * 30
        implicitHeight: Kirigami.Units.gridUnit * 20

        ColumnLayout {
            anchors.fill: parent

            QQC2.Label {
                id: dialogTitle
                font.bold: true
                text: root.title // Usar la propiedad 'title' del diálogo padre
            }

            QQC2.TextArea {
                id: opmlTextArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                wrapMode: Text.NoWrap
                font.family: "monospace"
                readOnly: !isImport
            }
        }
    }

    footer: QQC2.DialogButtonBox {
        standardButtons: root.standardButtons
        alignment: Qt.AlignRight

        QQC2.Button {
            text: isImport ? i18n("Import") : i18n("Copy to Clipboard")
            highlighted: true
            onClicked: {
                if (isImport) {
                    root.opmlAccepted(opmlTextArea.text)
                } else {
                    opmlTextArea.selectAll()
                    opmlTextArea.copy()
                }
                root.close()
            }
        }
    }
}