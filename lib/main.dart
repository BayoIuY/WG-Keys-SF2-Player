import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

void main() => runApp(const WGKeysApp());

class WGKeysApp extends StatelessWidget {
  const WGKeysApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF080808),
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.orange,
            brightness: Brightness.dark,
          ),
        ),
        home: const Player(),
      );
}

class Player extends StatefulWidget {
  const Player({super.key});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  static const ch = MethodChannel('wgkeys/sf2');

  String sf = 'Nenhum SF2 carregado';
  String midi = 'MIDI: não conectado';
  bool loaded = false;
  bool sustain = false;
  int octave = 4;
  int program = 0;
  int velocity = 105;
  double gain = .8;
  double reverb = .25;
  double chorus = 0;
  final Set<int> down = <int>{};

  final whites = <String>['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'A', 'B'];
  final semis = <int>[0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23];
  final blacks = <int>[1, 3, 6, 8, 10, 13, 15, 18, 20, 22];

  @override
  void initState() {
    super.initState();
    ch.setMethodCallHandler((call) async {
      if (call.method == 'midiStatus' && mounted) {
        setState(() => midi = call.arguments?.toString() ?? 'MIDI: conectado');
      }
    });
    ch.invokeMethod('midiStart').catchError((_) {});
  }

  @override
  void dispose() {
    ch.invokeMethod('close').catchError((_) {});
    super.dispose();
  }

  Future<void> load() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['sf2'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null || path.isEmpty) return;

    try {
      await ch.invokeMethod('load', {'path': path});
      if (!mounted) return;
      setState(() {
        sf = result.files.single.name;
        loaded = true;
      });
      await settings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar o SF2: $e')),
      );
    }
  }

  Future<void> noteOn(int n) async {
    final key = (octave + 1) * 12 + n;
    setState(() => down.add(n));
    if (loaded) {
      await ch.invokeMethod('noteOn', {'key': key, 'velocity': velocity});
    }
  }

  Future<void> noteOff(int n) async {
    final key = (octave + 1) * 12 + n;
    setState(() => down.remove(n));
    if (loaded && !sustain) {
      await ch.invokeMethod('noteOff', {'key': key});
    }
  }

  Future<void> settings() async {
    if (!loaded) return;
    await ch.invokeMethod('gain', {'value': gain});
    await ch.invokeMethod('reverb', {'level': reverb});
    await ch.invokeMethod('chorus', {'level': chorus});
    await ch.invokeMethod('program', {'program': program});
  }

  Widget slider(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> fn,
  ) =>
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(title), Text(value.toStringAsFixed(2))],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) {
              fn(v);
              settings();
            },
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'WG KEYS • SF2 PLAYER',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: const Color(0xFF111111),
          actions: [IconButton(onPressed: load, icon: const Icon(Icons.folder_open))],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sf,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: loaded ? Colors.orange : Colors.white54,
                        ),
                      ),
                    ),
                    Icon(
                      loaded ? Icons.check_circle : Icons.music_note,
                      color: loaded ? Colors.greenAccent : Colors.white38,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.folder_open),
                    label: Text(loaded ? 'TROCAR SF2' : 'ABRIR SF2'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: program,
                        decoration: const InputDecoration(labelText: 'Preset GM (0–127)'),
                        items: [
                          for (int i = 0; i < 128; i++)
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) {
                          setState(() => program = v ?? 0);
                          settings();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: octave,
                        decoration: const InputDecoration(labelText: 'Oitava'),
                        items: [
                          for (int i = 0; i <= 8; i++)
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) => setState(() => octave = v ?? 4),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    slider('Volume', gain, 0, 1, (v) => setState(() => gain = v)),
                    slider('Reverb', reverb, 0, 1, (v) => setState(() => reverb = v)),
                    slider('Chorus', chorus, 0, 2, (v) => setState(() => chorus = v)),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Velocity'),
                  SizedBox(
                    width: 150,
                    child: Slider(
                      value: velocity.toDouble(),
                      min: 1,
                      max: 127,
                      onChanged: (v) => setState(() => velocity = v.round()),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Sustain'),
                    selected: sustain,
                    onSelected: (v) async {
                      setState(() => sustain = v);
                      await ch.invokeMethod('sustain', {'on': v});
                      if (!v) await ch.invokeMethod('allNotesOff');
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    midi,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 205,
                child: LayoutBuilder(
                  builder: (ctx, c) {
                    final w = c.maxWidth / whites.length;
                    return Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < whites.length; i++)
                              Expanded(
                                child: GestureDetector(
                                  onTapDown: (_) => noteOn(semis[i]),
                                  onTapUp: (_) => noteOff(semis[i]),
                                  onTapCancel: () => noteOff(semis[i]),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 35),
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: down.contains(semis[i]) ? Colors.orange : Colors.white,
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                                    ),
                                    alignment: Alignment.bottomCenter,
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(whites[i], style: const TextStyle(color: Colors.black)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        for (int i = 0; i < whites.length; i++)
                          if (i < semis.length && blacks.contains(semis[i]))
                            Positioned(
                              left: (i + .64) * w,
                              width: w * .58,
                              height: 120,
                              top: 0,
                              child: GestureDetector(
                                onTapDown: (_) => noteOn(semis[i]),
                                onTapUp: (_) => noteOff(semis[i]),
                                onTapCancel: () => noteOff(semis[i]),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 35),
                                  decoration: BoxDecoration(
                                    color: down.contains(semis[i]) ? Colors.orange : Colors.black,
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'WG Keys • SF2 Player • Android',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );
}
