import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';
import '../permissions/permissions.dart';
import '../widgets/dialogs.dart';

/// A photo ready to upload: a JPEG of at most [PhotoPicker.maxDimension] pixels on its long
/// side, which is always well under the API's 5 MB limit.
class PickedPhoto {
  const PickedPhoto(this.bytes, {this.fileName = 'photo.jpg'});

  final Uint8List bytes;
  final String fileName;

  static const String contentType = 'image/jpeg';
}

enum PhotoSource { camera, gallery }

/// Takes or chooses a photo and shrinks it on the phone before it is uploaded. The API accepts
/// JPEG, PNG or WebP up to 5 MB; re-encoding everything as JPEG also turns HEIC photos into
/// something the API accepts.
abstract interface class PhotoPicker {
  static const int maxDimension = 1600;
  static const int jpegQuality = 80;
  static const int maxBytes = 5 * 1024 * 1024;

  /// Null if the user cancelled.
  Future<PickedPhoto?> pick(PhotoSource source);
}

class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      // The picker scales the image down first, so a 50 MP photo is never decoded in full.
      maxWidth: PhotoPicker.maxDimension.toDouble(),
      maxHeight: PhotoPicker.maxDimension.toDouble(),
      requestFullMetadata: false,
    );
    if (file == null) {
      return null;
    }
    // The package's defaults already give a JPEG with the EXIF data (e.g. GPS) removed.
    final jpeg = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: PhotoPicker.maxDimension,
      minHeight: PhotoPicker.maxDimension,
      quality: PhotoPicker.jpegQuality,
    );
    if (jpeg == null || jpeg.isEmpty || jpeg.length > PhotoPicker.maxBytes) {
      throw const PhotoUnusableException();
    }
    return PickedPhoto(jpeg);
  }
}

/// The photo couldn't be read or shrunk (a corrupt or unsupported file).
class PhotoUnusableException implements Exception {
  const PhotoUnusableException();
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());

/// Asks "Take a photo / Choose from gallery", checks the camera permission if needed, and
/// returns the shrunk photo, or null if the user backed out. Problems are explained on screen.
///
/// ```dart
/// final photo = await pickPhoto(context, ref);
/// if (photo != null) await api.uploadPhoto(photo);
/// ```
Future<PickedPhoto?> pickPhoto(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<PhotoSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.commonPhotoTakePhoto),
            onTap: () => Navigator.of(context).pop(PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.commonPhotoChooseFromGallery),
            onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) {
    return null;
  }
  if (source == PhotoSource.camera && !await ensureCameraPermission(context, ref)) {
    return null;
  }
  try {
    return await ref.read(photoPickerProvider).pick(source);
  } on Exception {
    if (context.mounted) {
      showToast(context, l10n.commonPhotoUnusable, tone: ToastTone.error);
    }
    return null;
  }
}
