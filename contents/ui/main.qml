import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt.labs.platform as Platform
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../lib/utils.mjs" as Utils
import "../lib/network.mjs" as Network

PlasmoidItem {
     // Cambiar a 'true' para ver todos los logs
    readonly property bool _debugMode: false
    
    id: root

    Plasmoid.backgroundHints: plasmoid.configuration.transparentBackground ? "NoBackground" : "StandardBackground"
    Layout.fillWidth: expanding
    Layout.fillHeight: expanding
    Layout.minimumWidth: Plasmoid.containment.corona?.editMode ? Kirigami.Units.gridUnit * 2 : 1
    Layout.minimumHeight: Plasmoid.containment.corona?.editMode ? Kirigami.Units.gridUnit * 2 : 1
    Layout.preferredWidth: horizontal ? (expanding ? optimalSize : Plasmoid.configuration.length || 200) : 0
    Layout.preferredHeight: horizontal ? 0 : (expanding ? optimalSize : Plasmoid.configuration.length || 200)
    preferredRepresentation: compactRepresentation
    compactRepresentation: tickerUiComponent
    fullRepresentation: Item {
        PlasmaComponents.Label {
            anchors.centerIn: parent
            text: "Full Representation (Not in use)"
        }
    }

    // --- Propiedades ---
    property var liveUi: null // Referencia a la UI viva
    
    // Señal para el "apretón de manos" asíncrono
    signal uiReady(var uiObject)
    property int scrollSpeed: plasmoid.configuration.scrollSpeed
    property int slowScrollSpeed: 10
    property int currentScrollSpeed: scrollSpeed
    property bool autoScroll: true
    property bool showIcons: plasmoid.configuration.showIcons
    property color textColor: plasmoid.configuration.textColor
    property int fontSize: plasmoid.configuration.fontSize
    property string fontFamily: plasmoid.configuration.fontFamily
    property bool blinkNewItems: plasmoid.configuration.blinkNewItems
    property bool showTooltips: plasmoid.configuration.showTooltips
    property var feedList: plasmoid.configuration.feedList || []
    property int currentFeedIndex: 0
    property int maxItems: plasmoid.configuration.maxItems || 10
    property string currentFaviconUrl: ""
    property bool isInitialized: false
    property var feedTimestamps: ({}) // Objeto para rastrear las marcas de tiempo de los items
    property var newsModel: []
    property bool isBusy: false // Bandera de bloqueo para operaciones asíncronas
    property int minDisplayTime: 5000
    property var feedStartTime: 0
    property bool hasValidContent: false
    property var preloadedData: null
    property bool allFeedsFailed: false
    property string emptyStateMessage: "" // Mensaje para cuando no hay contenido
    property int failedFeedAttempts: 0
    property real faviconOpacity: 1.0
    property int retryCount: 0 // Para el backoff exponencial
    property var lastAppliedFeedList: []

    property int optimalFaviconSize: {
        if (root.height >= 64) return 64;
        if (root.height >= 48) return 48;
        if (root.height >= 32) return 32;
        return 16;
    }
    readonly property string newsSeparator: "•"
    readonly property bool newsSeparatorBold: true
    readonly property int newsSeparatorMargin: Kirigami.Units.gridUnit * 1.2
    property bool horizontal: Plasmoid.formFactor !== 2 // 2 is Vertical in Plasma::Types::FormFactor
    property bool expanding: plasmoid.configuration.expanding || false

    property GridLayout panelLayout: {
        let candidate = root.parent;
        while (candidate) { if (candidate instanceof GridLayout) return candidate; candidate = candidate.parent; }
        return null;
    }
    property real optimalSize: {
        if (!panelLayout || !expanding) return Plasmoid.configuration.length || 200;
        try {
            let expandingSpacers = 0, thisSpacerIndex = null, sizeHints = [0];
            for (const child of panelLayout.children) {
                if (!child.visible) continue;
                if (child.applet?.plasmoid?.pluginName === 'org.kde.plasma.panelspacer' && child.applet.plasmoid.configuration.expanding) {
                    if (child.applet.plasmoid === Plasmoid) thisSpacerIndex = expandingSpacers;
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
            if (!containment) return Plasmoid.configuration.length || 200;
            let availableSize = root.horizontal ? containment.width : containment.height;
            let opt = (availableSize / expandingSpacers) - (sizeHints[thisSpacerIndex] / 2) - (sizeHints[thisSpacerIndex + 1] / 2);
            return Math.max(opt, 50);
        } catch (error) {
            if (_debugMode) console.error("Error calculando optimalSize:", error);
            return 200;
        }
    }

    // --- Lógica ---
    function findValidFavicon(candidates) {
        return new Promise((resolve) => {
            let currentIndex = 0;
            function tryNext() {
                if (currentIndex >= candidates.length) {
                    resolve(null);
                    return;
                }
                const url = candidates[currentIndex];
                var img = Qt.createQmlObject('import QtQuick 2.0; Image { visible: false }', root, "dynamicImage");
                img.source = url;
                img.statusChanged.connect(function() {
                    if (img.status === Image.Ready) {
                        const aspectRatio = img.width / img.height;
                        if (aspectRatio >= 0.5 && aspectRatio <= 2.0) {
                            resolve(url);
                        } else {
                            currentIndex++;
                            tryNext();
                        }
                    } else if (img.status === Image.Error) {
                        currentIndex++;
                        tryNext();
                    }
                    if (img.status !== Image.Loading) img.destroy();
                });
            }
            tryNext();
        });
    }

    function startFeedTransition() {
        if (_debugMode) console.log("🚦 [CHIVATO] Entrando en startFeedTransition(). Estado inicial de isBusy:", isBusy);
        if (isBusy) return;
        isBusy = true;
        if (_debugMode) console.log("   [CHIVATO] isBusy puesto a 'true'.");
        if (liveUi) {
            if (_debugMode) console.log("   [CHIVATO] liveUi existe. Llamando a animaciones y deteniendo scroll.");
            liveUi.startTransitionAnimations(0);
            liveUi.stopScrolling(); // ¡Detenemos el scrollTimer para que no interfiera!
        }
        if (_debugMode) console.log("   [CHIVATO] Dando la orden de iniciar transitionTimer y watchdogTimer...");
        transitionTimer.start();
        watchdogTimer.start(); // Inicia el temporizador de vigilancia
    }

    function completeFeedTransition() {
        if (_debugMode) console.log("🏁 [CHIVATO] Entrando en completeFeedTransition().");
        currentFeedIndex = (currentFeedIndex + 1) % feedList.length;
        if (preloadedData) { // Si la precarga tuvo éxito
            if (_debugMode) console.log("   [CHIVATO] ✅ Usando datos precargados.");
            setupNewsModel(preloadedData.items, preloadedData.feedUrl, preloadedData.faviconUrl);
            preloadedData = null;
        } else {
            console.warn("   [CHIVATO] ⚠️ No hay datos precargados. Cargando feed desde cero.");
            loadCurrentFeed(); // Si la precarga falló, carga el siguiente feed de forma normal
        }
    }

    function loadCurrentFeed() {
        if (!feedList || feedList.length === 0) {
            isInitialized = false;
            return;
        }
        if (currentFeedIndex >= feedList.length) currentFeedIndex = 0;
        var feedUrl = feedList[currentFeedIndex];
        if (!feedUrl || feedUrl.trim() === "") {
            advanceToNextFeed();
            return;
        }
        if (_debugMode) console.log("🔄 Cargando feed:", feedUrl);
        loadFeed(feedUrl, true);
    }

    function advanceToNextFeed() {
        isBusy = false;
        failedFeedAttempts++;
        if (failedFeedAttempts >= feedList.length) {
            allFeedsFailed = true;
            emptyStateMessage = i18n("All configured feeds failed to load. Please check the URLs and your network connection.");
            scheduleRetry();
            return;
        }
        currentFeedIndex = (currentFeedIndex + 1) % feedList.length;
        loadCurrentFeed();
    }

    function loadFeed(feedUrl, findFaviconNow) {
        if (_debugMode) console.log("[DEBUG] loadFeed: Registrando .then() para", feedUrl);
        Network.fetchFeed(feedUrl).then(content => {
            if (_debugMode) console.log("[DEBUG] loadFeed: .then() ejecutado. Contenido recibido:", !!content);
            if (content) {
                if (findFaviconNow) {
                    const candidates = Utils.getFaviconUrlCandidates(feedUrl, root.optimalFaviconSize);
                    findValidFavicon(candidates).then(validFavicon => {
                        const faviconUrl = validFavicon || "image://icon/applications-internet";
                        if (_debugMode) console.log("[DEBUG] loadFeed: Favicon encontrado/resuelto. Llamando a parseFeed.");
                        parseFeed(content, feedUrl, faviconUrl);
                    });
                } else {
                    parseFeed(content, feedUrl, "image://icon/applications-internet");
                }
            } else {
                advanceToNextFeed();
            }
        });
    }

    function preloadNextFeed() {
        if (_debugMode) console.log("⚡️ [CHIVATO] Iniciando preloadNextFeed()...");
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
        if (_debugMode) console.log(`⚡️ [CHIVATO] Intentando precargar: ${nextFeedUrl}`);
        const feedContentPromise = Network.fetchFeed(nextFeedUrl);
        const validFaviconPromise = findValidFavicon(Utils.getFaviconUrlCandidates(nextFeedUrl, root.optimalFaviconSize));
        Promise.all([feedContentPromise, validFaviconPromise]).then(results => {
            const feedContent = results[0];
            const validFaviconUrl = results[1];
            if (feedContent) {
                const preloadedItems = Utils.parseFeedWithMultipleStrategies(feedContent, nextFeedUrl, root.maxItems, root.feedTimestamps);
                if (preloadedItems.length > 0) {
                    preloadedItems[preloadedItems.length - 1].isLast = true;
                    preloadedData = {
                        items: preloadedItems,
                        feedUrl: nextFeedUrl,
                        faviconUrl: validFaviconUrl || "image://icon/applications-internet"
                    };
                    if (_debugMode) console.log(`✅ [CHIVATO] Precarga completada para: ${nextFeedUrl}`);
                } else {
                    preloadedData = null;
                    console.warn(`⚠️ [CHIVATO] Precarga para ${nextFeedUrl} no produjo items.`);
                }
            } else {
                preloadedData = null;
                console.warn(`⚠️ [CHIVATO] Falló la obtención de contenido durante la precarga de ${nextFeedUrl}.`);
            }
        });
    }

    function parseFeed(xml, feedUrl, faviconUrl) {
        if (_debugMode) console.log("[DEBUG] parseFeed: Iniciando parseo para", feedUrl);
        try {
            if (!xml || xml.trim().length === 0) {
                advanceToNextFeed();
                return;
            }
            var newItems = Utils.parseFeedWithMultipleStrategies(xml, feedUrl, root.maxItems, root.feedTimestamps);
            if (newItems.length > 0) {
                if (_debugMode) console.log(`[CHIVATO] parseFeed: Se encontraron ${newItems.length} items. Llamando a setupNewsModel.`);
                newItems[newItems.length - 1].isLast = true;
                hasValidContent = true;
                setupNewsModel(newItems, feedUrl, faviconUrl);
            } else {
                console.warn("[CHIVATO] parseFeed: No se encontraron items en el feed. Avanzando al siguiente.");
                hasValidContent = false;
                advanceToNextFeed();
            }
        } catch (e) {
            console.error("❌ Error crítico parseando feed " + feedUrl + ":", e);
            advanceToNextFeed();
        }
    }

    function setupNewsModel(items, feedUrl, faviconUrl) {
        if (_debugMode) console.log(`[CHIVATO] setupNewsModel: Iniciando con ${items.length} items.`);
        currentFaviconUrl = faviconUrl;
        emptyStateMessage = ""; // Limpiamos el mensaje de error si hemos tenido éxito
        failedFeedAttempts = 0;
        allFeedsFailed = false;
        retryFailedFeedsTimer.stop();
        retryFailedFeedsTimer.stop();
        retryCount = 0; // Reinicia el contador de reintentos en un éxito
        newsModel = items;
        isBusy = false;
        
        if (_debugMode) console.log("[CHIVATO] setupNewsModel: Modelo actualizado. Verificando si la UI está lista...");
        if (liveUi) {
            if (_debugMode) console.log("[CHIVATO] setupNewsModel: La UI ya estaba lista. Llamando a updateNewsModel.");
            updateNewsModel();
        } else {
            if (_debugMode) console.log("[CHIVATO] setupNewsModel: La UI aún no está lista. Esperando a que la UI avise.");
        }
    }

    function updateNewsModel() {
        if (_debugMode) console.log("[CHIVATO] updateNewsModel: Verificando si la UI existe.");
        feedStartTime = new Date().getTime(); // Actualizamos la hora de inicio aquí
        watchdogTimer.stop(); // Detiene el temporizador de vigilancia, la transición fue exitosa
        if (liveUi) {
            if (_debugMode) console.log("[CHIVATO] updateNewsModel: La UI existe. Usando la referencia 'liveUi' para llamar a updateNewsRow y startScrolling.");
            liveUi.updateNewsRow();
            liveUi.startScrolling();
            if (_debugMode) console.log("⏰ [CHIVATO] Dando la orden de iniciar feedChangeTimer...");
            feedChangeTimer.start(); // ¡REACTIVAR EL CICLO!
            preloadNextFeed(); // Iniciar la precarga DESPUÉS de que el ticker actual esté en marcha
        } else {
            console.error("[CRÍTICO] updateNewsModel: Se intentó actualizar, pero la UI (representationItem) es NULA.");
        }
    }

    function resetAndInitialize(isRetry = false) {
        if (_debugMode) console.log("🚀 Ejecutando inicialización completa...");
        
        // Forzamos el reset de banderas críticas
        isBusy = true;
        
        // Limpieza segura de la UI viva
        if (liveUi) {
            try {
                // Intentamos detener cualquier animación en curso si es posible
                if (typeof liveUi.stopAnimations === 'function') {
                    liveUi.stopAnimations();
                }
            } catch (e) {
                console.warn("Error al intentar detener liveUi:", e);
            }
            // No ponemos liveUi a null aquí, porque la referencia puede seguir siendo válida para el motor QML.
            // Simplemente asumimos que vamos a reconstruir el estado.
        }

        root.faviconOpacity = 0;
        root.currentFaviconUrl = "image://icon/applications-internet";
        currentFeedIndex = 0;
        feedTimestamps = ({});
        isInitialized = false;
        allFeedsFailed = false;
        failedFeedAttempts = 0;
        preloadedData = null;
        retryFailedFeedsTimer.stop();
        if (!isRetry) {
            retryCount = 0;
        }
        transitionTimer.stop();
        feedChangeTimer.stop();
        watchdogTimer.stop(); // Aseguramos que el watchdog no salte durante el reset

        newsModel = [];
        
        // Toma una "fotografía" de la configuración actual para compararla más tarde.
        lastAppliedFeedList = plasmoid.configuration.feedList ? JSON.parse(JSON.stringify(plasmoid.configuration.feedList)) : [];
        if (_debugMode) console.log("📸 'Fotografía' de la lista de feeds tomada:", JSON.stringify(lastAppliedFeedList));

        const feeds = plasmoid.configuration.feedList;
        if (feeds && feeds.length > 0 && feeds.some(feed => feed && feed.trim() !== '')) {
            if (_debugMode) console.log("✅ Feeds encontrados. Iniciando carga del primer feed.");
            isInitialized = true;
            // Damos un pequeño respiro antes de cargar para dejar que el loop de eventos procese
            Qt.callLater(loadCurrentFeed);
        } else {
            allFeedsFailed = true;
            emptyStateMessage = i18n("No feeds configured. Please add feeds in the settings.");
            console.warn("No hay feeds válidos configurados para mostrar.");
            isBusy = false;
        }
    }

    function scheduleRetry() {
        let newInterval;
        switch (retryCount) {
            case 0: newInterval = 5000; break;     // 5 segundos (primer intento)
            case 1: newInterval = 10000; break;    // 10 segundos
            case 2: newInterval = 15000; break;    // 15 segundos
            case 3: newInterval = 60000; break;    // 1 minuto
            default: newInterval = 60000; break;   // 1 minuto (intentos posteriores)
        }
        retryCount++;
        retryFailedFeedsTimer.interval = newInterval;
        retryFailedFeedsTimer.start();
        if (_debugMode) console.log(`🔌 Todos los feeds han fallado. Reintentando en ${newInterval / 1000} segundos.`);
    }

    // --- Temporizadores ---
    Timer {
        id: transitionTimer
        interval: 300 // Tiempo para la animación de fade-out
        repeat: false
        onTriggered: { if (_debugMode) console.log("⏱️ [CHIVATO] ¡transitionTimer disparado! Llamando a completeFeedTransition()."); completeFeedTransition(); }
    }
    Timer {
        id: feedChangeTimer
        interval: plasmoid.configuration.updateInterval * 60 * 1000
        repeat: false
        onTriggered: { if (_debugMode) console.log("💥 [CHIVATO] ¡feedChangeTimer disparado! Llamando a startFeedTransition()."); startFeedTransition(); }
    }
    Timer { id: retryFailedFeedsTimer; repeat: false; onTriggered: resetAndInitialize(true) }
    Timer {
        id: watchdogTimer
        interval: 30000 // Aumentamos a 30 segundos para dar más margen en redes lentas
        repeat: false
        onTriggered: {
            console.warn("🐶 [WATCHDOG] La transición del feed no se completó a tiempo. Forzando reinicio completo.");
            // Solo reiniciamos si realmente estamos bloqueados (isBusy es true)
            if (isBusy) {
                resetAndInitialize(true);
            }
        }
    }

    // --- Elementos de la Interfaz ---

    Component {
        id: tickerUiComponent

        Item {
            id: componentApi
            
            // API Pública del Componente
            function stopScrolling() { container.stopScrolling(); }
            function startScrolling() { container.startScrolling(); }
            function updateNewsRow() { container.updateNewsRow(); }
            function stopAnimations() { container.stopAnimations(); }
            function startTransitionAnimations(opacity) { container.startTransitionAnimations(opacity); }

            // Contenido Visual
            Rectangle {
                id: container; anchors.fill: parent; clip: true; color: "transparent"

                // Implementación de la API (funciones internas)
                function stopScrolling() { scrollAnimation.stop(); }
                function startScrolling() { if (_debugMode) console.log("[CHIVATO] tickerUiComponent: Arrancando scrollAnimation."); scrollAnimation.start(); }
                function updateNewsRow() {
                    newsRow.x = newsContainer.width;
                    startTransitionAnimations(1.0);
                }
                function stopAnimations() {
                    faviconOpacityAnimation.stop();
                    newsOpacityAnimation.stop();
                }
                function startTransitionAnimations(targetOpacity) {
                    faviconOpacityAnimation.to = targetOpacity;
                    faviconOpacityAnimation.start();
                    newsOpacityAnimation.to = targetOpacity;
                    newsOpacityAnimation.start();
                }

                // Elementos Visuales
                Item {
                    id: faviconContainer; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    height: root.height; width: root.optimalFaviconSize; visible: root.showIcons; opacity: root.faviconOpacity
                    Rectangle {
                        id: faviconClip; anchors.fill: parent; color: "transparent"; clip: true
                        Image {
                            id: faviconImage; anchors.centerIn: parent; height: root.optimalFaviconSize; width: root.optimalFaviconSize
                            source: root.currentFaviconUrl; fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(root.optimalFaviconSize, root.optimalFaviconSize); cache: false
                        }
                    }
                    NumberAnimation { id: faviconOpacityAnimation; target: faviconContainer; property: "opacity"; duration: 300; easing.type: Easing.InOutQuad }
                }
                Rectangle {
                    id: newsContainer; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                    anchors.left: root.showIcons ? faviconContainer.right : parent.left
                    anchors.leftMargin: root.showIcons ? Kirigami.Units.smallSpacing : 0
                    color: "transparent"; clip: true; opacity: faviconContainer.opacity
                    MouseArea {
                        id: newsMouseArea; anchors.fill: parent; hoverEnabled: root.showTooltips

                        onWheel: (wheel) => {
                            var delta = wheel.angleDelta.y / 120 * 40;
                            newsRow.x += delta;
                        }

                        onPositionChanged: {
                            let foundIndex = -1;
                            for (let i = 0; i < newsRepeater.count; i++) {
                                const itemDelegate = newsRepeater.itemAt(i);
                                if (itemDelegate && itemDelegate.visible && itemDelegate.contains(itemDelegate.mapFromItem(newsMouseArea, mouseX, mouseY))) {
                                    foundIndex = i;
                                    break;
                                }
                            }

                            if (foundIndex !== -1) {
                                const itemData = root.newsModel[foundIndex];
                                const mainText = Utils.truncateTitleForTooltip(itemData.title);
                                const subText = Utils.formatDescriptionForTooltip(itemData.summary);
                                
                                root.toolTipMainText = mainText;
                                root.toolTipSubText = subText;
                                root.currentScrollSpeed = root.slowScrollSpeed;
                            } else {
                                root.toolTipMainText = "";
                                root.toolTipSubText = "";
                                root.currentScrollSpeed = root.scrollSpeed;
                            }
                        }

                        onExited: {
//                          root.toolTipMainText = "";
//                          root.toolTipSubText = "";
                            root.currentScrollSpeed = root.scrollSpeed;
                        }
                    }
                    Row {
                        id: newsRow; height: parent.height; x: newsContainer.width
                        property real totalWidth: {
                            var width = 0;
                            for (var i = 0; i < children.length; i++) width += children[i].width + spacing;
                            return width;
                        }
                        Repeater {
                            id: newsRepeater; model: root.newsModel
                            delegate: Item {
                                required property var modelData; id: newsItem; height: parent.height; width: contentRow.width
                                visible: modelData && modelData.title && modelData.title.length > 0
                                Row {
                                    id: contentRow; height: parent.height; spacing: Kirigami.Units.smallSpacing
                                    PlasmaComponents.Label {
                                        id: titleText; text: modelData.title || ""; color: root.textColor
                                        font { pointSize: root.fontSize; family: root.fontFamily; bold: modelData.isNew && !root.blinkNewItems }
                                        verticalAlignment: Text.AlignVCenter; height: parent.height; visible: text.length > 0
                                    }
                                    RowLayout {
                                        id: separatorContainer; height: parent.height; visible: !modelData.isLast

                                        PlasmaComponents.Label {
                                            text: root.newsSeparator
                                            color: root.textColor
                                            font {
                                                pointSize: root.fontSize
                                                family: '"Noto Sans", "sans-serif"'
                                                bold: root.newsSeparatorBold
                                            }
                                            opacity: 0.7
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.leftMargin: root.newsSeparatorMargin
                                            Layout.rightMargin: root.newsSeparatorMargin
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (modelData.link) Qt.openUrlExternally(modelData.link) }
                                }
                            }
                        }
                    }
                    NumberAnimation { id: newsOpacityAnimation; target: newsContainer; property: "opacity"; duration: 300; from: 0; to: 1; easing.type: Easing.InOutQuad }
                    FrameAnimation {
                        id: scrollAnimation; running: false
                        onTriggered: {
                            if (!newsRow || newsRow.totalWidth <= 0) return;
                            // frameTime is in seconds
                            var pixelsToMove = root.currentScrollSpeed * frameTime;
                            var endOfScroll = newsRow.x + newsRow.totalWidth < -50;
                            var minTimeElapsed = (new Date().getTime() - feedStartTime >= minDisplayTime);

                            if (endOfScroll && !isBusy && hasValidContent && minTimeElapsed) {
                                if (_debugMode) console.log(`🏁 [CHIVATO] Fin de scroll detectado. Llamando a startFeedTransition().`);
                                startFeedTransition();
                            } else {
                                // Chivato de diagnóstico para cuando el scroll termina pero la transición está bloqueada
                                if (endOfScroll) {
                                    // Usamos un temporizador para no inundar el log
                                    if (!scrollDebugTimer.running) scrollDebugTimer.start();
                                }
                                newsRow.x -= pixelsToMove;
                            }
                        }
                    }
                }
                PlasmaComponents.Label {
                    anchors.centerIn: parent; visible: root.allFeedsFailed
                    text: root.emptyStateMessage
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    color: Kirigami.Theme.negativeTextColor; font.pointSize: root.fontSize; font.family: root.fontFamily
                }
            }
            
            Timer {
                id: scrollDebugTimer; interval: 2000; running: false; repeat: false
                onTriggered: if (_debugMode) console.log(`⏳ [CHIVATO] Fin de scroll alcanzado, pero la transición está bloqueada. Estado: isBusy=${isBusy}, hasValidContent=${hasValidContent}, minTimeElapsed=${(new Date().getTime() - feedStartTime >= minDisplayTime)}`);
            }

            Component.onCompleted: {
                if (_debugMode) console.log("✅ ¡La UI ha sido construida! Avisando al PlasmoidItem.");
                // Emitimos la señal con una referencia a nuestra API
                root.uiReady(componentApi);
            }
        }
    }

    // --- Conexiones y Arranque ---

    // Conexión a nuestra propia señal. Esto se dispara cuando la UI emite uiReady().
    onUiReady: (uiObject) => {
        if (_debugMode) console.log("🤝 Apretón de manos recibido. Guardando referencia a la UI.");
        liveUi = uiObject;
        // Comprobamos si los datos habían llegado antes que la UI
        if (newsModel.length > 0) {
            if (_debugMode) console.log("[CHIVATO] onUiReady: Los datos ya estaban listos. Llamando a updateNewsModel.");
            updateNewsModel();
        }
    }

    Connections {
        target: plasmoid

        // Se dispara cuando el diálogo de configuración se abre/cierra
        function onUserConfiguringChanged() {
            // Nos interesa solo cuando se cierra (userConfiguring -> false)
            if (!plasmoid.userConfiguring) {
                if (_debugMode) console.log("👋 El diálogo de configuración se ha cerrado.");
                const currentFeedsJSON = JSON.stringify(plasmoid.configuration.feedList || []);
                const lastAppliedFeedsJSON = JSON.stringify(lastAppliedFeedList);

                if (_debugMode) console.log("   [CHIVATO] Lista actual:", currentFeedsJSON);
                if (_debugMode) console.log("   [CHIVATO] Última lista aplicada:", lastAppliedFeedsJSON);

                if (currentFeedsJSON !== lastAppliedFeedsJSON) {
                    if (_debugMode) console.log("✅ La lista de feeds ha cambiado. Reiniciando para aplicar cambios.");
                    resetAndInitialize(false);
                } else {
                    if (_debugMode) console.log("❌ No se detectaron cambios en la lista de feeds. No se requiere reinicio.");
                }
            }
        }
    }

    Connections {
        target: plasmoid.configuration
        
        function onScrollSpeedChanged() {
            if (!newsMouseArea.containsMouse) currentScrollSpeed = plasmoid.configuration.scrollSpeed
        }
        function onShowTooltipsChanged() {
            if (!plasmoid.configuration.showTooltips) {
                root.toolTipMainText = "";
                root.toolTipSubText = "";
            }
        }
    }

    Component.onCompleted: {
        if (_debugMode) console.log("Plasmoid cargado. Programando primer intento de inicialización.");
        resetAndInitialize(false);
    }
}
