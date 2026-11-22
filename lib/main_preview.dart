import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/pos_provider.dart';
import 'providers/printer_provider.dart';
import 'screens/pos/pos_main_screen.dart';

void main() async {
  DevicePreview.enable();
  await DevicePreview.maybeController?.applyPreset(DevicePresets.galaxyS24);
  runApp(const PosPreviewApp());
}

class PosPreviewApp extends StatelessWidget {
  const PosPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => PosProvider()..loadMockPreviewData()),
      ],
      child: MaterialApp(
        title: '${AppConfig.appName} POS Live Preview',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: AppConfig.primaryTeal,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConfig.primaryTeal,
            primary: AppConfig.primaryTeal,
            secondary: AppConfig.accent,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          fontFamily: 'Roboto',
        ),
        home: const PreviewWrapperScreen(),
      ),
    );
  }
}

/// Pembungkus layar POS dengan Floating Quick-Switcher Toolbar
/// untuk berpindah device, rotasi layar, dan simulasi keyboard langsung dari browser.
class PreviewWrapperScreen extends StatefulWidget {
  const PreviewWrapperScreen({super.key});

  @override
  State<PreviewWrapperScreen> createState() => _PreviewWrapperScreenState();
}

class _PreviewWrapperScreenState extends State<PreviewWrapperScreen> {
  bool _keyboardRaised = false;
  bool _isLandscape = false;
  String _activeDevice = 'Galaxy S24';

  Future<void> _switchDevice(String name, DevicePreset preset) async {
    final controller = DevicePreview.maybeController;
    if (controller == null) return;
    await controller.applyPreset(
      preset,
      orientation: _isLandscape ? Orientation.landscape : Orientation.portrait,
    );
    setState(() {
      _activeDevice = name;
    });
  }

  Future<void> _toggleOrientation() async {
    final controller = DevicePreview.maybeController;
    if (controller == null) return;
    final nextLandscape = !_isLandscape;
    await controller.setOrientation(
      nextLandscape ? Orientation.landscape : Orientation.portrait,
    );
    setState(() {
      _isLandscape = nextLandscape;
    });
  }

  Future<void> _toggleKeyboard() async {
    final controller = DevicePreview.maybeController;
    if (controller == null) return;
    final next = !_keyboardRaised;
    await controller.update((s) {
      return s.copyWith(keyboardInset: next ? 320.0 : null);
    });
    setState(() {
      _keyboardRaised = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layar POS Kasir Utama
        const PosMainScreen(),

        // Floating Vibe Coding Control Pill (draggable / pinned di kanan atas)
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF1E293B).withValues(alpha: 0.92),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Pilih Device',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.devices, size: 14, color: Colors.cyanAccent),
                          const SizedBox(width: 4),
                          Text(
                            _activeDevice,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white70),
                        ],
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'phone') {
                        _switchDevice('Galaxy S24', DevicePresets.galaxyS24);
                      } else if (val == 'pixel') {
                        _switchDevice('Pixel 9', DevicePresets.pixel9);
                      } else if (val == 'iphone') {
                        _switchDevice('iPhone 16', DevicePresets.iPhone16);
                      } else if (val == 'tablet_s10') {
                        _switchDevice('Tab S10+', DevicePresets.galaxyTabS10Plus);
                      } else if (val == 'ipad') {
                        _switchDevice('iPad Air', DevicePresets.iPadAir11M2);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'phone',
                        child: Text('📱 Samsung Galaxy S24 (HP)'),
                      ),
                      const PopupMenuItem(
                        value: 'pixel',
                        child: Text('📱 Google Pixel 9 (HP)'),
                      ),
                      const PopupMenuItem(
                        value: 'iphone',
                        child: Text('🍏 iPhone 16 (HP)'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'tablet_s10',
                        child: Text('💻 Galaxy Tab S10+ (Tablet POS)'),
                      ),
                      const PopupMenuItem(
                        value: 'ipad',
                        child: Text('💻 iPad Air 11" (Tablet POS)'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  // Tombol Putar Landscape / Portrait
                  IconButton(
                    icon: Icon(
                      _isLandscape ? Icons.screen_lock_landscape : Icons.screen_lock_portrait,
                      size: 16,
                      color: _isLandscape ? Colors.amberAccent : Colors.white70,
                    ),
                    tooltip: 'Putar Layar (${_isLandscape ? "Landscape" : "Portrait"})',
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    onPressed: _toggleOrientation,
                  ),
                  const SizedBox(width: 2),
                  // Tombol Simulasi Keyboard Muncul
                  IconButton(
                    icon: Icon(
                      Icons.keyboard,
                      size: 16,
                      color: _keyboardRaised ? Colors.amberAccent : Colors.white70,
                    ),
                    tooltip: _keyboardRaised ? 'Tutup Keyboard Virtual' : 'Buka Keyboard Virtual',
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    onPressed: _toggleKeyboard,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
