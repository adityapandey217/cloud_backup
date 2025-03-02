import 'package:flutter/material.dart';
import 'package:cloud_backup/services/secure_storage_service.dart';
import 'package:cloud_backup/services/minio_service.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _accessKeyController = TextEditingController();
  final TextEditingController _secretKeyController = TextEditingController();
  final TextEditingController _bucketNameController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _folderNameController = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    setState(() {
      _isLoading = true;
    });

    _accessKeyController.text = await SecureStorageService.getAccessKey() ?? '';
    _secretKeyController.text = await SecureStorageService.getSecretKey() ?? '';
    _bucketNameController.text =
        await SecureStorageService.getBucketName() ?? '';
    _regionController.text = await SecureStorageService.getRegion() ?? '';
    _folderNameController.text =
        await SecureStorageService.getFolderName() ?? 'cloud_backup';

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveCredentials({bool showMessage = true}) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await SecureStorageService.setAccessKey(_accessKeyController.text);
      await SecureStorageService.setSecretKey(_secretKeyController.text);
      await SecureStorageService.setBucketName(_bucketNameController.text);
      await SecureStorageService.setRegion(_regionController.text);
      await SecureStorageService.setFolderName(_folderNameController.text);

      setState(() {
        _isLoading = false;
      });

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credentials saved successfully')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isTesting = true;
      });

      // Save the credentials first
      await _saveCredentials(showMessage: false);

      // Test the connection
      final minioService = MinioService();
      final success = await minioService.testConnection();

      setState(() {
        _isTesting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Connection successful!'
                  : 'Failed to connect. Please check your credentials.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Setup'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      'DigitalOcean Spaces Credentials',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _accessKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Access Key',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your access key';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _secretKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Secret Key',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your secret key';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bucketNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bucket Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your bucket name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _regionController,
                      decoration: const InputDecoration(
                        labelText: 'Region',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., nyc3',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your region';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _folderNameController,
                      decoration: const InputDecoration(
                        labelText: 'Folder Name',
                        border: OutlineInputBorder(),
                        hintText: 'Default: cloud_backup',
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveCredentials,
                            child: const Text('Save Credentials'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isTesting ? null : _testConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                            ),
                            child: _isTesting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text('Test Connection'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Clear Credentials'),
                            content: const Text(
                                'Are you sure you want to clear all saved credentials?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await SecureStorageService.clearAll();
                          _loadCredentials();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Credentials cleared')),
                            );
                          }
                        }
                      },
                      child: const Text('Clear Credentials'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _bucketNameController.dispose();
    _regionController.dispose();
    _folderNameController.dispose();
    super.dispose();
  }
}
