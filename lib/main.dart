import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TarifaFacilApp());

class TarifaFacilApp extends StatelessWidget {
  const TarifaFacilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tarifa Fácil',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Position? _start;
  Position? _last;
  StreamSubscription<Position>? _gps;
  double _distance = 0;
  double _rate = 2.50;
  double _minimum = 7.00;
  bool _running = false;
  String _startAddress = 'Não definido';
  String _endAddress = 'Aguardando final da corrida';

  double get total {
    if (_distance <= 0) return 0;
    return _minimum > (_distance * _rate) ? _minimum : _distance * _rate;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _rate = p.getDouble('rate') ?? 2.50;
      _minimum = p.getDouble('minimum') ?? 7.00;
    });
  }

  Future<bool> _ensureGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack('Ative o GPS/localização do celular.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _snack('Permissão de localização não concedida.');
      return false;
    }
    return true;
  }

  Future<void> _startTrip() async {
    if (!await _ensureGps()) return;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    await _gps?.cancel();
    setState(() {
      _start = pos;
      _last = pos;
      _distance = 0;
      _startAddress =
          '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      _endAddress = 'Corrida em andamento';
      _running = true;
    });

    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (_last != null) {
        final delta = Geolocator.distanceBetween(
          _last!.latitude, _last!.longitude, pos.latitude, pos.longitude,
        );
        if (delta >= 2 && delta < 500) _distance += delta / 1000;
      }
      setState(() => _last = pos);
    });
  }

  Future<void> _finishTrip() async {
    if (!_running) return;
    await _gps?.cancel();
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      _last = pos;
      _endAddress =
          '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      _running = false;
    });
  }

  Future<void> _settings() async {
    final rate = TextEditingController(text: _rate.toStringAsFixed(2));
    final minimum = TextEditingController(text: _minimum.toStringAsFixed(2));
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Configurações'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor por km (R\$)',
                prefixText: 'R\$ ',
              ),
            ),
            TextField(
              controller: minimum,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor mínimo da corrida (R\$)',
                prefixText: 'R\$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final r = double.tryParse(rate.text.replaceAll(',', '.'));
              final m = double.tryParse(minimum.text.replaceAll(',', '.'));
              if (r == null || m == null || r < 0 || m < 0) return;
              final p = await SharedPreferences.getInstance();
              await p.setDouble('rate', r);
              await p.setDouble('minimum', m);
              setState(() { _rate = r; _minimum = m; });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _snack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final money = total.toStringAsFixed(2).replaceAll('.', ',');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarifa Fácil'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _settings, icon: const Icon(Icons.settings)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('VALOR DA CORRIDA',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('R\$ $money',
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('${_distance.toStringAsFixed(2)} km percorridos',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _infoCard(Icons.trip_origin, 'Ponto de partida', _startAddress),
          _infoCard(Icons.flag, 'Ponto final', _endAddress),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? null : _startTrip,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('INICIAR'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _running ? _finishTrip : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('FINALIZAR'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.route),
              title: const Text('Tarifa configurada'),
              subtitle: Text(
                'R\$ ${_rate.toStringAsFixed(2)}/km • mínimo R\$ ${_minimum.toStringAsFixed(2)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _settings,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _running
                ? 'GPS ativo • distância sendo atualizada automaticamente'
                : 'Pressione INICIAR para começar a medir a corrida.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }
}
