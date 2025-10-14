import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Controls // Importación adicional para propiedades adjuntas como ToolTip
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols as KQC

Kirigami.FormLayout {
    id: root

    property string cfg_scrollSpeedDefault: "50"
    property bool cfg_showIconsDefault: true
    property color cfg_textColorDefault: PlasmaCore.Theme.textColor
    property int cfg_fontSizeDefault: 12
    property string cfg_fontFamilyDefault: PlasmaCore.Theme.defaultFont.family
    property int cfg_maxItemsDefault: 10
    property int cfg_updateIntervalDefault: 15
    property bool cfg_transparentBackgroundDefault: false
    property bool cfg_blinkNewItemsDefault: false

    // Propiedades actuales
    property alias cfg_scrollSpeed: scrollSpeedSpinBox.value
    property alias cfg_showIcons: showIconsCheckBox.checked
    property alias cfg_textColor: colorButton.color
    property alias cfg_fontSize: fontSizeSpinBox.value
    property alias cfg_fontFamily: fontButton.font.family
    property alias cfg_maxItems: maxItemsSpinBox.value
    property alias cfg_updateInterval: updateIntervalSpinBox.value
    property alias cfg_transparentBackground: transparentBackgroundCheckBox.checked
    property alias cfg_blinkNewItems: blinkNewItemsCheckBox.checked

    Component.onCompleted: {
        // Inicializar la fuente con el valor por defecto si no está establecida
        if (!cfg_fontFamily) {
            cfg_fontFamily = cfg_fontFamilyDefault
        }
    }

    QQC2.ScrollView {
        id: scrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        ColumnLayout {
            width: scrollView.availableWidth
            spacing: Kirigami.Units.smallSpacing
            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.SpinBox {
                    id: scrollSpeedSpinBox
                    Kirigami.FormData.label: i18n("Scroll Speed:")
                    from: 10
                    to: 100
                    stepSize: 5
                    value: root.cfg_scrollSpeedDefault
                }

                QQC2.CheckBox {
                    id: showIconsCheckBox
                    text: i18n("Display feed icons")
                    Kirigami.FormData.label: i18n("Show Icons:")
                    checked: root.cfg_showIconsDefault
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Font type & Color:")
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    
                    QQC2.Button {
                        id: fontButton
                        text: cfg_fontFamily
                        Layout.fillWidth: true // Permitir que este botón se expanda
                        onClicked: fontDialog.open()
                        
                        FontDialog {
                            id: fontDialog
                            title: i18n("Select Font")
                            options: FontDialog.NoSizes // ¡Aquí está la clave! Oculta el selector de tamaño.
                            selectedFont.family: cfg_fontFamily
                            onAccepted: {
                                cfg_fontFamily = selectedFont.family
                            }
                        }
                    }
                    
                    QQC2.SpinBox {
                        id: fontSizeSpinBox
                        from: 8
                        to: 72
                        value: root.cfg_fontSizeDefault
                    }
                    
                    KQC.ColorButton {
                        id: colorButton
                        color: root.cfg_textColorDefault
                    }
                }

                QQC2.CheckBox {
                    id: transparentBackgroundCheckBox
                    text: i18n("Transparent Background")
                    Kirigami.FormData.label: i18n("Background:")
                    checked: root.cfg_transparentBackgroundDefault
                }

                QQC2.CheckBox {
                    id: blinkNewItemsCheckBox
                    text: i18n("Blink New Items")
                    checked: root.cfg_blinkNewItemsDefault
                }

                QQC2.SpinBox {
                    id: maxItemsSpinBox
                    Kirigami.FormData.label: i18n("Maximum Items per Feed:")
                    from: 1
                    to: 50
                    value: root.cfg_maxItemsDefault
                }

                QQC2.SpinBox {
                    id: updateIntervalSpinBox
                    Kirigami.FormData.label: i18n("Update Interval (minutes):")
                    from: 1
                    to: 60
                    value: root.cfg_updateIntervalDefault
                }
            }
        }
    }
}