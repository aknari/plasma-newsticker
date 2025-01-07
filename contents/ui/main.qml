import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support

PlasmoidItem {
    id: root
    
    Plasmoid.backgroundHints: plasmoid.configuration.transparentBackground ? "NoBackground" : "StandardBackground"
    
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
    property var previousTitles: ({})  // Mantener para compatibilidad
    property var feedTimestamps: ({})  // Nuevo: almacena los timestamps por feed y título
    property string pendingFaviconUrl: ""
    property var faviconCandidates: []
    property int currentFaviconCandidate: 0
    property var newsModel: []
    property bool isLastTitleOfFeed: false
    property bool isTransitioning: false
    property int transitionDelay: 3000  // ms antes de cambiar al siguiente feed
    property real lastTitlePosition: 0
    property bool isScrolling: false
    property var nextFeedData: []
    property real scrollPos: 0
    property real faviconOpacity: 1.0
    property bool faviconReady: false
    property var pendingNewsModel: null
    property bool isFaviconLoading: false

    // Temporizador de seguridad para inicialización
    Timer {
        id: safetyInitTimer
        interval: 10000  // 10 segundos
        repeat: false
        onTriggered: {
            initializeFeedsWithDelay()
        }
    }

    // Nueva función para inicialización diferida
    function initializeFeedsWithDelay() {
        var initTimer = Qt.createQmlObject(`
            import QtQuick
            Timer {
                interval: 5000  // Retraso de 5 segundos
                repeat: false
                onTriggered: {
                    loadFeeds();
                    destroy();
                }
            }
        `, root);
        
        initTimer.start();
    }

    // Función para cargar un feed con reintentos
    function loadFeedWithRetry(feedUrl, maxRetries = 2, timeout = 10000, onSuccess, onFailure) {
        var retries = maxRetries;
        
        function attemptLoad() {
            console.log(`Attempting to load feed: ${feedUrl}, ${retries} attempts left`);
            
            var xhr = new XMLHttpRequest();
            var timeoutTimer = Qt.createQmlObject(`
                import QtQuick
                Timer {
                    interval: ${timeout}
                    repeat: false
                    onTriggered: {
                        xhr.abort();
                        handleLoadFailure();
                    }
                }
            `, root);
            
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    timeoutTimer.stop();
                    timeoutTimer.destroy();
                    
                    if (xhr.status === 200) {
                        try {
                            var parsedItems = parseFeedItems(xhr.responseText, feedUrl);
                            onSuccess(parsedItems);
                        } catch (parseError) {
                            console.error(`Error parsing feed ${feedUrl}:`, parseError);
                            handleLoadFailure();
                        }
                    } else {
                        handleLoadFailure();
                    }
                }
            }

            xhr.onerror = function() {
                timeoutTimer.stop();
                timeoutTimer.destroy();
                handleLoadFailure();
            }

            function handleLoadFailure() {
                if (retries > 0) {
                    retries--;
                    // Esperar un poco antes de reintentar
                    Qt.setTimeout(attemptLoad, 3000);
                } else {
                    console.error(`Feed ${feedUrl} failed after ${maxRetries} attempts`);
                    onFailure(new Error(`Could not load feed: ${feedUrl}`));
                }
            }

            xhr.open("GET", feedUrl);
            xhr.send();
            timeoutTimer.start();
        }

        attemptLoad();
    }

    // Función para cargar todos los feeds
    function loadFeeds() {
        // Filtrar feeds válidos
        var validFeeds = feedList.filter(feed => feed && feed.trim() !== '');
        var successfulFeeds = [];
        var failedFeeds = [];

        function processNextFeed(index) {
            if (index >= validFeeds.length) {
                // Todos los feeds procesados
                if (successfulFeeds.length > 0) {
                    // Combinar items de feeds cargados exitosamente
                    var combinedItems = successfulFeeds.reduce((acc, feedItems) => 
                        acc.concat(feedItems), []);
                    
                    newsModel = combinedItems;
                    
                    // Actualizar favicon
                    if (validFeeds.length > 0) {
                        try {
                            var urlObj = new URL(validFeeds[0]);
                            currentFeedBaseUrl = urlObj.origin;
                            currentFaviconUrl = getFaviconUrl(validFeeds[0]);
                        } catch (e) {
                            console.error("Error setting favicon:", e);
                        }
                    }
                } else {
                    // No se pudo cargar ningún feed
                    newsModel = [];
                    currentFaviconUrl = "image://icon/applications-internet";
                }
                return;
            }

            var feedUrl = validFeeds[index];
            loadFeedWithRetry(
                feedUrl, 
                2, 
                10000,
                // Éxito
                function(parsedItems) {
                    console.log(`Feed ${feedUrl} loaded successfully`);
                    successfulFeeds.push(parsedItems);
                    processNextFeed(index + 1);
                },
                // Fallo
                function(error) {
                    console.error(`Feed ${feedUrl} failed to load:`, error);
                    failedFeeds.push(feedUrl);
                    processNextFeed(index + 1);
                }
            );
        }

        // Comenzar con el primer feed
        processNextFeed(0);
    }

    // Función para parsear items de feed de manera más segura
    function parseFeedItems(xml, feedUrl) {
        var itemRegex = /<item>[\s\S]*?<\/item>/g;
        var titleRegex = /<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/title>/;
        var linkRegex = /<link>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/link>/;
        var pubDateRegex = /<pubDate>(.*?)<\/pubDate>/;
        
        var items = xml.match(itemRegex) || [];
        var newItems = [];
        
        for (var i = 0; i < Math.min(items.length, maxItems); i++) {
            var item = items[i];
            var titleMatch = item.match(titleRegex);
            var linkMatch = item.match(linkRegex);
            var pubDateMatch = item.match(pubDateRegex);
            
            if (titleMatch && titleMatch[1]) {
                var title = titleMatch[1].trim();
                var link = (linkMatch && linkMatch[1]) ? linkMatch[1].trim() : "";
                var pubDate = (pubDateMatch && pubDateMatch[1]) ? new Date(pubDateMatch[1]).getTime() : new Date().getTime();
                
                var isNew = false;
                if (!feedTimestamps[feedUrl]) {
                    feedTimestamps[feedUrl] = {};
                    isNew = true;
                } else if (!feedTimestamps[feedUrl][title] || pubDate > feedTimestamps[feedUrl][title]) {
                    isNew = true;
                }
                
                feedTimestamps[feedUrl] = feedTimestamps[feedUrl] || {};
                feedTimestamps[feedUrl][title] = pubDate;
                
                newItems.push({
                    title: title,
                    link: link,
                    isNew: isNew,
                    isLast: false
                });
            }
        }
        
        if (newItems.length > 0) {
            newItems[newItems.length - 1].isLast = true;
        }
        
        return newItems;
    }

    ListModel {
        id: nextFeedModel
    }

    Timer {
        id: transitionTimer
        interval: 300
        repeat: false
        onTriggered: completeFeedTransition()
    }

    Component.onCompleted: {
        // Añadir un temporizador de inicialización segura
        var initializationTimer = Qt.createQmlObject(`
            import QtQuick
            Timer {
                id: safeInitTimer
                interval: 10000  // 10 segundos de espera inicial
                repeat: false
                
                function initializeFeeds() {
                    // Verificar si hay feeds configurados
                    if (feedList && feedList.length > 0) {
                        var loadAttempts = 0;
                        var maxLoadAttempts = 2;  // Máximo 2 intentos
                        
                        function attemptFeedLoad() {
                            loadAttempts++;
                            
                            // Resetear estado de inicialización
                            isInitialized = true;
                            currentFeedIndex = 0;
                            feedTimestamps = ({});
                            newsModel = [];
                            isTransitioning = false;
                            
                            try {
                                // Intentar cargar feed actual
                                loadCurrentFeed();
                                
                                // Si tiene éxito, detener reintentos
                                console.log("Feeds loaded successfully on attempt " + loadAttempts);
                            } catch (error) {
                                console.log("Feed load attempt " + loadAttempts + " failed: " + error);
                                
                                // Reintentar si no se ha alcanzado el máximo
                                if (loadAttempts < maxLoadAttempts) {
                                    // Esperar 3 segundos antes del siguiente intento
                                    Qt.setTimeout(attemptFeedLoad, 3000);
                                } else {
                                    console.log("Max feed load attempts reached");
                                    // Resetear a estado inicial si falla
                                    isInitialized = false;
                                    currentFeedIndex = -1;
                                    newsModel = [];
                                    currentFaviconUrl = "image://icon/applications-internet";
                                }
                            }
                        }
                        
                        // Iniciar primer intento
                        attemptFeedLoad();
                    } else {
                        // Sin feeds configurados
                        isInitialized = false;
                        currentFeedIndex = -1;
                        newsModel = [];
                        currentFaviconUrl = "image://icon/applications-internet";
                    }
                }
                
                onTriggered: {
                    initializeFeeds();
                    destroy();
                }
            }
        `, root);
        
        initializationTimer.start();
    }

    function loadCurrentFeed() {
        if (!feedList || feedList.length === 0) {
            return
        }

        var feedUrl = feedList[currentFeedIndex]
        if (!feedUrl || feedUrl.length === 0) {
            advanceToNextFeed()
            return
        }

        loadFeed(feedUrl)
    }

    function advanceToNextFeed() {
        if (isTransitioning) {
            return
        }
        
        currentFeedIndex = (currentFeedIndex + 1) % feedList.length
        loadCurrentFeed()
    }

    function updateAllFeeds() {
        if (feedList && feedList.length > 0) {
            currentFeedIndex = -1
            loadNextFeed()
        }
    }

    function loadNextFeed() {
        if (!feedList || feedList.length === 0) {
            return
        }

        if (currentFeedIndex >= feedList.length) {
            currentFeedIndex = 0
        }

        var feedUrl = feedList[currentFeedIndex]
        
        var currentTime = new Date().toISOString()
        
        var urlObj = new URL(feedUrl);
        currentFeedBaseUrl = urlObj.origin;
        
        if (feedUrl && feedUrl.length > 0) {
            loadFeed(feedUrl)
        } else {
            currentFeedIndex++
            loadNextFeed()
        }
    }

    function loadFeed(feedUrl) {
        nextFeedModel.clear();
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    parseFeed(xhr.responseText, feedUrl);
                } else {
                    isTransitioning = false;
                    advanceToNextFeed();
                }
            }
        }
        xhr.onerror = function() {
            isTransitioning = false;
            advanceToNextFeed();
        }
        xhr.open("GET", feedUrl);
        xhr.send();
    }

    function parseFeed(xml, feedUrl) {
        try {
            var itemRegex = /<item>[\s\S]*?<\/item>/g;
            var titleRegex = /<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/title>/;
            var linkRegex = /<link>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/link>/;
            var pubDateRegex = /<pubDate>(.*?)<\/pubDate>/;
            
            var items = xml.match(itemRegex) || [];
            var newItems = [];
            
            for (var i = 0; i < Math.min(items.length, maxItems); i++) {
                var item = items[i];
                var titleMatch = item.match(titleRegex);
                var linkMatch = item.match(linkRegex);
                var pubDateMatch = item.match(pubDateRegex);
                
                if (titleMatch && titleMatch[1]) {
                    var title = titleMatch[1].trim();
                    var link = (linkMatch && linkMatch[1]) ? linkMatch[1].trim() : "";
                    var pubDate = (pubDateMatch && pubDateMatch[1]) ? new Date(pubDateMatch[1]).getTime() : new Date().getTime();
                    
                    var isNew = false;
                    if (!feedTimestamps[feedUrl]) {
                        feedTimestamps[feedUrl] = {};
                        isNew = true;
                    } else if (!feedTimestamps[feedUrl][title] || pubDate > feedTimestamps[feedUrl][title]) {
                        isNew = true;
                    }
                    
                    feedTimestamps[feedUrl] = feedTimestamps[feedUrl] || {};
                    feedTimestamps[feedUrl][title] = pubDate;
                    
                    newItems.push({
                        title: title,
                        link: link,
                        isNew: isNew,
                        isLast: false
                    });
                }
            }
            
            if (newItems.length > 0) {
                newItems[newItems.length - 1].isLast = true;
                
                try {
                    var urlObj = new URL(feedUrl);
                    currentFeedBaseUrl = urlObj.origin;
                    currentFaviconUrl = getFaviconUrl(feedUrl);
                    newsModel = newItems;
                    newsRow.x = newsContainer.width;
                    
                    faviconOpacityAnimation.to = 1;
                    faviconOpacityAnimation.start();
                    newsOpacityAnimation.to = 1;
                    newsOpacityAnimation.start();
                    
                    isTransitioning = false;
                } catch (e) {
                    currentFeedBaseUrl = "";
                    currentFaviconUrl = "";
                    newsModel = newItems;
                    newsRow.x = newsContainer.width;
                    isTransitioning = false;
                }
            } else {
                isTransitioning = false;
                advanceToNextFeed();
            }
        } catch (e) {
            isTransitioning = false;
            advanceToNextFeed();
        }
    }

    function getFaviconUrl(feedUrl) {
        try {
            var domain = feedUrl.replace(/^https?:\/\//, '').split('/')[0]
            var candidates = [
                "https://logo.clearbit.com/" + domain + "?size=32",
                "https://www.google.com/s2/favicons?domain=" + domain + "&sz=32"
            ]
            
            if (domain === "www.canarias7.es") {
                return candidates[1]
            }
            
            return candidates[0]
        } catch (e) {
            return ""
        }
    }

    function startFeedTransition() {
        if (isTransitioning) {
            return
        }
        
        isTransitioning = true;
        
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
            loadFeed(feedUrl);
        } else {
            isTransitioning = false;
        }
    }

    function updateNewsModel() {
        if (pendingNewsModel && (faviconReady || !isFaviconLoading)) {
            newsModel = pendingNewsModel
            pendingNewsModel = null
            newsRow.x = newsContainer.width  // Reset position
            faviconOpacityAnimation.to = 1.0
            faviconOpacityAnimation.start()
            newsOpacityAnimation.start()
        }
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

            Image {
                id: faviconImage
                anchors.centerIn: parent
                height: Math.min(parent.height, 32)
                width: height
                source: root.currentFaviconUrl
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(32, 32)
                cache: false
                
                onStatusChanged: {
                    if (status === Image.Ready || status === Image.Error) {
                        faviconReady = true
                        isFaviconLoading = false
                        updateNewsModel()
                    }
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
            anchors.leftMargin: root.fontSize
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
                    // Calcular el desplazamiento máximo permitido
                    var maxLeftMove = newsContainer.width - newsRow.totalWidth;
                    var maxRightMove = 0;

                    // Desplazamiento proporcional
                    var delta = wheel.angleDelta.y / 120 * 20;
                    
                    // Nuevo valor de x, limitado
                    var newX = newsRow.x + delta;
                    
                    // Restringir el movimiento
                    newX = Math.min(Math.max(newX, maxLeftMove), maxRightMove);
                    
                    newsRow.x = newX;
                }
            }

            Row {
                id: newsRow
                height: parent.height
                x: newsContainer.width  // Start from the right edge

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
                            spacing: root.fontSize

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

                            PlasmaComponents.Label {
                                id: separatorText
                                text: modelData.isLast ? "" : "\u2002\u2022\u2004\u2003"  // En Space + En Space + Bullet + Em Space
                                color: root.textColor
                                font {
                                    pointSize: root.fontSize
                                    family: root.fontFamily
                                }
                                opacity: 0.7
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                                visible: !modelData.isLast
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.link) {
                                    Qt.openUrlExternally(modelData.link)
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
                    if (newsRow.x + newsRow.totalWidth < 0) {
                        if (!isTransitioning) {
                            startFeedTransition()
                        }
                    } else {
                        newsRow.x -= pixelsPerFrame
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