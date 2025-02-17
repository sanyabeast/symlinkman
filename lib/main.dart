import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(SymlinkManagerApp());
}

class SymlinkManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Symlink Manager',
      theme: ThemeData.dark(),
      home: SymlinkManagerScreen(),
    );
  }
}

class SymlinkManagerScreen extends StatefulWidget {
  @override
  _SymlinkManagerScreenState createState() => _SymlinkManagerScreenState();
}

class _SymlinkManagerScreenState extends State<SymlinkManagerScreen> {
  List<Map<String, dynamic>> symlinks = [];

  @override
  void initState() {
    super.initState();
    _loadSymlinks();
  }

  Future<void> _loadSymlinks() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/symlinks.json');
    if (file.existsSync()) {
      final jsonData = jsonDecode(await file.readAsString());
      setState(() {
        symlinks = List<Map<String, dynamic>>.from(jsonData);
      });
    }
  }

  Future<void> _saveSymlinks() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/symlinks.json');
    await file.writeAsString(jsonEncode(symlinks));
  }

  void _pickSource(bool isFolder) async {
    String? source;
    if (isFolder) {
      source = await FilePicker.platform.getDirectoryPath();
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        source = result.files.single.path;
      }
    }

    if (source != null) {
      setState(() {
        symlinks.add({
          'source': source!,
          'links': [],
          'type': isFolder ? 'folder' : 'file',
        });
        _saveSymlinks();
      });
    }
  }

  void _createSymlink(String source, int index) async {
    TextEditingController nameController =
        TextEditingController(text: source.split(Platform.pathSeparator).last);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Target Name'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: 'Target Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String? target = await FilePicker.platform.getDirectoryPath();
                if (target != null) {
                  String symlinkPath = '$target\\${nameController.text}';
                  try {
                    ProcessResult result;
                    if (symlinks[index]['type'] == 'folder') {
                      result = await Process.run(
                          'cmd', ['/c', 'mklink', '/D', symlinkPath, source]);
                    } else {
                      result = await Process.run(
                          'cmd', ['/c', 'mklink', symlinkPath, source]);
                    }

                    if (result.exitCode == 0) {
                      setState(() {
                        symlinks[index]['links'].add(symlinkPath);
                        _saveSymlinks();
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Failed to create symlink: ${result.stderr}')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error executing symlink command: $e')),
                    );
                  }
                }
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _deleteSymlink(String path, int index) {
    try {
      if (Directory(path).existsSync()) {
        Process.runSync('cmd', ['/c', 'rmdir', path]);
      } else if (File(path).existsSync()) {
        File(path).deleteSync();
      }

      setState(() {
        symlinks[index]['links'].remove(path);
        _saveSymlinks();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete symlink: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Symlink Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showAppInfo,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: symlinks.length,
        itemBuilder: (context, index) {
          var item = symlinks[index];
          return Card(
            child: ExpansionTile(
              leading: Icon(item['type'] == 'folder'
                  ? Icons.folder
                  : Icons.insert_drive_file),
              title: Text(item['source']),
              children: [
                ElevatedButton(
                  onPressed: () => _createSymlink(item['source'], index),
                  child: Text('Create Symlink'),
                ),
                Column(
                  children: item['links']
                      .map<Widget>((link) => ListTile(
                            title: Text(link),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSymlink(link, index),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _pickSource(false),
            child: Icon(Icons.insert_drive_file),
            tooltip: 'Add File Symlink',
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => _pickSource(true),
            child: Icon(Icons.folder),
            tooltip: 'Add Folder Symlink',
          ),
        ],
      ),
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('About Symlink Manager'),
          content: Text(
              'Version: 1.0.0\nDeveloped by: @sanyabeast\nManage and create symlinks for files and folders.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
