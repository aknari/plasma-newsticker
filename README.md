# plasma-newsticker

Plasma 6 plasmoid that provides a scrolling RSS news ticker with advanced features.

## Features

- **RSS Feed Support**: Display headlines from multiple RSS feeds with intelligent parsing
- **OPML Import/Export**: Full support for OPML file format with robust error handling
- **Smart Icon Loading**: Automatically finds and displays feed icons with multiple fallback sources
- **Panel Integration**: Configurable panel spacer behavior for seamless desktop integration
- **Mouse Wheel Navigation**: Smooth scrolling with customizable sensitivity and edge spacing
- **Internationalization**: Support for some writing systems (Latin, Cyrillic, etc.)
- **Universal Character Support**: Handles all Unicode characters including special typographic marks
- **Multi-Language Typography**: Proper display of language-specific quotation marks and punctuation
- **Automatic Script Detection**: Identifies and validates different writing systems automatically
- **Unicode Normalization**: Handles encoding issues and normalizes text automatically
- **Comprehensive Entity Decoding**: Supports all HTML5 entities and numeric character references
- **Configurable Appearance**: Colors, fonts, scroll speed, and more
- **Comprehensive Debugging**: Detailed logging for troubleshooting any issues

## Installation & Usage

Just change into the directory of the downloaded bundle and perform the following commands:

```bash
kpackagetool6 -t Plasma/Applet -u .
# If you wish to refresh the plasmoids...
plasmashell --replace
```
## Configuration

### Feed Management
- Add/remove individual RSS feeds
- Configure scroll speed and appearance
- Enable/disable feed icons

The operations of exporting and importing OPML files are not implemented due to QML and Plasma 6 restrictions.
