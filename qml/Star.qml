import QtQuick

// Favori yıldızı (yazı tipine bağlı kalmamak için çizilir)
Canvas {
    id: c
    property color color: theme.accent
    implicitWidth: 14
    implicitHeight: 14
    onColorChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var cx = width / 2, cy = height / 2, R = Math.min(width, height) / 2, r = R * 0.45
        ctx.beginPath()
        for (var i = 0; i < 10; i++) {
            var rad = (i % 2 === 0) ? R : r
            var a = -Math.PI / 2 + i * Math.PI / 5
            ctx.lineTo(cx + rad * Math.cos(a), cy + rad * Math.sin(a))
        }
        ctx.closePath()
        ctx.fillStyle = c.color
        ctx.fill()
    }
}
