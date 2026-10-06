package com.intc.intc_bridge

import android.print.PrintAttributes
import android.print.PrinterCapabilitiesInfo
import android.print.PrinterId
import android.print.PrinterInfo
import android.printservice.PrintService
import android.printservice.PrinterDiscoverySession
import android.util.Log
import org.json.JSONObject

class IntcPrinterDiscoverySession(
    private val printService: PrintService
) : PrinterDiscoverySession() {

    companion object {
        private const val TAG = "IntcDiscoverySession"
    }

    override fun onStartPrinterDiscovery(priorityList: List<PrinterId>) {
        Log.d(TAG, "Démarrage découverte")
        addOrUpdatePrinters()
    }

    override fun onStopPrinterDiscovery() {
        Log.d(TAG, "Arrêt découverte")
    }

    override fun onValidatePrinters(printerIds: List<PrinterId>) {
        addOrUpdatePrinters()
    }

    override fun onStartPrinterStateTracking(printerId: PrinterId) {
        addOrUpdatePrinters()
    }

    override fun onStopPrinterStateTracking(printerId: PrinterId) {}

    override fun onDestroy() {
        Log.d(TAG, "Destruction session")
    }

    private fun addOrUpdatePrinters() {
        val printerId = printService.generatePrinterId(IntcPrintService.PRINTER_LOCAL_ID)

        val capabilities = PrinterCapabilitiesInfo.Builder(printerId)
            .addMediaSize(
                PrintAttributes.MediaSize("thermal_58mm", "Thermique 58mm", 2244, 78740),
                false
            )
            .addMediaSize(
                PrintAttributes.MediaSize("thermal_80mm", "Thermique 80mm", 3150, 78740),
                true
            )
            .addResolution(
                PrintAttributes.Resolution("203dpi", "203 dpi", 203, 203),
                true
            )
            .setColorModes(
                PrintAttributes.COLOR_MODE_MONOCHROME,
                PrintAttributes.COLOR_MODE_MONOCHROME
            )
            .setDuplexModes(
                PrintAttributes.DUPLEX_MODE_NONE,
                PrintAttributes.DUPLEX_MODE_NONE
            )
            .build()

        val printerInfo = PrinterInfo.Builder(
            printerId,
            buildPrinterName(),
            PrinterInfo.STATUS_IDLE
        )
            .setCapabilities(capabilities)
            .build()

        Log.d(TAG, "Publication : ${buildPrinterName()}")
        addPrinters(listOf(printerInfo))
    }

    private fun buildPrinterName(): String = try {
        val prefs = printService.getSharedPreferences(
            "FlutterSharedPreferences",
            android.content.Context.MODE_PRIVATE
        )
        val json = prefs.getString("flutter.printer_config", null)
        if (json != null) {
            val obj        = JSONObject(json)
            val deviceName = obj.optString("deviceName", "").trim()
            val paperSize  = obj.optString("paperSize", "mm80")
            val label      = if (paperSize == "mm58") "58mm" else "80mm"
            if (deviceName.isNotEmpty()) "INTC Bridge — $deviceName ($label)"
            else "INTC Bridge ($label)"
        } else "INTC Bridge"
    } catch (_: Exception) { "INTC Bridge" }
}
