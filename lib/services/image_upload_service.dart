import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageUploadService {
  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance;
  final _db = FirebaseFirestore.instance;

  Future<File?> seleccionarImagen({bool desdeCamara = false}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: desdeCamara ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      print('Error al seleccionar imagen: $e');
    }
    return null;
  }

  Future<File?> comprimirImagen(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(tempDir.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result != null) {
        return File(result.path);
      }
    } catch (e) {
      print('Error al comprimir imagen: $e');
    }
    return file;
  }

  Future<String?> subirImagen(File file, String rutaStorage) async {
    try {
      final compressedFile = await comprimirImagen(file);
      final ref = _storage.ref().child(rutaStorage);
      final uploadTask = await ref.putFile(compressedFile ?? file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error al subir imagen: $e');
      return null;
    }
  }

  Future<void> actualizarUrlFirestore(String coleccion, String docId, String campo, String url) async {
    try {
      await _db.collection(coleccion).doc(docId).update({
        campo: url,
      });
    } catch (e) {
      print('Error al actualizar Firestore: $e');
    }
  }
}
