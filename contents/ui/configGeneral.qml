import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols as KQC

Item {
    id: root
    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: Kirigami.Units.gridUnit * 20
    
    // Propiedades por defecto requeridas por el sistema de configuración de Plasma
    property string cfg_scrollSpeedDefault: "50"
    property bool cfg_showIconsDefault: true
    property color cfg_textColorDefault: PlasmaCore.Theme.textColor
    property int cfg_fontSizeDefault: 12
    property string cfg_fontFamilyDefault: PlasmaCore.Theme.defaultFont.family
    property var cfg_feedListDefault: []
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
    property var cfg_feedList: []  
    property alias cfg_maxItems: maxItemsSpinBox.value
    property alias cfg_updateInterval: updateIntervalSpinBox.value
    property alias cfg_transparentBackground: transparentBackgroundCheckBox.checked
    property alias cfg_blinkNewItems: blinkNewItemsCheckBox.checked

    Component.onCompleted: {
        // Inicializar la fuente con el valor por defecto si no está establecida
        if (!cfg_fontFamily) {
            cfg_fontFamily = cfg_fontFamilyDefault
        }
        
        // Inicializar la lista de feeds
        if (cfg_feedList && cfg_feedList.length > 0) {
            for (var i = 0; i < cfg_feedList.length; i++) {
                feedSelectorModel.append({"url": cfg_feedList[i], "title": cfg_feedList[i]})
            }
        }
    }

    QQC2.ScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        
        ColumnLayout {
            width: scrollView.availableWidth
            spacing: Kirigami.Units.smallSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Kirigami.FormData.label: i18n("RSS Feeds")
                    Layout.fillWidth: true
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        
                        QQC2.ComboBox {
                            id: feedSelector
                            Layout.fillWidth: true
                            model: ListModel {
                                id: feedSelectorModel
                                ListElement { 
                                    url: "Add new feed..."
                                    title: "Add new feed..."
                                }
                            }
                            textRole: "title"
                            onActivated: {
                                if (currentIndex > 0) {
                                    feedInput.text = model.get(currentIndex).url
                                    feedInput.readOnly = true
                                    addButton.enabled = false
                                    removeButton.enabled = true
                                } else {
                                    feedInput.text = ""
                                    feedInput.readOnly = false
                                    addButton.enabled = false
                                    removeButton.enabled = false
                                }
                            }
                        }
                        
                        QQC2.TextField {
                            id: feedInput
                            Layout.fillWidth: true
                            placeholderText: i18n("Enter RSS feed URL")
                            onTextChanged: {
                                if (!readOnly) {
                                    addButton.enabled = text.trim().length > 0
                                }
                            }
                        }
                        
                        QQC2.Button {
                            id: addButton
                            icon.name: "list-add"
                            enabled: false
                            onClicked: {
                                if (feedInput.text.trim()) {
                                    feedSelectorModel.append({"url": feedInput.text.trim(), "title": feedInput.text.trim()})
                                    updateFeedList()
                                    feedSelector.currentIndex = 0
                                    feedInput.text = ""
                                    feedInput.readOnly = false
                                    addButton.enabled = false
                                    removeButton.enabled = false
                                }
                            }
                        }
                        
                        QQC2.Button {
                            id: removeButton
                            icon.name: "list-remove"
                            enabled: false
                            onClicked: {
                                if (feedSelector.currentIndex > 0) {
                                    feedSelectorModel.remove(feedSelector.currentIndex)
                                    updateFeedList()
                                    feedSelector.currentIndex = 0
                                    feedInput.text = ""
                                    feedInput.readOnly = false
                                    addButton.enabled = false
                                    removeButton.enabled = false
                                }
                            }
                        }
                    }
                }

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
                    Kirigami.FormData.label: i18n("Font:")
                    
                    QQC2.Button {
                        id: fontButton
                        text: cfg_fontFamily
                        Layout.fillWidth: true
                        onClicked: fontDialog.open()
                        
                        FontDialog {
                            id: fontDialog
                            title: i18n("Select Font")
                            selectedFont.family: cfg_fontFamily
                            onAccepted: {
                                cfg_fontFamily = selectedFont.family
                            }
                        }
                    }
                }

                QQC2.SpinBox {
                    id: fontSizeSpinBox
                    Kirigami.FormData.label: i18n("Font Size:")
                    from: 8
                    to: 72
                    value: root.cfg_fontSizeDefault
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Text Color:")
                    
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

    function updateFeedList() {
        var urls = []
        for (var i = 1; i < feedSelectorModel.count; i++) {
            urls.push(feedSelectorModel.get(i).url)
        }
        cfg_feedList = urls
    }
}