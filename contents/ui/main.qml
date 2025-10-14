import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt.labs.platform as Platform
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "utils.mjs" as Utils
import "network.mjs" as Network

PlasmoidItem {
    id: root
    
    Plasmoid.backgroundHints: plasmoid.configuration.transparentBackground ? "NoBackground" : "StandardBackground"

    // Configuración de Layout para comportamiento de panel spacer
    Layout.fillWidth: expanding
    Layout.fillHeight: expanding
    Layout.minimumWidth: Plasmoid.containment.corona?.editMode ? Kirigami.Units.gridUnit * 2 : 1
    Layout.minimumHeight: Plasmoid.containment.corona?.editMode ? Kirigami.Units.gridUnit * 2 : 1

    Layout.preferredWidth: horizontal
        ? (expanding ? optimalSize : Plasmoid.configuration.length || 200)
        : 0
    Layout.preferredHeight: horizontal
        ? 0
        : (expanding ? optimalSize : Plasmoid.configuration.length || 200)

    // Usamos el nuevo archivo para la configuración
    preferredRepresentation: fullRepresentation
    
    // Representación para la configuración en línea (cuando se hace clic en modo edición)
    compactRepresentation: Component {
        ColumnLayout {
            GridLayout {
                columns: 2
                
                QQC2.Label {
                    text: i18n("Flexible size")
                    Layout.alignment: Qt.AlignRight
                }
                QQC2.Switch {
                    id: expandingSwitch
                    checked: plasmoid.configuration.expanding
                    onCheckedChanged: plasmoid.configuration.expanding = checked
                }

                QQC2.Label {
                    text: i18n("Fixed size:")
                    visible: !expandingSwitch.checked
                    Layout.alignment: Qt.AlignRight
                }
                QQC2.Slider {
                    id: lengthSlider
                    visible: !expandingSwitch.checked
                    from: 50
                    to: 1000
                    value: plasmoid.configuration.length
                    onValueChanged: plasmoid.configuration.length = value
                    stepSize: 25
                    Layout.fillWidth: true
                }
            }
        }
    }

    property int scrollSpeed: plasmoid.configuration.scrollSpeed
    property int slowScrollSpeed: 10
    property int currentScrollSpeed: scrollSpeed
    property bool autoScroll: true
    property bool showIcons: plasmoid.configuration.showIcons
    property color textColor: plasmoid.configuration.textColor
    property int fontSize: plasmoid.configuration.fontSize
    property string fontFamily: plasmoid.configuration.fontFamily
    property bool blinkNewItems: plasmoid.configuration.blinkNewItems
    property var feedList: Plasmoid.configuration.feedList || []
    property int currentFeedIndex: 0
    property int maxItems: 10
    property string currentFaviconUrl: ""
    property string currentFeedBaseUrl: ""
    property bool isInitialized: false
    property bool transparentBackground: plasmoid.configuration.transparentBackground
    property var previousTitles: ({})
    property var feedTimestamps: ({})
    property string pendingFaviconUrl: ""
    property var faviconCandidates: []
    property int currentFaviconCandidate: 0
    property var newsModel: []
    property bool isLastTitleOfFeed: false
    property bool isTransitioning: false
    property int transitionDelay: 3000
    property real lastTitlePosition: 0 // TODO: Revisar si esta propiedad sigue siendo útil
    property bool isScrolling: false
    property var nextFeedData: []
    property real scrollPos: 0
    property string preloadedFeedContent: ""
    property real faviconOpacity: 1.0
    property bool faviconReady: false
    property var pendingNewsModel: null
    property bool isFaviconLoading: false
    property int minDisplayTime: 5000
    property var feedStartTime: 0
    property bool hasValidContent: false
    property var preloadedData: null // Objeto que contendrá { content, faviconUrl }

    // Constantes para valores "mágicos"
    readonly property string newsSeparator: "•"
    // Espaciado para el separador de noticias. Opciones:
    // - Kirigami.Units.smallSpacing  (espacio pequeño estándar)
    // - Kirigami.Units.gridUnit      (un poco más grande, ~8px)
    // - Kirigami.Units.gridUnit * 2  (el doble del anterior, ~16px)
    // - root.fontSize * 0.75         (relativo al tamaño de la fuente)
    // - 12                         (píxeles fijos)
    readonly property int newsSeparatorMargin: Kirigami.Units.gridUnit * 1.2


    // Propiedades para comportamiento de panel spacer
    property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    property bool expanding: Plasmoid.configuration.expanding || false

    property GridLayout panelLayout: {
        // Método robusto para encontrar el GridLayout del panel
        let candidate = root.parent
        while (candidate) {
            if (candidate instanceof GridLayout) return candidate
            candidate = candidate.parent
        }
        return null
    }

    property real optimalSize: {
        // Lógica de cálculo de tamaño portada de plasma-newsticker-dev-02
        if (!panelLayout || !expanding) return Plasmoid.configuration.length || 200;
        try {
            let expandingSpacers = 0;
            let thisSpacerIndex = null;
            let sizeHints = [0];

            for (const child of panelLayout.children) {
                if (!child.visible) {
                    continue;
                }

                // Identifica los espaciadores (incluyéndose a sí mismo)
                if (child.applet?.plasmoid?.pluginName === 'org.kde.plasma.panelspacer' && child.applet.plasmoid.configuration.expanding) {
                    if (child.applet.plasmoid === Plasmoid) thisSpacerIndex = expandingSpacers
                    sizeHints.push(0);
                    expandingSpacers++;
                } else if (root.horizontal) {
                    sizeHints[sizeHints.length - 1] += Math.min(child.Layout.maximumWidth, Math.max(child.Layout.minimumWidth, child.Layout.preferredWidth)) + panelLayout.rowSpacing;
                } else {
                    sizeHints[sizeHints.length - 1] += Math.min(child.Layout.maximumHeight, Math.max(child.Layout.minimumHeight, child.Layout.preferredHeight)) + panelLayout.columnSpacing;
                }
            }

            sizeHints[0] *= 2; sizeHints[sizeHints.length - 1] *= 2;

            let containment = Plasmoid.containmentItem;
            if (!containment) {
                return Plasmoid.configuration.length || 200;
            }

            let availableSize = root.horizontal ? containment.width : containment.height;

            let opt = (availableSize / expandingSpacers) - (sizeHints[thisSpacerIndex] / 2) - (sizeHints[thisSpacerIndex + 1] / 2);
            return Math.max(opt, 50); // Devolver el tamaño calculado con un mínimo de 50px
        } catch (error) {
            console.error("Error calculando optimalSize:", error);
            return 200; // Valor seguro en caso de error
        }
    }

    // Esta función ahora solo obtiene los candidatos, la validación se hace en network.mjs
    function getFaviconUrl(feedUrl) {
        // La lógica de prioridades específicas se puede reimplementar si es necesario,
        // pero el nuevo sistema de validación automática debería ser más robusto.
        return Utils.getFaviconUrlCandidates(feedUrl);
    }

    // Intenta encontrar un favicon válido de una lista de candidatos.
    // Esta función debe estar en QML porque necesita el tipo 'Image'.
    function findValidFavicon(candidates) {
        return new Promise((resolve) => {
            let currentIndex = 0;

            function tryNext() {
                if (currentIndex >= candidates.length) {
                    resolve(null); // No se encontró ningún favicon válido
                    return;
                }

                const url = candidates[currentIndex];
                // Usamos Qt.createQmlObject para crear una instancia de Image dinámicamente
                var img = Qt.createQmlObject('import QtQuick 2.0; Image {}', root, "dynamicImage");
                img.source = url;

                img.statusChanged.connect(function() {
                    if (img.status === Image.Ready) {
                        const aspectRatio = img.width / img.height;
                        if (aspectRatio >= 0.5 && aspectRatio <= 2.0) {
                            resolve(url); // ¡Favicon válido encontrado!
                        } else {
                            currentIndex++;
                            tryNext();
                        }
                    } else if (img.status === Image.Error) {
                        currentIndex++;
                        tryNext();
                    }
                    // Al final, destruir el objeto para no consumir memoria
                    if (img.status !== Image.Loading) img.destroy();
                });
            }
            tryNext();
        });
    }

    // Funciones de transición entre feeds
    function startFeedTransition() {
        if (isTransitioning) {
            return
        }

        isTransitioning = true;
        feedStartTime = new Date().getTime();

        faviconOpacityAnimation.to = 0;
        faviconOpacityAnimation.start();

        newsOpacityAnimation.to = 0;
        newsOpacityAnimation.start();

        transitionTimer.start();
    }

    function completeFeedTransition() {
        if (!isTransitioning) return;

        currentFeedIndex = (currentFeedIndex + 1) % feedList.length;

        if (feedList && feedList.length > 0) {
            var feedUrl = feedList[currentFeedIndex];
            if (preloadedData && preloadedData.content) {
                // Usar los datos pre-cargados (contenido y favicon)
                parseFeed(preloadedData.content, feedUrl, preloadedData.faviconUrl);
                preloadedData = null; // Limpiar para la siguiente ronda
            } else {
                loadFeed(feedUrl, true); // Cargar y buscar favicon ahora
            }
        } else {
            isTransitioning = false;
        }
    }

    function updateNewsModel() {
        // Esta función se simplifica o elimina, ya que el modelo se actualiza de una vez.
        newsRow.x = newsContainer.width
        faviconOpacityAnimation.to = 1.0
        faviconOpacityAnimation.start()
        newsOpacityAnimation.to = 1.0
        newsOpacityAnimation.start()
    }

    // Funciones de carga de feeds simplificadas
    function loadCurrentFeed() {
        if (!feedList || feedList.length === 0) {
            console.warn("No hay feeds configurados.");
            isInitialized = false;
            return;
        }

        if (currentFeedIndex >= feedList.length) {
            console.log("⚠️ Índice de feed inválido, reiniciando");
            currentFeedIndex = 0;
        }

        var feedUrl = feedList[currentFeedIndex];
        if (!feedUrl || feedUrl.trim() === "") {
            console.warn("Feed vacío encontrado en la lista, avanzando al siguiente.");
            advanceToNextFeed();
            return;
        }

        console.log("🔄 Cargando feed:", feedUrl);
        loadFeed(feedUrl, true); // <--- SOLUCIÓN 1: Forzar la búsqueda de favicon para el primer feed
    }

    function advanceToNextFeed() {
        if (isTransitioning) {
            return;
        }

        currentFeedIndex = (currentFeedIndex + 1) % feedList.length;

        if (currentFeedIndex === 0) {
            console.log("🔄 Completado ciclo completo de feeds");
        }

        loadCurrentFeed();
    }

    function loadFeed(feedUrl, findFaviconNow = false) {
        Network.fetchFeed(feedUrl).then(content => {
            if (content) {
                if (findFaviconNow) {
                    const candidates = Utils.getFaviconUrlCandidates(feedUrl);
                    findValidFavicon(candidates).then(validFavicon => {
                        const faviconUrl = validFavicon || "image://icon/applications-internet";
                        parseFeed(content, feedUrl, faviconUrl);
                    });
                } else {
                    parseFeed(content, feedUrl, "image://icon/applications-internet");
                }
            } else {
                console.error("❌ Error cargando feed:", feedUrl);
                isTransitioning = false;
                advanceToNextFeed();
            }
        });
    }

    // Nueva función para pre-cargar el siguiente feed en segundo plano
    function preloadNextFeed() {
        if (!feedList || feedList.length <= 1) {
            preloadedData = null;
            return;
        }

        const nextIndex = (currentFeedIndex + 1) % feedList.length;
        const nextFeedUrl = feedList[nextIndex];

        if (!nextFeedUrl || !nextFeedUrl.trim()) {
            preloadedData = null;
            return;
        }

        const faviconCandidates = Utils.getFaviconUrlCandidates(nextFeedUrl);

        console.log(`⚡️ Pre-cargando siguiente feed y favicon para: ${nextFeedUrl}`);

        // Iniciar ambas tareas en paralelo
        const feedContentPromise = Network.fetchFeed(nextFeedUrl);
        const validFaviconPromise = findValidFavicon(faviconCandidates);

        // Usar Promise.all para esperar a que ambas terminen
        Promise.all([feedContentPromise, validFaviconPromise]).then(results => {
            const feedContent = results[0];
            const validFaviconUrl = results[1];

            preloadedData = {
                content: feedContent,
                faviconUrl: validFaviconUrl || "image://icon/applications-internet"
            };

            if (preloadedData.content) {
                console.log(`✅ Pre-carga completada para: ${nextFeedUrl}`);
            }
        });
    }


    function parseFeed(xml, feedUrl, faviconUrl) {
        try {
            // Verificar que el contenido recibido sea válido
            if (!xml || xml.trim().length === 0) {
                console.error("❌ Feed vacío recibido de " + feedUrl);
                isTransitioning = false;
                advanceToNextFeed();
                return;
            }

            // Usar el módulo de utilidades para el parsing
            var newItems = Utils.parseFeedWithMultipleStrategies(xml, feedUrl, root.maxItems, root.feedTimestamps);

            if (newItems.length > 0) {
                newItems[newItems.length - 1].isLast = true;
                hasValidContent = true;

                // Configurar modelo de noticias
                setupNewsModel(newItems, feedUrl, faviconUrl);

                // Iniciar la pre-carga del siguiente feed
                preloadNextFeed();
            } else {
                hasValidContent = false;
                isTransitioning = false;
                advanceToNextFeed();
            }
        } catch (e) {
            console.error("❌ Error crítico parseando feed " + feedUrl + ":", e);
            isTransitioning = false;
            advanceToNextFeed();
        }
    }

    function setupNewsModel(items, feedUrl, faviconUrl) {
        try {
            currentFeedBaseUrl = new URL(feedUrl).origin;
            currentFaviconUrl = faviconUrl;

            newsModel = items;
            
            // La animación ahora se controla en un solo lugar
            updateNewsModel();

            // La transición ha terminado
            isTransitioning = false;

        } catch (e) {
            console.error("❌ Error configurando modelo:", e);
            currentFeedBaseUrl = "";
            currentFaviconUrl = "image://icon/applications-internet";
            newsModel = items;
            updateNewsModel();
            isTransitioning = false;
        }
    }

    // Temporizadores
    Timer {
        id: safetyInitTimer
        interval: 10000
        repeat: false
        onTriggered: {
            initializeFeedsWithDelay()
        }
    }

    Timer {
        id: transitionTimer
        interval: 300
        repeat: false
        onTriggered: completeFeedTransition()
    }

    // Inicialización simplificada
    Component.onCompleted: {
        console.log("🚀 Iniciando News Ticker...");

        // Inicialización básica
        isInitialized = false;
        currentFeedIndex = -1;
        feedTimestamps = ({});
        newsModel = [];
        isTransitioning = false;
        currentFaviconUrl = "image://icon/applications-internet";

        // Iniciar carga después de un breve delay para asegurar que todo esté listo
        initializationTimer.start();
    }

    Timer {
        id: initializationTimer
        interval: 2000  // Delay más corto y predecible
        repeat: false

        onTriggered: {
            initializeFeeds();
        }
    }

    function initializeFeeds() {
        console.log("🔄 Inicializando feeds...");

        if (!feedList || feedList.length === 0) {
            console.warn("No hay feeds configurados para mostrar.");
            isInitialized = false;
            currentFeedIndex = -1;
            newsModel = [];
            currentFaviconUrl = "image://icon/applications-internet";
            return;
        }

        // Filtrar feeds válidos
        var validFeeds = feedList.filter(feed => feed && feed.trim() !== '');

        if (validFeeds.length === 0) {
            console.warn("La lista de feeds no contiene ninguna URL válida.");
            isInitialized = false;
            return;
        }

        // Iniciar carga del primer feed
        isInitialized = true;
        currentFeedIndex = 0;

        // Cargar el primer feed directamente sin reintentos complejos
        loadCurrentFeed();
    }

    Rectangle {
        id: container
        anchors.fill: parent
        clip: true
        color: "transparent"

        Item {
            id: faviconContainer
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: height
            visible: root.showIcons
            opacity: root.faviconOpacity

            Rectangle {
                id: faviconClip
                anchors.fill: parent
                color: "transparent"
                clip: true

                Image {
                    id: faviconImage
                    anchors.centerIn: parent
                    height: parent.height
                    width: parent.width
                    source: root.currentFaviconUrl
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(32, 32)
                    cache: false

                    // La lógica de onStatusChanged se ha movido a network.mjs
                    // Ahora el componente Image solo muestra la URL que ya ha sido validada.
                }
            }

            NumberAnimation {
                id: faviconOpacityAnimation
                target: faviconContainer
                property: "opacity"
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            id: newsContainer
            anchors.left: faviconContainer.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Kirigami.Units.smallSpacing
            color: "transparent"
            clip: true
            opacity: faviconContainer.opacity

            MouseArea {
                id: newsMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    root.currentScrollSpeed = root.slowScrollSpeed
                }
                onExited: {
                    root.currentScrollSpeed = root.scrollSpeed
                }
            }

            MouseArea {
                anchors.fill: parent
                onWheel: function(wheel) {
                    // Navegación mejorada según especificaciones del usuario
                    var delta = wheel.angleDelta.y / 120 * 40;

                    var newX = newsRow.x + delta;

                    // Calcular límites extremos para máxima libertad de navegación
                    var minX = -(newsRow.totalWidth) + 50;
                    var maxX = newsContainer.width - 50;

                    newX = Math.min(Math.max(newX, minX), maxX);

                    newsRow.x = newX;

                    // Comprobar si el desplazamiento manual ha llegado al final
                    if (newsRow.x + newsRow.totalWidth < -50) {
                        if (!isTransitioning) {
                            var currentTime = new Date().getTime();
                            if (currentTime - feedStartTime >= minDisplayTime && hasValidContent) {
                                startFeedTransition();
                            }
                        }
                    }
                }
            }

            Row {
                id: newsRow
                height: parent.height
                x: newsContainer.width

                property real totalWidth: {
                    var width = 0;
                    for (var i = 0; i < children.length; i++) {
                        width += children[i].width + spacing;
                    }
                    return width;
                }

                Repeater {
                    id: newsRepeater
                    model: root.newsModel
                    delegate: Item {
                        required property var modelData
                        id: newsItem
                        height: parent.height
                        width: contentRow.width
                        visible: modelData && modelData.title && modelData.title.length > 0

                        Row {
                            id: contentRow
                            height: parent.height
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents.Label {
                                id: titleText
                                text: modelData.title || ""
                                color: root.textColor
                                font {
                                    pointSize: root.fontSize
                                    family: root.fontFamily
                                    bold: modelData.isNew && !root.blinkNewItems
                                }
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                                visible: text.length > 0

                                PropertyAnimation {
                                    id: blinkAnimation
                                    target: titleText
                                    property: "opacity"
                                    from: 1.0
                                    to: 0.3
                                    duration: 1000
                                    running: modelData.isNew && root.blinkNewItems
                                    loops: Animation.Infinite
                                    easing.type: Easing.InOutQuad
                                    alwaysRunToEnd: true
                                }

                                PropertyAnimation {
                                    id: blinkBackAnimation
                                    target: titleText
                                    property: "opacity"
                                    from: 0.3
                                    to: 1.0
                                    duration: 1000
                                    running: blinkAnimation.running
                                    loops: Animation.Infinite
                                    easing.type: Easing.InOutQuad
                                    alwaysRunToEnd: true
                                }
                            }

                            // Separador mejorado para un control preciso
                            RowLayout {
                                id: separatorContainer
                                height: parent.height
                                visible: !modelData.isLast

                                PlasmaComponents.Label {
                                    text: root.newsSeparator
                                    color: root.textColor
                                    font {
                                        pointSize: root.fontSize
                                        family: root.fontFamily
                                    }
                                    opacity: 0.7
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.leftMargin: root.newsSeparatorMargin
                                    Layout.rightMargin: root.newsSeparatorMargin
                                }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.link) {
                                    Qt.openUrlExternally(modelData.link) // <--- SOLUCIÓN 2: Llamada correcta a la función
                                }
                            }
                        }
                    }
                }
            }

            NumberAnimation {
                id: newsOpacityAnimation
                target: newsContainer
                property: "opacity"
                duration: 300
                from: 0
                to: 1
                easing.type: Easing.InOutQuad
            }

            Timer {
                id: scrollTimer
                interval: 16
                running: root.autoScroll && newsRow.totalWidth > 0
                repeat: true

                onTriggered: {
                    if (!newsRow || newsRow.totalWidth <= 0) {
                        return;
                    }

                    var pixelsPerFrame = (root.currentScrollSpeed / 1000) * interval;

                    if (newsRow.x + newsRow.totalWidth < -50) {
                        if (!isTransitioning) {
                            var currentTime = new Date().getTime();
                            if (currentTime - feedStartTime >= minDisplayTime && hasValidContent) {
                                startFeedTransition();
                            }
                        }
                    } else {
                        newsRow.x -= pixelsPerFrame;
                    }
                }
            }
        }

        Connections {
            target: plasmoid.configuration

            function onFeedListChanged() {
                if (feedList && feedList.length > 0) {
                    if (!isInitialized) {
                        isInitialized = true
                        currentFeedIndex = 0
                        feedTimestamps = ({})
                        loadCurrentFeed()
                    } else {
                        if (currentFeedIndex >= feedList.length) {
                            currentFeedIndex = 0
                        }
                        loadCurrentFeed()
                    }
                } else {
                    isInitialized = false
                    currentFeedIndex = -1
                    newsModel = []
                    currentFaviconUrl = "image://icon/applications-internet"
                }
            }

            function onScrollSpeedChanged() {
                if (!newsMouseArea.containsMouse) {
                    currentScrollSpeed = plasmoid.configuration.scrollSpeed
                }
            }
        }
    }
}