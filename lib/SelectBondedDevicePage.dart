import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import './BluetoothDeviceListEntry.dart';

class SelectBondedDevicePage extends StatefulWidget {
  /// If true, on page start there is performed discovery upon the bonded devices.
  /// Then, if they are not avaliable, they would be disabled from the selection.
  final bool checkAvailability;

  const SelectBondedDevicePage({this.checkAvailability = true});

  @override
  _SelectBondedDevicePage createState() => new _SelectBondedDevicePage();
}

enum _DeviceAvailability {
  maybe,
  yes,
}

class _DeviceWithAvailability extends BluetoothDevice {
  BluetoothDevice device;
  _DeviceAvailability availability;
  int? rssi;

  _DeviceWithAvailability(this.device, this.availability) : super(
    address: device.address,
    name: device.name,
    type: device.type,
    bondState: device.bondState,
    isConnected: device.isConnected
  );
}

class _SelectBondedDevicePage extends State<SelectBondedDevicePage> {
  List<_DeviceWithAvailability> devices = <_DeviceWithAvailability>[];

  // 將 _discoveryStreamSubscription 改為可空類型
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;
  bool _isDiscovering = false;

  _SelectBondedDevicePage();

  @override
  void initState() {
    super.initState();

    requestPermissions().then((_) {
      _isDiscovering = widget.checkAvailability;

      if (_isDiscovering) {
        _startDiscovery();
      }

      // Setup a list of the bonded devices
      FlutterBluetoothSerial.instance
          .getBondedDevices()
          .then((List<BluetoothDevice> bondedDevices) {
        setState(() {
          devices = bondedDevices
              .map(
                (device) => _DeviceWithAvailability(
                  device,
                  widget.checkAvailability
                      ? _DeviceAvailability.maybe
                      : _DeviceAvailability.yes,
                ),
              )
              .toList();
        });
      });
    });
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.bluetooth.status.isDenied) {
        await Permission.bluetooth.request();
      }
      if (await Permission.bluetoothConnect.status.isDenied) {
        await Permission.bluetoothConnect.request();
      }
      if (await Permission.bluetoothScan.status.isDenied) {
        await Permission.bluetoothScan.request();
      }
      if (await Permission.location.status.isDenied) {
        await Permission.location.request();
      }
    }
  }

  void _startDiscovery() {
    _discoveryStreamSubscription?.cancel(); // 取消現有的訂閱（如果有的話）
    
    _discoveryStreamSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        Iterator i = devices.iterator;
        while (i.moveNext()) {
          var _device = i.current;
          if (_device.device == r.device) {
            _device.availability = _DeviceAvailability.yes;
            _device.rssi = r.rssi;
          }
        }
      });
    });

    _discoveryStreamSubscription?.onDone(() {
      setState(() {
        _isDiscovering = false;
      });
    });
  }

  void _restartDiscovery() {
    setState(() {
      _isDiscovering = true;
    });

    _startDiscovery();
  }

  @override
  void dispose() {
    // 安全地取消訂閱
    _discoveryStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<BluetoothDeviceListEntry> list = devices
        .map((_device) => BluetoothDeviceListEntry(
              device: _device.device,
              rssi: _device.rssi ?? 0,
              enabled: _device.availability == _DeviceAvailability.yes,
              onTap: () {
                Navigator.of(context).pop(_device.device);
              },
              onLongPress: () {},
            ))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Select device'),
        actions: <Widget>[
          _isDiscovering
              ? FittedBox(
                  child: Container(
                    margin: new EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.replay),
                  onPressed: _restartDiscovery,
                )
        ],
      ),
      body: ListView(children: list),
    );
  }
}
