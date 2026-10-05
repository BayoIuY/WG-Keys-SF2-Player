package com.wgkeys.sf2player

import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiManager
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver
import android.os.Bundle
import dev.kotlinds.fluidsynth.AudioConfig
import dev.kotlinds.fluidsynth.FluidSynthPlayer
import dev.kotlinds.fluidsynth.Interpolation
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channelName = "wgkeys/sf2"
    private var synth: FluidSynthPlayer? = null
    private var midiManager: MidiManager? = null
    private var midiDevice: MidiDevice? = null
    private var midiOutput: MidiOutputPort? = null
    private var midiReceiver: MidiReceiver? = null
    private var flutterChannel: MethodChannel? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        synth = FluidSynthPlayer(
            AudioConfig(
                sampleRate = 48000,
                interpolation = Interpolation.HIGH,
                periodSize = 64,
                periods = 2,
            )
        )

        flutterChannel = MethodChannel(engine.dartExecutor.binaryMessenger, channelName)
        flutterChannel!!.setMethodCallHandler { call, result ->
            try {
                val s = synth
                when (call.method) {
                    "load" -> {
                        val path = call.argument<String>("path")
                            ?: throw IllegalArgumentException("Caminho do SF2 vazio")
                        val id = s?.loadSoundFont(path) ?: -1
                        if (id < 0) throw IllegalStateException("SF2 inválido ou não pôde ser carregado")
                        s.programChange(0, 0)
                        result.success(id)
                    }
                    "noteOn" -> {
                        s?.noteOn(0, call.argument<Int>("key") ?: 60, call.argument<Int>("velocity") ?: 100)
                        result.success(null)
                    }
                    "noteOff" -> {
                        s?.noteOff(0, call.argument<Int>("key") ?: 60)
                        result.success(null)
                    }
                    "program" -> {
                        s?.programChange(0, call.argument<Int>("program") ?: 0)
                        result.success(null)
                    }
                    "gain" -> {
                        s?.setGain((call.argument<Double>("value") ?: 0.8).toFloat())
                        result.success(null)
                    }
                    "reverb" -> {
                        s?.setReverb(0.6, 0.5, 0.5, call.argument<Double>("level") ?: 0.0)
                        result.success(null)
                    }
                    "chorus" -> {
                        s?.setChorus(3, call.argument<Double>("level") ?: 0.0, 0.3, 8.0)
                        result.success(null)
                    }
                    "sustain" -> {
                        // fluidsynth-kmp 1.1.1 exposes note/program/effect APIs, but not CC directly.
                        // We therefore emulate sustain at the app layer by delaying note-off events.
                        result.success(null)
                    }
                    "allNotesOff" -> {
                        for (key in 0..127) s?.noteOff(0, key)
                        result.success(null)
                    }
                    "midiStart" -> {
                        startMidi()
                        result.success(null)
                    }
                    "close" -> {
                        closeMidi()
                        s?.close()
                        synth = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("SF2_ERROR", e.message ?: "Erro desconhecido", null)
            }
        }
    }

    private fun startMidi() {
        closeMidi()
        midiManager = getSystemService(MIDI_SERVICE) as? MidiManager
        val manager = midiManager
        if (manager == null) {
            flutterChannel?.invokeMethod("midiStatus", "MIDI: indisponível")
            return
        }

        val infos = manager.devices
        if (infos.isEmpty()) {
            flutterChannel?.invokeMethod("midiStatus", "MIDI: nenhum dispositivo")
            return
        }

        val info = infos.firstOrNull { it.outputPortCount > 0 }
        if (info == null) {
            flutterChannel?.invokeMethod("midiStatus", "MIDI: sem saída MIDI")
            return
        }

        manager.openDevice(info, { device ->
            midiDevice = device
            val output = device.openOutputPort(0)
            if (output == null) {
                flutterChannel?.invokeMethod("midiStatus", "MIDI: não foi possível abrir a saída")
                return@openDevice
            }

            midiOutput = output
            val receiver = object : MidiReceiver() {
                @Throws(IOException::class)
                override fun onSend(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
                    parseMidi(msg, offset, count)
                }
            }
            midiReceiver = receiver
            output.connect(receiver)

            val name = info.properties[MidiDeviceInfo.PROPERTY_NAME] ?: "dispositivo MIDI"
            flutterChannel?.invokeMethod("midiStatus", "MIDI: $name")
        }, null)
    }

    private fun parseMidi(data: ByteArray, off: Int, count: Int) {
        var i = off
        val end = off + count
        while (i < end) {
            val status = data[i].toInt() and 0xFF
            if (status < 0x80) {
                i++
                continue
            }
            val type = status and 0xF0
            val chan = status and 0x0F
            val messageSize = if (type == 0xC0 || type == 0xD0) 2 else 3
            if (i + messageSize > end) break

            val data1 = data[i + 1].toInt() and 0x7F
            val data2 = if (messageSize == 3) data[i + 2].toInt() and 0x7F else 0
            val s = synth

            when (type) {
                0x80 -> s?.noteOff(chan, data1)
                0x90 -> if (data2 == 0) s?.noteOff(chan, data1) else s?.noteOn(chan, data1, data2)
                0xC0 -> s?.programChange(chan, data1)
            }
            i += messageSize
        }
    }

    private fun closeMidi() {
        try {
            val output = midiOutput
            val receiver = midiReceiver
            if (output != null && receiver != null) output.disconnect(receiver)
            output?.close()
            midiDevice?.close()
        } catch (_: Exception) {
        } finally {
            midiOutput = null
            midiReceiver = null
            midiDevice = null
        }
    }

    override fun onDestroy() {
        closeMidi()
        synth?.close()
        synth = null
        super.onDestroy()
    }
}
