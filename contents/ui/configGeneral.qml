import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import QtQuick.Dialogs
import org.kde.kquickcontrols as KQC

// El componente raíz debe ser una Page para que ConfigModel funcione correctamente.
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


    // El contenido visual va dentro de un ScrollView.
    QQC2.ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.smallSpacing
            
            Kirigami.FormLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Kirigami.FormData.label: i18n("Scroll Speed:")
                    Layout.fillWidth: true
                    Layout.maximumWidth: 282
                    
                    QQC2.Slider {
                        id: scrollSpeedSlider
                        Layout.fillWidth: true
                        from: 10
                        to: 100
                        stepSize: 5
                        value: cfg_scrollSpeed
                        onValueChanged: cfg_scrollSpeed = value
                    }
                    
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: i18n("Current: %1 px/s", Math.round(scrollSpeedSlider.value))
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                    }
                }

                QQC2.Switch {
                    id: showIconsSwitch
                    Kirigami.FormData.label: i18n("Display feed icons")
                    checked: cfg_showIcons
                    onCheckedChanged: cfg_showIcons = checked
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Font type & Color:")
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    
                    QQC2.ComboBox {
                        id: fontComboBox
                        Layout.fillWidth: true
                        model: Qt.fontFamilies()
                        currentIndex: model.indexOf(cfg_fontFamily) !== -1 ? model.indexOf(cfg_fontFamily) : 0
                        onCurrentIndexChanged: {
                            if (currentIndex !== -1) {
                                cfg_fontFamily = model[currentIndex]
                            }
                        }
                        Component.onCompleted: {
                            if (cfg_fontFamily && model.indexOf(cfg_fontFamily) === -1) {
                                // Si la fuente guardada no está en la lista, la añadimos al principio
                                // para no perder la configuración.
                                model.insert(0, cfg_fontFamily)
                                fontComboBox.currentIndex = 0
                            }
                        }
                    }

                    QQC2.SpinBox {
                        id: fontSizeSpinBox
                        from: 8
                        to: 72
                        value: cfg_fontSize
                        onValueChanged: cfg_fontSize = value
                    }

                    KQC.ColorButton {
                        id: colorButton
                        color: cfg_textColor
                        onColorChanged: cfg_textColor = color
                    }
                }

                QQC2.Switch {
                    id: transparentBackgroundSwitch
                    Kirigami.FormData.label: i18n("Transparent background")
                    checked: cfg_transparentBackground
                    onCheckedChanged: cfg_transparentBackground = checked
                }

                QQC2.Switch {
                    id: blinkNewItemsSwitch
                    Kirigami.FormData.label: i18n("Blink new items")
                    checked: cfg_blinkNewItems
                    onCheckedChanged: cfg_blinkNewItems = checked
                }

                QQC2.Switch {
                    id: showTooltipsSwitch
                    Kirigami.FormData.label: i18n("Show tooltips with details")
                    checked: cfg_showTooltips
                    onCheckedChanged: cfg_showTooltips = checked
                }

                QQC2.SpinBox {
                    id: maxItemsSpinBox
                    Kirigami.FormData.label: i18n("Maximum Items per Feed:")
                    from: 1
                    to: 50
                    value: cfg_maxItems
                    onValueChanged: cfg_maxItems = value
                }

                QQC2.SpinBox {
                    id: updateIntervalSpinBox
                    Kirigami.FormData.label: i18n("Update Interval (minutes):")
                    from: 1
                    to: 60
                    value: cfg_updateInterval
                    onValueChanged: cfg_updateInterval = value
                }
            }
        }
    }
}