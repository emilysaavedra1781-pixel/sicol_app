import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_upload_service.dart';

class ImagePickerWidget extends StatefulWidget {
  final String? initialUrl;
  final String storagePath;
  final String label;
  final Function(String) onImagenSubida;

  const ImagePickerWidget({
    super.key,
    this.initialUrl,
    required this.storagePath,
    required this.label,
    required this.onImagenSubida,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final _uploadService = ImageUploadService();
  String? _currentUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
  }

  Future<void> _handleImageSelection(bool desdeCamara) async {
    Navigator.pop(context);
    final File? selectedFile = await _uploadService.seleccionarImagen(desdeCamara: desdeCamara);
    
    if (selectedFile != null) {
      setState(() => _loading = true);
      final String? url = await _uploadService.subirImagen(selectedFile, widget.storagePath);
      
      if (url != null) {
        setState(() {
          _currentUrl = url;
          _loading = false;
        });
        widget.onImagenSubida(url);
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la imagen'), backgroundColor: Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF6B21F5)),
              title: const Text('Tomar Foto'),
              onTap: () => _handleImageSelection(true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF6B21F5)),
              title: const Text('Elegir de Galería'),
              onTap: () => _handleImageSelection(false),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _loading ? null : _showPickerOptions,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B21F5)))
                : _currentUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(_currentUrl!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: Color(0xFF6B21F5), size: 32),
                          SizedBox(height: 8),
                          Text('Toca para subir', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}
