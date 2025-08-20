import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Web Timer', home: const TimerPage());
  }
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});
  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final player = AudioPlayer();
  Timer? _timer;
  Timer? _countdownTimer;

  int _minutes = 1;
  bool _repeat = false;
  bool _running = false;
  Duration _remaining = Duration.zero;

  final _msgCtrl = TextEditingController();
  String _reminderMessage = "Time’s up!";
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minutes = prefs.getInt("minutes") ?? 1;
      _repeat = prefs.getBool("repeat") ?? false;
      _reminderMessage = prefs.getString("reminderMessage") ?? "Time’s up!";
      _volume = prefs.getDouble("volume") ?? 1.0;
      _msgCtrl.text = _reminderMessage;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("minutes", _minutes);
    await prefs.setBool("repeat", _repeat);
    await prefs.setString("reminderMessage", _reminderMessage);
    await prefs.setDouble("volume", _volume);
  }

  Future<void> _resetPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _minutes = 1;
      _repeat = false;
      _reminderMessage = "Time’s up!";
      _volume = 1.0;
      _msgCtrl.text = _reminderMessage;
    });
  }

  void _startTimer() {
    if (_running) return;
    setState(() {
      _running = true;
      _remaining = Duration(minutes: _minutes);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining.inSeconds > 0) {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });

    _timer = Timer.periodic(Duration(minutes: _minutes), (t) async {
      if (!_repeat) {
        t.cancel();
        _countdownTimer?.cancel();
        setState(() => _running = false);
      } else {
        setState(() => _remaining = Duration(minutes: _minutes));
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            title: const Text("Reminder"),
            content: Text(_reminderMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      }

      await player.setVolume(_volume);
      await player.play(AssetSource("doorbell.mp3"));
    });

    _savePrefs();
  }

  void _stopTimer() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _running = false;
      _remaining = Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    player.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Custom Web Timer")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                const Text("Interval: "),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _minutes,
                  onChanged: (val) {
                    setState(() => _minutes = val ?? 1);
                    _savePrefs();
                  },
                  items: [1, 2, 5, 10, 15, 30, 60]
                      .map(
                        (m) =>
                            DropdownMenuItem(value: m, child: Text("$m min")),
                      )
                      .toList(),
                ),
              ],
            ),
            Row(
              children: [
                const Text("Repeat: "),
                Switch(
                  value: _repeat,
                  onChanged: (v) {
                    setState(() => _repeat = v);
                    _savePrefs();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _msgCtrl,
              decoration: const InputDecoration(
                labelText: "Reminder Message",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                _reminderMessage = val;
                _savePrefs();
              },
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    label: (_volume * 100).round().toString(),
                    onChanged: (val) {
                      setState(() => _volume = val);
                      _savePrefs();
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
              ],
            ),

            const SizedBox(height: 20),

            _running
                ? Column(
                    children: [
                      Text(
                        "Remaining: ${_formatDuration(_remaining)}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _stopTimer,
                        icon: const Icon(Icons.stop),
                        label: const Text("Stop"),
                      ),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: _startTimer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Start"),
                  ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _resetPrefs,
              icon: const Icon(Icons.restore),
              label: const Text("Reset to Default"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
