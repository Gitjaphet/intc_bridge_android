package com.intc.intc_bridge

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.print.PrintAttributes
import android.print.PrinterCapabilitiesInfo
import android.print.PrinterId
import android.print.PrinterInfo
import android.printservice.PrintJob
import android.printservice.PrintService
import android.printservice.PrinterDiscoverySession
import android.util.Log
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import java.io.DataOutputStream
import java.util.UUID

class IntcPrintService : PrintService() {

    companion object {
        private const val TAG = "IntcPrintService"
        private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")
        private const val PAPER_58MM_PX = 384
        private const val PAPER_80MM_PX = 576
        const val PRINTER_LOCAL_ID = "intc_thermal_printer"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onConnected() {
        Log.i(TAG, "PrintService connecté")
    }

    override fun onDisconnected() {
        Log.i(TAG, "PrintService déconnecté")
    }

    override fun onCreatePrinterDiscoverySession(): PrinterDiscoverySession {
        return IntcPrinterDiscoverySession(this)
    }

    override fun onPrintJobQueued(printJob: PrintJob) {
        val pfd: ParcelFileDescriptor? = printJob.document?.data

        if (pfd == null) {
            printJob.fail("Document vide")
            return
        }

        printJob.start()
        Log.i(TAG, "Job démarré, envoi Bluetooth SPP")


        Thread {
            var tempFile: java.io.File? = null
            var seekablePfd: ParcelFileDescriptor? = null
            try {
                tempFile = java.io.File.createTempFile("print_job", ".pdf", cacheDir)
                java.io.FileInputStream(pfd.fileDescriptor).use { input ->
                    tempFile!!.outputStream().use { output -> input.copyTo(output) }
                }
                seekablePfd = ParcelFileDescriptor.open(tempFile, ParcelFileDescriptor.MODE_READ_ONLY)

                val paperWidthPx = getPaperWidthPx()
                val escBytes = pdfToEscPos(seekablePfd, paperWidthPx)
                Log.i(TAG, "ESC/POS généré : ${escBytes.size} bytes")
                sendToLocalServer(escBytes)
                Log.i(TAG, "Envoi réussi")
                mainHandler.post { printJob.complete() }
            } catch (e: Exception) {
                Log.e(TAG, "Échec impression : ${e.javaClass.simpleName} — ${e.message}")
                mainHandler.post { printJob.fail("Erreur : ${e.message}") }
            } finally {
                try { pfd.close() } catch (_: Exception) {}
                try { seekablePfd?.close() } catch (_: Exception) {}
                tempFile?.delete()
            }
        }.start()
    }

    override fun onRequestCancelPrintJob(printJob: PrintJob) {
        printJob.cancel()
    }

    private fun pdfToEscPos(pfd: ParcelFileDescriptor, paperWidthPx: Int): ByteArray {
        val renderer = PdfRenderer(pfd)
        val output = ByteArrayOutputStream()

        for (i in 0 until renderer.pageCount) {
            val page = renderer.openPage(i)
            val scale  = paperWidthPx.toFloat() / page.width.toFloat()
            val height = (page.height * scale).toInt()

            val bitmap = Bitmap.createBitmap(paperWidthPx, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            page.close()

            // DEBUG: sauvegarder le bitmap
            val debugFile = java.io.File(cacheDir, "debug_page_$i.png")
            java.io.FileOutputStream(debugFile).use { bitmap.compress(Bitmap.CompressFormat.PNG, 90, it) }
            Log.d(TAG, "DEBUG bitmap sauvegardé: ${debugFile.absolutePath} (${bitmap.width}x${bitmap.height})")
            val cropped = cropWhitespace(bitmap)
            Log.d(TAG, "Bitmap cropé: ${bitmap.width}x${bitmap.height} -> ${cropped.width}x${cropped.height}")
            output.write(bitmapToEscPos(cropped))
            if (cropped != bitmap) cropped.recycle()
            bitmap.recycle()

            if (i < renderer.pageCount - 1) output.write(byteArrayOf(0x0A, 0x0A))
        }

        renderer.close()
        // Init + feed + cut
        val init = byteArrayOf(0x1B, 0x40)          // ESC @ init
        val feed = byteArrayOf(0x1B, 0x64, 0x05)    // ESC d - avance 5 lignes
        val cut  = byteArrayOf(0x1D, 0x56, 0x42, 0x00) // GS V B - coupe
        val result = ByteArrayOutputStream()
        result.write(init)
        result.write(output.toByteArray())
        result.write(feed)
        result.write(cut)
        return result.toByteArray()
    }

    private fun bitmapToEscPos(bitmap: Bitmap): ByteArray {
        val width       = bitmap.width
        val height      = bitmap.height
        val bytesPerRow = (width + 7) / 8
        val imageData   = ByteArray(bytesPerRow * height)

        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        for (y in 0 until height) {
            val rowOffset = y * width
            for (b in 0 until bytesPerRow) {
                var byte = 0
                for (bit in 0..7) {
                    val x = b * 8 + bit
                    if (x < width) {
                        val pixel = pixels[rowOffset + x]
                        val alpha = (pixel ushr 24) and 0xFF
                        val r = if (alpha == 0) 255 else (pixel ushr 16) and 0xFF
                        val g = if (alpha == 0) 255 else (pixel ushr 8) and 0xFF
                        val b2 = if (alpha == 0) 255 else pixel and 0xFF
                        val lum = 0.299 * r + 0.587 * g + 0.114 * b2
                        if (lum < 128) byte = byte or (0x80 ushr bit)
                    }
                }
                imageData[y * bytesPerRow + b] = byte.toByte()
            }
        }

        val out = ByteArrayOutputStream()
        out.write(0x1D); out.write(0x76); out.write(0x30); out.write(0x00)
        out.write(bytesPerRow and 0xFF)
        out.write((bytesPerRow shr 8) and 0xFF)
        out.write(height and 0xFF)
        out.write((height shr 8) and 0xFF)
        out.write(imageData)
        return out.toByteArray()
    }

    private fun sendToLocalServer(data: ByteArray) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val json  = prefs.getString("flutter.printer_config", null)
            ?: throw Exception("Configuration imprimante absente")
        val config = JSONObject(json)
        val connectionType = config.optString("connectionType", "bluetooth")

        if (connectionType == "wifi") {
            val ip = config.optString("wifiIp", "")
            val port = config.optInt("wifiPort", 9100)
            if (ip.isBlank()) throw Exception("IP WiFi non configurée")

            Log.d(TAG, "Connexion WiFi à $ip:$port")
            java.net.Socket().use { socket ->
                socket.connect(java.net.InetSocketAddress(ip, port), 5000)
                socket.getOutputStream().write(data)
                socket.getOutputStream().flush()
            }
            Log.i(TAG, "Envoi WiFi terminé")
        } else {
            val address = config.optString("bluetoothAddress", "")
            if (address.isBlank()) throw Exception("Adresse Bluetooth non configurée")

            Log.d(TAG, "Connexion Bluetooth SPP à $address")
            val adapter = BluetoothAdapter.getDefaultAdapter()
                ?: throw Exception("Bluetooth non disponible")
            val device = adapter.getRemoteDevice(address)
            val socket: BluetoothSocket = device.createRfcommSocketToServiceRecord(SPP_UUID)
            adapter.cancelDiscovery()
            socket.connect()
            Log.d(TAG, "Connecté à $address, envoi ${data.size} bytes")
            socket.outputStream.write(data)
            socket.outputStream.flush()
            Thread.sleep(3000)
            socket.close()
            Log.i(TAG, "Envoi Bluetooth terminé")
        }
    }

    private fun cropWhitespace(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        fun rowHasInk(y: Int): Boolean {
            val rowOffset = y * width
            for (x in 0 until width) {
                val p = pixels[rowOffset + x]
                val r = (p ushr 16) and 0xFF
                val g = (p ushr 8) and 0xFF
                val b = p and 0xFF
                val lum = 0.299 * r + 0.587 * g + 0.114 * b
                if (lum < 240) return true
            }
            return false
        }

        var firstNonWhite = 0
        for (y in 0 until height) { if (rowHasInk(y)) { firstNonWhite = y; break } }
        var lastNonWhite = height - 1
        for (y in height - 1 downTo 0) { if (rowHasInk(y)) { lastNonWhite = y; break } }
        if (firstNonWhite >= lastNonWhite) return bitmap

        val top = maxOf(firstNonWhite - 10, 0)
        val bottom = minOf(lastNonWhite + 20, height - 1)
        return Bitmap.createBitmap(bitmap, 0, top, width, bottom - top + 1)
    }

    private fun getPaperWidthPx(): Int = try {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val json  = prefs.getString("flutter.printer_config", null)
        if (json != null && JSONObject(json).optString("paperSize") == "mm58")
            PAPER_58MM_PX else PAPER_80MM_PX
    } catch (_: Exception) { PAPER_80MM_PX }
}
